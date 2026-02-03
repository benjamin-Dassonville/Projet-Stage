import express from "express";
import { pool } from "../db.js";

const router = express.Router();

// ✅ Roles autorisés
function requireRoleManager(req, res, next) {
  const role = req.user?.role;
  if (role === "chef" || role === "direction" || role === "admin") return next();
  return res.status(403).json({ error: "Forbidden" });
}

// YYYY-MM-DD strict
function parseISODate(s) {
  if (!s || typeof s !== "string") return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const d = new Date(`${s}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) return null;
  return s;
}

/**
 * GET /calendar/teams?date=YYYY-MM-DD
 * Stats par équipe sur un jour
 */
router.get("/teams", requireRoleManager, async (req, res, next) => {
  try {
    const date = parseISODate(req.query.date);
    if (!date) return res.status(400).json({ error: "Missing or invalid date (YYYY-MM-DD)" });

    const { rows } = await pool.query(
      `
      with w as (
        select
          t.id as "teamId",
          t.name as "teamName",
          w.id as "workerId"
        from teams t
        join workers w on w.team_id = t.id
      ),
      c as (
        select
          worker_id as "workerId",
          result
        from checks
        where check_day = $1::date
      )
      select
        w."teamId",
        w."teamName",
        count(*)::int as "totalWorkers",
        count(c."workerId")::int as "checkedWorkers",
        count(*) filter (where c.result = 'CONFORME')::int as "ok",
        count(*) filter (where c.result = 'NON_CONFORME')::int as "nonConforme",
        count(*) filter (where c.result = 'KO')::int as "ko",
        (count(*) - count(c."workerId"))::int as "noCheck"
      from w
      left join c on c."workerId" = w."workerId"
      group by w."teamId", w."teamName"
      order by w."teamName" asc
      `,
      [date]
    );

    res.json(rows);
  } catch (e) {
    next(e);
  }
});

/**
 * GET /calendar/teams/:teamId?date=YYYY-MM-DD
 * Liste workers avec statut check du jour
 */
router.get("/teams/:teamId", requireRoleManager, async (req, res, next) => {
  try {
    const teamId = String(req.params.teamId || "").trim();
    const date = parseISODate(req.query.date);

    if (!teamId) return res.status(400).json({ error: "Missing teamId" });
    if (!date) return res.status(400).json({ error: "Missing or invalid date (YYYY-MM-DD)" });

    const t = await pool.query(`select id, name from teams where id = $1`, [teamId]);
    if (t.rowCount === 0) return res.status(404).json({ error: "Team not found" });

    const { rows } = await pool.query(
      `
      select
        w.id as "workerId",
        w.name as "name",
        w.attendance as "attendance",
        (c.id is not null) as "hasCheck",
        c.id as "checkId",
        c.result as "result"
      from workers w
      left join checks c
        on c.worker_id = w.id
       and c.check_day = $2::date
      where w.team_id = $1
      order by w.name asc
      `,
      [teamId, date]
    );

    res.json({
      team: t.rows[0],
      workers: rows,
    });
  } catch (e) {
    next(e);
  }
});

/**
 * GET /calendar/workers/:workerId?date=YYYY-MM-DD
 * Retourne check + items (visualisation)
 */
router.get("/workers/:workerId", requireRoleManager, async (req, res, next) => {
  try {
    const workerId = String(req.params.workerId || "").trim();
    const date = parseISODate(req.query.date);

    if (!workerId) return res.status(400).json({ error: "Missing workerId" });
    if (!date) return res.status(400).json({ error: "Missing or invalid date (YYYY-MM-DD)" });

    const w = await pool.query(`select id, name, team_id from workers where id = $1`, [workerId]);
    if (w.rowCount === 0) return res.status(404).json({ error: "Worker not found" });

    const c = await pool.query(
      `
      select
        id,
        worker_id as "workerId",
        team_id as "teamId",
        role,
        result,
        created_at as "createdAt",
        check_day as "checkDay",
        exists (
          select 1
          from check_audits ca
          where ca.check_id = checks.id
            and ca.action = 'UPDATE'
        ) as "isModified"
      from checks
      where worker_id = $1 and check_day = $2::date
      limit 1
      `,
      [workerId, date]
    );

    if (c.rowCount === 0) {
      return res.json({
        worker: w.rows[0],
        check: null,
        items: [],
      });
    }

    const checkId = c.rows[0].id;

    const items = await pool.query(
      `
      select
        ci.equipment_id as "equipmentId",
        e.name as "equipmentName",
        ci.status as "status"
      from check_items ci
      join equipment e on e.id = ci.equipment_id
      where ci.check_id = $1
      order by e.name asc
      `,
      [checkId]
    );

    res.json({
      worker: w.rows[0],
      check: c.rows[0],
      items: items.rows,
    });
  } catch (e) {
    next(e);
  }
});

export default router;