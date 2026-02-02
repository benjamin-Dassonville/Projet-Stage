import express from "express";
import { pool } from "../db.js";

const router = express.Router();

const UNASSIGNED_TEAM_ID = process.env.UNASSIGNED_TEAM_ID || "UNASSIGNED";

/**
 * GET /workers/unassigned
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

/**
 * GET /workers/:workerId
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

    if (rows.length === 0) return res.status(404).json({ error: "Worker not found" });
    return res.json(rows[0]);
  } catch (e) {
    console.error("GET /workers/:workerId error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * GET /workers/:workerId/required-equipment
 */
router.get("/:workerId/required-equipment", async (req, res) => {
  const workerId = String(req.params.workerId);

  try {
    const w = await pool.query(
      `select id, role, team_id as "teamId" from workers where id = $1 limit 1`,
      [workerId]
    );

    if (w.rows.length === 0) return res.status(404).json({ error: "Worker not found" });

    const roleId = w.rows[0].role; // peut être null
    const teamId = w.rows[0].teamId;

    if (!roleId) {
      return res.json({ workerId, teamId, role: null, equipment: [] });
    }

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
      teamId,
      role: roleId,
      equipment: eq.rows,
    });
  } catch (e) {
    console.error("GET /workers/:workerId/required-equipment error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * GET /workers/:workerId/checks?range=today|7d|30d|365d
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
    const exists = await pool.query(`select 1 from workers where id = $1`, [workerId]);
    if (exists.rowCount === 0) return res.status(404).json({ error: "Worker not found" });

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

/**
 * PATCH /workers/:workerId/team
 */
router.patch("/:workerId/team", async (req, res) => {
  const workerId = String(req.params.workerId);
  const teamId = req.body?.teamId ? String(req.body.teamId) : null;

  if (!teamId) return res.status(400).json({ error: "Missing teamId" });

  try {
    const t = await pool.query(`select 1 from teams where id = $1`, [teamId]);
    if (t.rowCount === 0) return res.status(404).json({ error: "Team not found" });

    const upd = await pool.query(
      `
      update workers
      set team_id = $1
      where id = $2
      returning
        id, name, status, attendance,
        team_id as "teamId",
        controlled,
        last_check_at as "lastCheckAt"
      `,
      [teamId, workerId]
    );

    if (upd.rowCount === 0) return res.status(404).json({ error: "Worker not found" });

    return res.json({ ok: true, mode: "moved", worker: upd.rows[0] });
  } catch (e) {
    console.error("PATCH /workers/:workerId/team error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * PATCH /workers/:workerId/role
 */
router.patch("/:workerId/role", async (req, res) => {
  const workerId = String(req.params.workerId);
  const role = req.body?.role === null ? null : String(req.body?.role || "").trim();

  try {
    const upd = await pool.query(
      `
      update workers
      set role = $1
      where id = $2
      returning
        id, name,
        employee_number as "employeeNumber",
        role,
        attendance, status, controlled,
        last_check_at as "lastCheckAt",
        team_id as "teamId"
      `,
      [role === "" ? null : role, workerId]
    );

    if (upd.rowCount === 0) return res.status(404).json({ error: "Worker not found" });

    return res.json({ ok: true, worker: upd.rows[0] });
  } catch (e) {
    console.error("PATCH /workers/:workerId/role error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * PATCH /workers/:workerId/profile
 */
router.patch("/:workerId/profile", async (req, res) => {
  const workerId = String(req.params.workerId);
  const teamId = req.body?.teamId ? String(req.body.teamId) : null;
  const role = req.body?.role !== undefined ? String(req.body.role) : null;

  if (!teamId) return res.status(400).json({ error: "Missing teamId" });

  try {
    const t = await pool.query(`select 1 from teams where id = $1`, [teamId]);
    if (t.rowCount === 0) return res.status(404).json({ error: "Team not found" });

    const upd = await pool.query(
      `
      update workers
      set team_id = $1,
          role = $2
      where id = $3
      returning
        id, name, employee_number as "employeeNumber",
        role, attendance, status, controlled,
        team_id as "teamId", last_check_at as "lastCheckAt"
      `,
      [teamId, role === "" ? null : role, workerId]
    );

    if (upd.rowCount === 0) return res.status(404).json({ error: "Worker not found" });

    return res.json({ ok: true, worker: upd.rows[0] });
  } catch (e) {
    console.error("PATCH /workers/:workerId/profile error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * ✅ GET /workers/:workerId/alerts
 * Renvoie les équipements en alerte: max>0 + notified=true + strikes>=max
 */
router.get("/:workerId/alerts", async (req, res) => {
  const workerId = String(req.params.workerId);

  try {
    const exists = await pool.query(`select 1 from workers where id = $1`, [workerId]);
    if (exists.rowCount === 0) return res.status(404).json({ error: "Worker not found" });

    const { rows } = await pool.query(
      `
      select
        s.equipment_id as "equipmentId",
        e.name as "equipmentName",
        s.strikes as "missCount",
        e.max_misses_before_notif as "maxMissesBeforeNotif",
        s.last_strike_at as "lastStrikeAt"
      from worker_equipment_strikes s
      join equipment e on e.id = s.equipment_id
      where s.worker_id = $1
        and e.max_misses_before_notif > 0
        and s.notified = true
        and s.strikes >= e.max_misses_before_notif
      order by s.last_strike_at desc
      `,
      [workerId]
    );

    return res.json({ workerId, alerts: rows });
  } catch (e) {
    console.error("GET /workers/:workerId/alerts error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * ✅ POST /workers/:workerId/alerts/reset
 * Reset complet : strikes=0 et notified=false pour ce worker
 */
router.post("/:workerId/alerts/reset", async (req, res) => {
  const workerId = String(req.params.workerId);

  try {
    const exists = await pool.query(`select 1 from workers where id = $1`, [workerId]);
    if (exists.rowCount === 0) return res.status(404).json({ error: "Worker not found" });

    const upd = await pool.query(
      `
      update worker_equipment_strikes
      set strikes = 0,
          notified = false
      where worker_id = $1
      returning equipment_id
      `,
      [workerId]
    );

    return res.json({ ok: true, resetCount: upd.rowCount });
  } catch (e) {
    console.error("POST /workers/:workerId/alerts/reset error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * ✅ POST /workers/:workerId/alerts/:equipmentId/reset
 * Reset par équipement : strikes=0 et notified=false pour ce worker + cet équipement
 */
router.post("/:workerId/alerts/:equipmentId/reset", async (req, res) => {
  const workerId = String(req.params.workerId);
  const equipmentId = String(req.params.equipmentId);

  try {
    const w = await pool.query(`select 1 from workers where id = $1`, [workerId]);
    if (w.rowCount === 0) return res.status(404).json({ error: "Worker not found" });

    const e = await pool.query(`select 1 from equipment where id = $1`, [equipmentId]);
    if (e.rowCount === 0) return res.status(404).json({ error: "Equipment not found" });

    const upd = await pool.query(
      `
      update worker_equipment_strikes
      set strikes = 0,
          notified = false
      where worker_id = $1
        and equipment_id = $2
      returning worker_id, equipment_id
      `,
      [workerId, equipmentId]
    );

    // Si aucune ligne => il n’y avait pas de strikes enregistrés pour ce couple
    return res.json({
      ok: true,
      workerId,
      equipmentId,
      existed: upd.rowCount > 0,
    });
  } catch (e) {
    console.error("POST /workers/:workerId/alerts/:equipmentId/reset error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;