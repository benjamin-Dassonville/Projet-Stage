import express from "express";
import { pool } from "../db.js";

const router = express.Router();

function normalizeRange(r) {
  const allowed = new Set(["today", "7d", "30d", "365d"]);
  if (!r) return "today";
  const s = String(r);
  return allowed.has(s) ? s : "today";
}

function rangeToSince(range) {
  const now = new Date();
  switch (range) {
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

// GET /dashboard/summary?range=today|7d|30d|365d&teamId=1&chefId=c2
router.get("/summary", async (req, res) => {
  const range = normalizeRange(req.query.range);
  const teamId = req.query.teamId ? String(req.query.teamId) : null;
  const chefId = req.query.chefId ? String(req.query.chefId) : null;

  try {
    // 1) teams ciblées (FULL DB)
    let teamIds = [];

    if (teamId) {
      teamIds = [teamId];
    } else if (chefId) {
      const t = await pool.query(`select id from teams where chef_id = $1`, [chefId]);
      teamIds = t.rows.map((r) => String(r.id));
    } else {
      const t = await pool.query(`select id from teams`);
      teamIds = t.rows.map((r) => String(r.id));
    }

    const since = rangeToSince(range);

    if (teamIds.length === 0) {
      return res.json({
        range,
        since: since.toISOString(),
        filters: { teamId, chefId },
        teamIds: [],
        kpi: {
          total: 0,
          presents: 0,
          absents: 0,
          ok: 0,
          ko: 0,
          nonControles: 0,
          controlled: 0,
          current: {
            total: 0,
            presents: 0,
            absents: 0,
            ok: 0,
            ko: 0,
            nonControles: 0,
            controlled: 0,
          },
          period: {
            controlled: 0,
            ok: 0,
            ko: 0,
            nonControles: 0,
          },
        },
        koWorkers: [],
      });
    }

    // 2) workers (état courant)
    const workersRes = await pool.query(
      `
      select id, name, attendance, status, controlled, team_id as "teamId"
      from workers
      where team_id = any($1)
      `,
      [teamIds]
    );
    const workers = workersRes.rows;

    // KPI current
    const currentTotal = workers.length;
    const currentAbsents = workers.filter((w) => w.attendance === "ABS").length;
    const currentPresents = currentTotal - currentAbsents;

    const currentControlled = workers.filter(
      (w) => w.attendance === "PRESENT" && w.controlled === true
    ).length;

    const currentNonControles = workers.filter(
      (w) => w.attendance === "PRESENT" && w.controlled === false
    ).length;

    // ✅ FIX: OK/KO = uniquement sur les contrôlés (et présents)
    const currentOk = workers.filter(
      (w) => w.attendance === "PRESENT" && w.controlled === true && w.status === "OK"
    ).length;

    const currentKo = workers.filter(
      (w) => w.attendance === "PRESENT" && w.controlled === true && w.status === "KO"
    ).length;

    // 3) last check in period per worker
    const lastChecksRes = await pool.query(
      `
      select distinct on (c.worker_id)
        c.id as "checkId",
        c.worker_id as "workerId",
        c.result,
        c.created_at as "createdAt"
      from checks c
      where c.team_id = any($1)
        and c.created_at >= $2
      order by c.worker_id, c.created_at desc
      `,
      [teamIds, since.toISOString()]
    );
    const lastChecks = lastChecksRes.rows;

    // --- checks modifiés ? (au moins 1 UPDATE dans check_audits) ---
    const checkIds = lastChecks.map((c) => c.checkId).filter(Boolean);

    let modifiedSet = new Set();
    if (checkIds.length > 0) {
      const modRes = await pool.query(
        `
        select distinct check_id
        from check_audits
        where check_id = any($1)
          and upper(action) = 'UPDATE'
        `,
        [checkIds]
      );
      modifiedSet = new Set(modRes.rows.map((r) => String(r.check_id)));
    }

    const periodControlled = lastChecks.length;
    const periodOk = lastChecks.filter((c) => c.result === "CONFORME").length;

    // ✅ FIX: "KO" doit compter les checks KO (pas NON_CONFORME)
    const periodKo = lastChecks.filter((c) => c.result === "KO").length;

    const checkedSet = new Set(lastChecks.map((c) => c.workerId));
    const periodNonControles = workers.filter(
      (w) => w.attendance === "PRESENT" && !checkedSet.has(w.id)
    ).length;

    // koWorkers period + infos modification
    const koChecks = lastChecks.filter((c) => c.result === "KO");
    const koIds = new Set(koChecks.map((c) => c.workerId));
    const koByWorker = new Map(koChecks.map((c) => [c.workerId, c]));

    const koWorkers = workers
      .filter((w) => koIds.has(w.id))
      .map((w) => {
        const lc = koByWorker.get(w.id);
        const checkId = lc ? String(lc.checkId) : null;
        const isModified = checkId ? modifiedSet.has(checkId) : false;

        return {
          id: w.id,
          name: w.name,
          teamId: w.teamId,
          checkId,
          isModified,
        };
      });

    return res.json({
      range,
      since: since.toISOString(),
      filters: { teamId, chefId },
      teamIds,

      // compat Flutter: on garde l’ancien format (basé current)
      kpi: {
        total: currentTotal,
        presents: currentPresents,
        absents: currentAbsents,
        ok: currentOk,
        ko: currentKo,
        nonControles: currentNonControles,
        controlled: currentControlled,

        current: {
          total: currentTotal,
          presents: currentPresents,
          absents: currentAbsents,
          ok: currentOk,
          ko: currentKo,
          nonControles: currentNonControles,
          controlled: currentControlled,
        },
        period: {
          controlled: periodControlled,
          ok: periodOk,
          ko: periodKo,
          nonControles: periodNonControles,
        },
      },

      koWorkers,
    });
  } catch (e) {
    console.error("GET /dashboard/summary error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;