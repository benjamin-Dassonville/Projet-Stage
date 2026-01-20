import express from "express";
import { pool } from "../db.js";

const router = express.Router();

/**
 * GET /teams/:teamId/workers
 * [{ id, name, status, attendance, teamId, controlled, lastCheckAt }]
 */
router.get("/:teamId/workers", async (req, res) => {
  const teamId = String(req.params.teamId);

  try {
    const team = await pool.query(`select 1 from teams where id = $1`, [teamId]);
    if (team.rowCount === 0) {
      return res.status(404).json({ error: "Team not found" });
    }

    const { rows } = await pool.query(
      `
      select
        w.id,
        w.name,
        w.status,
        w.attendance,
        w.team_id as "teamId",
        w.controlled,
        w.last_check_at as "lastCheckAt"
      from workers w
      where w.team_id = $1
      order by
        -- 1) PRESENT avant ABS
        case when w.attendance = 'PRESENT' then 0 else 1 end,
        -- 2) non contrôlés en haut
        case when w.controlled = false then 0 else 1 end,
        -- 3) KO avant OK
        case when w.status = 'KO' then 0 else 1 end,
        -- 4) nom
        w.name asc
      `,
      [teamId]
    );

    return res.json(rows);
  } catch (e) {
    console.error("GET /teams/:teamId/workers error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;