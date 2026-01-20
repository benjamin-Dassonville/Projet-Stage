import express from "express";
import { pool } from "../db.js";

const router = express.Router();

// GET /workers/:workerId (DB)
router.get("/:workerId", async (req, res) => {
  const workerId = String(req.params.workerId);

  try {
    const { rows } = await pool.query(
      `
      select
        w.id,
        w.name,
        w.employee_number as "employeeNumber",
        w.role,
        w.attendance,
        w.status,
        w.controlled,
        w.last_check_at as "lastCheckAt",
        w.team_id as "teamId",
        t.name as "teamName"
      from workers w
      join teams t on t.id = w.team_id
      where w.id = $1
      limit 1
      `,
      [workerId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "Worker not found" });
    }

    return res.json(rows[0]);
  } catch (e) {
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;