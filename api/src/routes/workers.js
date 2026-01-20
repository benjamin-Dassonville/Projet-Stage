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
 * Matériel requis (FULL DB)
 * via workers.role -> role_equipment -> equipment
 */
router.get("/:workerId/required-equipment", async (req, res) => {
  const workerId = String(req.params.workerId);

  try {
    // 1) récupérer le rôle du worker
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

    // 2) équipements requis pour ce rôle
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
    console.error(
      "GET /workers/:workerId/required-equipment error:",
      e
    );
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * GET /workers/:workerId/checks?range=today|7d|30d|365d
 * Historique des contrôles (FULL DB)
 */
router.get("/:workerId/checks", async (req, res) => {
  const workerId = String(req.params.workerId);

  const allowed = new Set(["today", "7d", "30d", "365d"]);
  const range = allowed.has(String(req.query.range || "today"))
    ? String(req.query.range || "today")
    : "today";

  function rangeToSince(r) {
    const now = new Date();
    switch (r) {
      case "today": {
        const d = new Date(now);
        d.setHours(0, 0, 0, 0);
        return d;
      }
      case "7d":
        return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      case "30d":
        return new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      case "365d":
        return new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
      default: {
        const d = new Date(now);
        d.setHours(0, 0, 0, 0);
        return d;
      }
    }
  }

  const since = rangeToSince(range);

  try {
    // 1) vérifier que le worker existe
    const exists = await pool.query(
      `select 1 from workers where id = $1`,
      [workerId]
    );

    if (exists.rowCount === 0) {
      return res.status(404).json({ error: "Worker not found" });
    }

    // 2) récupérer les checks + items
    const { rows } = await pool.query(
      `
      select
        c.id as "checkId",
        c.worker_id as "workerId",
        c.team_id as "teamId",
        c.result,
        c.role,
        c.created_at as "createdAt",
        ci.id as "checkItemId",
        ci.equipment_id as "equipmentId",
        e.name as "equipmentName",
        ci.status as "itemStatus"
      from checks c
      left join check_items ci on ci.check_id = c.id
      left join equipment e on e.id = ci.equipment_id
      where c.worker_id = $1
        and c.created_at >= $2
      order by c.created_at desc, ci.id asc
      `,
      [workerId, since.toISOString()]
    );

    // 3) regrouper par check
    const byCheck = new Map();

    for (const r of rows) {
      if (!byCheck.has(r.checkId)) {
        byCheck.set(r.checkId, {
          id: String(r.checkId),
          workerId: r.workerId,
          teamId: r.teamId,
          result: r.result,
          role: r.role ?? null,
          createdAt: r.createdAt,
          items: [],
        });
      }

      if (r.checkItemId) {
        byCheck.get(r.checkId).items.push({
          id: String(r.checkItemId),
          equipmentId: r.equipmentId,
          equipmentName: r.equipmentName ?? null,
          status: r.itemStatus,
        });
      }
    }

    return res.json({
      workerId,
      range,
      since,
      checks: Array.from(byCheck.values()),
    });
  } catch (e) {
    console.error("GET /workers/:workerId/checks error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;