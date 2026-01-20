import express from "express";
import { pool } from "../db.js";

const router = express.Router();

function computeResult(items) {
  // règle MVP: si au moins 1 item MANQUANT ou KO => NON_CONFORME sinon CONFORME
  const bad = items?.some((it) => it.status === "MANQUANT" || it.status === "KO");
  return bad ? "NON_CONFORME" : "CONFORME";
}

router.post("/", async (req, res) => {
  const { workerId, teamId, items } = req.body;

  if (!workerId || !teamId || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: "Invalid payload" });
  }

  // validation items minimale
  for (const it of items) {
    if (!it.equipmentId || !it.status) {
      return res.status(400).json({ error: "Invalid items payload" });
    }
    if (!["OK", "MANQUANT", "KO"].includes(it.status)) {
      return res.status(400).json({ error: "Invalid item status" });
    }
  }

  const client = await pool.connect();
  try {
    await client.query("begin");

    // 1) vérifier existence worker & cohérence team_id
    const w = await client.query(
      `select id, team_id, attendance from workers where id = $1 limit 1`,
      [String(workerId)]
    );

    if (w.rows.length === 0) {
      await client.query("rollback");
      return res.status(404).json({ error: "Worker not found" });
    }

    const worker = w.rows[0];
    if (String(worker.team_id) !== String(teamId)) {
      await client.query("rollback");
      return res.status(400).json({ error: "Worker not in this team" });
    }

    // 2) insérer check (le trigger DB bloquera si attendance=ABS)
    const result = computeResult(items);

    const inserted = await client.query(
      `
      insert into checks(worker_id, team_id, result)
      values ($1, $2, $3)
      returning id
      `,
      [String(workerId), String(teamId), result]
    );

    const checkId = inserted.rows[0].id;

    // 3) insérer les items
    for (const it of items) {
      await client.query(
        `
        insert into check_items(check_id, equipment_id, status)
        values ($1, $2, $3)
        `,
        [checkId, String(it.equipmentId), it.status]
      );
    }

    // 4) update worker (si tu as déjà trigger qui le fait, c’est OK de le redire, c’est idempotent)
    const newStatus = result === "CONFORME" ? "OK" : "KO";

    await client.query(
      `
      update workers
      set
        status = $2,
        controlled = true,
        last_check_at = now()
      where id = $1
      `,
      [String(workerId), newStatus]
    );

    await client.query("commit");
    return res.json({ ok: true, checkId: String(checkId), result });
  } catch (e) {
    try {
      await client.query("rollback");
    } catch {}

    // Gestion propre des erreurs trigger / contraintes
    const msg = String(e?.message ?? "");

    // ton trigger ABSENT renvoie typiquement "Worker is ABSENT, cannot submit check"
    if (msg.toLowerCase().includes("absent")) {
      return res.status(400).json({ error: "Worker is ABSENT, cannot submit check" });
    }

    // FK equipment inconnu
    if (msg.toLowerCase().includes("violates foreign key constraint")) {
      return res.status(400).json({ error: "Invalid foreign key (worker/team/equipment)" });
    }

    console.error("POST /checks error:", e);
    return res.status(500).json({ error: "Server error" });
  } finally {
    client.release();
  }
});

export default router;