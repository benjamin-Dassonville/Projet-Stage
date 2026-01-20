import express from "express";
import { pool } from "../db.js";

const router = express.Router();

function computeResult(items) {
  // CONFORME si tous OK, sinon NON_CONFORME
  const nonOk = items.some((it) => it.status !== "OK");
  return nonOk ? "NON_CONFORME" : "CONFORME";
}

function statusFromResult(result) {
  return result === "CONFORME" ? "OK" : "KO";
}

// POST /checks
// body attendu:
// {
//   "workerId": "1-2",
//   "teamId": "1",
//   "items": [{ "equipmentId":"e1", "status":"OK|MANQUANT|KO" }, ...],
//   "createdAt": "2026-01-20T10:00:00.000Z" (optionnel)
// }
router.post("/", async (req, res) => {
  const { workerId, teamId, items, createdAt } = req.body ?? {};

  if (!workerId || !teamId || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: "Invalid payload" });
  }

  for (const it of items) {
    if (!it?.equipmentId || !["OK", "MANQUANT", "KO"].includes(it.status)) {
      return res.status(400).json({ error: "Invalid items" });
    }
  }

  const client = await pool.connect();
  try {
    await client.query("begin");

    // 1) Vérifier worker + présence
    const wRes = await client.query(
      `
      select id, attendance, role
      from workers
      where id = $1
      for update
      `,
      [String(workerId)]
    );

    if (wRes.rows.length === 0) {
      await client.query("rollback");
      return res.status(404).json({ error: "Worker not found" });
    }

    const worker = wRes.rows[0];

    if (worker.attendance === "ABS") {
      await client.query("rollback");
      return res.status(400).json({ error: "Worker is ABSENT, cannot submit check" });
    }

    // 2) Calculer result côté serveur
    const result = computeResult(items);
    const newStatus = statusFromResult(result);

    // 3) Insérer checks
    const checkRes = await client.query(
      `
      insert into checks (worker_id, team_id, role, result, created_at)
      values ($1, $2, $3, $4, coalesce($5::timestamptz, now()))
      returning id
      `,
      [String(workerId), String(teamId), worker.role ?? null, result, createdAt ?? null]
    );
    const checkId = checkRes.rows[0].id;

    // 4) Insérer check_items
    for (const it of items) {
      await client.query(
        `
        insert into check_items (check_id, equipment_id, status)
        values ($1, $2, $3)
        `,
        [checkId, String(it.equipmentId), String(it.status)]
      );
    }

    // 5) Mettre à jour worker
    await client.query(
      `
      update workers
      set status = $2,
          controlled = true,
          last_check_at = now()
      where id = $1
      `,
      [String(workerId), newStatus]
    );

    await client.query("commit");
    return res.json({ ok: true, checkId: String(checkId), result });
  } catch (e) {
    await client.query("rollback");
    console.error("POST /checks error:", e);
    return res.status(500).json({ error: "Server error" });
  } finally {
    client.release();
  }
});

export default router;