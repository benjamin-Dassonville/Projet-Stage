import { Router } from "express";
import { pool } from "../db.js";

const router = Router();

const UNASSIGNED_TEAM_ID = process.env.UNASSIGNED_TEAM_ID || "UNASSIGNED";

/**
 * GET /workers/unassigned
 * Liste les travailleurs dont team_id = UNASSIGNED_TEAM_ID
 */
router.get("/unassigned", async (req, res) => {
  try {
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
      order by w.name asc
      `,
      [UNASSIGNED_TEAM_ID]
    );

    return res.json({
      teamId: UNASSIGNED_TEAM_ID,
      count: rows.length,
      workers: rows,
    });
  } catch (e) {
    console.error("GET /workers/unassigned error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;