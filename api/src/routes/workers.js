import express from "express";
import { pool } from "../db.js";

const router = express.Router();

/**
 * GET /workers/:workerId
 * Infos du travailleur (DB)
 */
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
    console.error("GET /workers/:workerId error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * GET /workers/:workerId/required-equipment
 * Matériel requis en DB via role_equipment + equipment
 *
 * Hypothèse (cohérente avec ton schema/seed): workers.role contient l'identifiant du rôle
 * (ex: 'debroussailleur') qui correspond à roles.id.
 */
router.get("/:workerId/required-equipment", async (req, res) => {
  const workerId = String(req.params.workerId);

  try {
    // 1) Récupérer le rôle du worker
    const w = await pool.query(
      `select id, role from workers where id = $1 limit 1`,
      [workerId]
    );

    if (w.rows.length === 0) {
      return res.status(404).json({ error: "Worker not found" });
    }

    const roleId = w.rows[0].role;
    if (!roleId) {
      return res.json({ workerId, role: null, equipment: [] });
    }

    // 2) Récupérer les équipements requis par ce rôle
    const eq = await pool.query(
      `
      select
        e.id,
        e.name
      from role_equipment re
      join equipment e on e.id = re.equipment_id
      where re.role_id = $1
      order by e.name asc
      `,
      [roleId]
    );

    return res.json({
      workerId,
      role: roleId,
      equipment: eq.rows,
    });
  } catch (e) {
    console.error("GET /workers/:id/required-equipment error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;