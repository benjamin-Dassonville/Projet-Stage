import express from "express";
import { pool } from "../db.js";

const router = express.Router();

// POST /attendance
// body: { workerId: "1-2", status: "ABS" | "PRESENT" }
router.post("/", async (req, res) => {
  const { workerId, status } = req.body ?? {};

  if (!workerId || (status !== "ABS" && status !== "PRESENT")) {
    return res.status(400).json({ error: "Invalid payload" });
  }

  try {
    let query;
    let params;

    if (status === "ABS") {
      // Option B: absent => invalide le contrôle
      query = `
        update workers
        set attendance = 'ABS',
            controlled = false,
            last_check_at = null,
            status = 'OK'
        where id = $1
        returning id, name, status, attendance, team_id as "teamId", controlled
      `;
      params = [String(workerId)];
    } else {
      // PRESENT => on remet présent, sans valider un contrôle
      query = `
        update workers
        set attendance = 'PRESENT'
        where id = $1
        returning id, name, status, attendance, team_id as "teamId", controlled
      `;
      params = [String(workerId)];
    }

    const { rows } = await pool.query(query, params);

    if (rows.length === 0) {
      return res.status(404).json({ error: "Worker not found" });
    }

    return res.json({ ok: true, worker: rows[0] });
  } catch (e) {
    console.error("POST /attendance error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;