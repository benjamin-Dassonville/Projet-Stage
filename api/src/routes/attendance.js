import express from "express";
import { pool } from "../db.js";

const router = express.Router();

router.post("/", async (req, res) => {
  const { workerId, status } = req.body;

  if (!workerId || (status !== "ABS" && status !== "PRESENT")) {
    return res.status(400).json({ error: "Invalid payload" });
  }

  try {
    // règle MVP: si ABS => controlled=false + status=OK (optionnel mais tu le fais déjà)
    const query =
      status === "ABS"
        ? `
          update workers
          set attendance = 'ABS',
              controlled = false,
              status = 'OK',
              last_check_at = null
          where id = $1
          returning id, name, status, attendance, team_id as "teamId", controlled
        `
        : `
          update workers
          set attendance = 'PRESENT'
          where id = $1
          returning id, name, status, attendance, team_id as "teamId", controlled
        `;

    const { rows } = await pool.query(query, [String(workerId)]);
    if (rows.length === 0) return res.status(404).json({ error: "Worker not found" });

    return res.json({ ok: true, worker: rows[0] });
  } catch (e) {
    console.error("POST /attendance error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;