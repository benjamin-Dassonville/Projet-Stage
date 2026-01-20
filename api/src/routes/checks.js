import express from "express";
import { pool } from "../db.js";

const router = express.Router();

function computeResultFromItems(items) {
  // NON_CONFORME si au moins un item est KO ou MANQUANT
  const nonOk = items.some(
    (it) => it?.status === "KO" || it?.status === "MANQUANT"
  );
  return nonOk ? "NON_CONFORME" : "CONFORME";
}

// POST /checks
// body: { workerId, teamId, items:[{equipmentId,status}], createdAt? }
router.post("/", async (req, res) => {
  const workerId = req.body?.workerId ? String(req.body.workerId) : null;
  const teamId = req.body?.teamId ? String(req.body.teamId) : null;
  const items = Array.isArray(req.body?.items) ? req.body.items : [];

  if (!workerId || !teamId) {
    return res.status(400).json({ error: "workerId/teamId required" });
  }

  // validation items
  for (const it of items) {
    const equipmentId = it?.equipmentId ? String(it.equipmentId) : null;
    const status = it?.status ? String(it.status) : null;
    const okStatus = status === "OK" || status === "MANQUANT" || status === "KO";
    if (!equipmentId || !okStatus) {
      return res.status(400).json({ error: "Invalid items payload" });
    }
  }

  const client = await pool.connect();
  try {
    await client.query("begin");

    // 1) lock worker row (évite concurrence)
    const wRes = await client.query(
      `
      select id, attendance, role
      from workers
      where id = $1
      for update
      `,
      [workerId]
    );

    if (wRes.rowCount === 0) {
      await client.query("rollback");
      return res.status(404).json({ error: "Worker not found" });
    }

    const worker = wRes.rows[0];
    if (worker.attendance === "ABS") {
      await client.query("rollback");
      return res
        .status(400)
        .json({ error: "Worker is ABSENT, cannot submit check" });
    }

    // 2) vérifier team existe (et cohérence worker.team_id)
    const tRes = await client.query(
      `select id from teams where id = $1 limit 1`,
      [teamId]
    );
    if (tRes.rowCount === 0) {
      await client.query("rollback");
      return res.status(404).json({ error: "Team not found" });
    }

    // 3) calcul résultat depuis items
    const result = computeResultFromItems(items);
    const newStatus = result === "CONFORME" ? "OK" : "KO";

    // 4) insert check
    const createdAt = req.body?.createdAt
      ? new Date(req.body.createdAt)
      : new Date();

    const checkRes = await client.query(
      `
      insert into checks (worker_id, team_id, role, result, created_at)
      values ($1, $2, $3, $4, $5)
      returning id
      `,
      [workerId, teamId, worker.role ?? null, result, createdAt]
    );

    const checkId = String(checkRes.rows[0].id);

    // 5) insert items (si vide, on autorise quand même)
    for (const it of items) {
      await client.query(
        `
        insert into check_items (check_id, equipment_id, status)
        values ($1, $2, $3)
        `,
        [checkId, String(it.equipmentId), String(it.status)]
      );
    }

    // 6) update worker
    await client.query(
      `
      update workers
      set status = $2,
          controlled = true,
          last_check_at = $3
      where id = $1
      `,
      [workerId, newStatus, createdAt]
    );

    await client.query("commit");
    return res.json({ ok: true, checkId, result });
  } catch (e) {
    try {
      await client.query("rollback");
    } catch (_) {}
    console.error("POST /checks error:", e);
    return res.status(500).json({ error: "Server error" });
  } finally {
    client.release();
  }
});

export default router;