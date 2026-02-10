import express from "express";
import { pool } from "../db.js";

const router = express.Router();

/**
 * Rôles:
 * - chef / direction / admin : briefing jour + custom topics
 * - direction / admin : catalogue + obligations
 */
function requireRoleBriefing(req, res, next) {
  const role = req.user?.role;
  if (role === "chef" || role === "direction" || role === "admin") {
    return next();
  }
  return res.status(403).json({ error: "Forbidden" });
}

function requireRoleAdminOrDirection(req, res, next) {
  const role = req.user?.role;
  if (role === "direction" || role === "admin") {
    return next();
  }
  return res.status(403).json({ error: "Forbidden" });
}

function isoDayOrToday(v) {
  if (!v) {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    return d.toISOString().slice(0, 10); // YYYY-MM-DD
  }
  const s = String(v).trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  return s;
}

function parseIsoWeekday(v) {
  const n = Number(v);
  if (!Number.isInteger(n)) return null;
  if (n < 1 || n > 7) return null; // ISO: 1..7
  return n;
}

/* ============================================================================
   BRIEFING ÉQUIPE (CHEF)
============================================================================ */

/**
 * GET /briefings/team/:teamId?day=YYYY-MM-DD
 */
router.get("/team/:teamId", requireRoleBriefing, async (req, res) => {
  const teamId = String(req.params.teamId || "").trim();
  const day = isoDayOrToday(req.query.day);

  if (!teamId) return res.status(400).json({ error: "Missing teamId" });
  if (!day) return res.status(400).json({ error: "Invalid day" });

  try {
    const t = await pool.query(`select 1 from teams where id = $1`, [teamId]);
    if (t.rowCount === 0) {
      return res.status(404).json({ error: "Team not found" });
    }

    const { rows: bRows } = await pool.query(
      `
      insert into briefings (team_id, day, done)
      values ($1, $2::date, false)
      on conflict (team_id, day) do update
        set team_id = excluded.team_id
      returning
        id,
        team_id as "teamId",
        to_char(day, 'YYYY-MM-DD') as day,
        done,
        done_at as "doneAt"
      `,
      [teamId, day],
    );

    const briefing = bRows[0];

    const { rows: requiredTopics } = await pool.query(
      `
      with required_topic_ids as (
        -- Obligatoire à une date précise
        select brt.topic_id
        from briefing_required_topics brt
        where brt.day = $2::date

        union

        -- Obligatoire selon règles (stocké 0..6)
        select r.topic_id
        from briefing_required_rules r
        where r.is_active = true
          and (r.team_id is null or r.team_id = $1)
          and r.weekday = (extract(isodow from $2::date)::int - 1)
          and (r.start_day is null or $2::date >= r.start_day)
          and (r.end_day is null or $2::date <= r.end_day)
      )
      select
        bt.id as "topicId",
        bt.title,
        bt.description,
        coalesce(btc.checked, false) as checked
      from required_topic_ids r
      join briefing_topics bt on bt.id = r.topic_id
      left join briefing_topic_checks btc
        on btc.briefing_id = $3
       and btc.topic_id = bt.id
      where bt.is_active = true
      order by bt.title asc
      `,
      [teamId, day, briefing.id],
    );

    const { rows: customTopics } = await pool.query(
      `
      select
        bct.id,
        bct.title,
        bct.description,
        coalesce(bctc.checked, false) as checked
      from briefing_custom_topics bct
      left join briefing_custom_topic_checks bctc
        on bctc.custom_topic_id = bct.id
       and bctc.briefing_id = $1
      where bct.briefing_id = $1
      order by bct.created_at asc
      `,
      [briefing.id],
    );

    return res.json({
      teamId,
      day,
      briefing,
      requiredTopics,
      customTopics,
    });
  } catch (e) {
    console.error("GET /briefings/team/:teamId error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/* ============================================================================
   DONE / CHECKS
============================================================================ */

router.patch("/:briefingId/done", requireRoleBriefing, async (req, res) => {
  const briefingId = String(req.params.briefingId || "").trim();
  const done = req.body?.done;

  if (!briefingId) return res.status(400).json({ error: "Missing briefingId" });
  if (typeof done !== "boolean") {
    return res.status(400).json({ error: "done must be boolean" });
  }

  try {
    const { rows } = await pool.query(
      `
      update briefings
      set
        done = $2,
        done_at = case when $2 = true then now() else null end
      where id = $1
      returning
        id,
        team_id as "teamId",
        to_char(day, 'YYYY-MM-DD') as day,
        done,
        done_at as "doneAt"
      `,
      [briefingId, done],
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "Briefing not found" });
    }

    return res.json({ ok: true, briefing: rows[0] });
  } catch (e) {
    console.error("PATCH /briefings/:id/done error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

router.patch(
  "/:briefingId/topics/:topicId",
  requireRoleBriefing,
  async (req, res) => {
    const briefingId = String(req.params.briefingId || "").trim();
    const topicId = String(req.params.topicId || "").trim();
    const checked = req.body?.checked;

    if (!briefingId) return res.status(400).json({ error: "Missing briefingId" });
    if (!topicId) return res.status(400).json({ error: "Missing topicId" });
    if (typeof checked !== "boolean") {
      return res.status(400).json({ error: "checked must be boolean" });
    }

    try {
      // (optionnel mais propre) vérifier que briefing + topic existent
      const b = await pool.query(`select 1 from briefings where id = $1`, [briefingId]);
      if (b.rowCount === 0) return res.status(404).json({ error: "Briefing not found" });

      const t = await pool.query(`select 1 from briefing_topics where id = $1`, [topicId]);
      if (t.rowCount === 0) return res.status(404).json({ error: "Topic not found" });

      const { rows } = await pool.query(
        `
        insert into briefing_topic_checks (briefing_id, topic_id, checked)
        values ($1, $2, $3)
        on conflict (briefing_id, topic_id) do update
          set checked = excluded.checked
        returning
          id,
          briefing_id as "briefingId",
          topic_id as "topicId",
          checked
        `,
        [briefingId, topicId, checked],
      );

      return res.json({ ok: true, check: rows[0] });
    } catch (e) {
      console.error("PATCH /briefings/:briefingId/topics/:topicId error:", e);
      return res.status(500).json({ error: "Server error" });
    }
  },
);

/* ============================================================================
   ADMIN – SUJETS
============================================================================ */

router.get("/topics", requireRoleAdminOrDirection, async (_, res) => {
  try {
    const { rows } = await pool.query(
      `
      select
        id,
        title,
        description,
        is_active as "isActive"
      from briefing_topics
      order by title asc
      `,
    );
    res.json(rows);
  } catch (e) {
    console.error("GET /briefings/topics error:", e);
    res.status(500).json({ error: "Server error" });
  }
});

router.post("/topics", requireRoleAdminOrDirection, async (req, res) => {
  const title = String(req.body?.title || "").trim();
  const description =
    req.body?.description === undefined
      ? null
      : String(req.body.description).trim();

  if (!title) return res.status(400).json({ error: "Missing title" });

  try {
    const { rows } = await pool.query(
      `
      insert into briefing_topics (title, description, is_active)
      values ($1, $2, true)
      returning
        id,
        title,
        description,
        is_active as "isActive"
      `,
      [title, description],
    );
    res.status(201).json(rows[0]);
  } catch (e) {
    console.error("POST /briefings/topics error:", e);
    res.status(500).json({ error: "Server error" });
  }
});
/**
 * ✅ DELETE /briefings/topics/:topicId
 * Supprime définitivement un sujet SI il n'est pas référencé.
 */
router.delete(
  "/topics/:topicId",
  requireRoleAdminOrDirection,
  async (req, res) => {
    const topicId = String(req.params.topicId || "").trim();
    if (!topicId) return res.status(400).json({ error: "Missing topicId" });

    try {
      // 1) Vérifier si utilisé quelque part (sinon FK / incohérences)
      const checks = await pool.query(
        `
        select
          (select count(*)::int from briefing_required_topics where topic_id = $1) as required_by_date,
          (select count(*)::int from briefing_required_rules where topic_id = $1) as required_by_rules,
          (select count(*)::int from briefing_topic_checks where topic_id = $1) as checks_count
        `,
        [topicId],
      );

      const usage = checks.rows[0];
      const used =
        usage.required_by_date > 0 ||
        usage.required_by_rules > 0 ||
        usage.checks_count > 0;

      if (used) {
        return res.status(409).json({
          error:
            "Topic is used and cannot be deleted. Remove obligations/checks first.",
          usage,
        });
      }

      // 2) Delete (si pas utilisé)
      const del = await pool.query(
        `delete from briefing_topics where id = $1`,
        [topicId],
      );

      if (del.rowCount === 0) {
        return res.status(404).json({ error: "Topic not found" });
      }

      return res.json({ ok: true });
    } catch (e) {
      console.error("DELETE /briefings/topics/:topicId error:", e);
      return res.status(500).json({ error: "Server error" });
    }
  },
);
/**
 * PATCH /briefings/topics/:topicId
 * (sans updated_at pour éviter ton 500 si colonne inexistante)
 */
router.patch("/topics/:topicId", requireRoleAdminOrDirection, async (req, res) => {
  const topicId = String(req.params.topicId || "").trim();
  if (!topicId) return res.status(400).json({ error: "Missing topicId" });

  const title =
    req.body?.title === undefined ? null : String(req.body.title || "").trim();
  const description =
    req.body?.description === undefined
      ? null
      : String(req.body.description || "").trim();
  const isActive = req.body?.isActive;

  if (title !== null && title.length === 0) {
    return res.status(400).json({ error: "Invalid title" });
  }
  if (isActive !== undefined && typeof isActive !== "boolean") {
    return res.status(400).json({ error: "isActive must be boolean" });
  }

  try {
    const { rows } = await pool.query(
      `
      update briefing_topics
      set
        title = coalesce($2, title),
        description = coalesce($3, description),
        is_active = coalesce($4, is_active)
      where id = $1
      returning
        id,
        title,
        description,
        is_active as "isActive"
      `,
      [topicId, title, description, isActive === undefined ? null : isActive],
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "Topic not found" });
    }

    res.json(rows[0]);
  } catch (e) {
    console.error("PATCH /briefings/topics/:id error:", e);
    res.status(500).json({ error: "Server error" });
  }
});

/* ============================================================================
   ✅ ADMIN – OBLIGATIONS PAR DATE  (FIX DU 404)
============================================================================ */

/**
 * GET /briefings/required?day=YYYY-MM-DD
 */
router.get("/required", requireRoleAdminOrDirection, async (req, res) => {
  const day = isoDayOrToday(req.query.day);
  if (!day) return res.status(400).json({ error: "Invalid day (YYYY-MM-DD)" });

  try {
    const { rows } = await pool.query(
      `
      select
        brt.id,
        to_char(brt.day, 'YYYY-MM-DD') as day,
        bt.id as "topicId",
        bt.title,
        bt.description
      from briefing_required_topics brt
      join briefing_topics bt on bt.id = brt.topic_id
      where brt.day = $1::date
      order by bt.title asc
      `,
      [day],
    );

    return res.json({ day, required: rows });
  } catch (e) {
    console.error("GET /briefings/required error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * POST /briefings/required   body: { day: YYYY-MM-DD, topicId }
 */
router.post("/required", requireRoleAdminOrDirection, async (req, res) => {
  const day = isoDayOrToday(req.body?.day);
  const topicId = String(req.body?.topicId || "").trim();

  if (!day) return res.status(400).json({ error: "Invalid day (YYYY-MM-DD)" });
  if (!topicId) return res.status(400).json({ error: "Missing topicId" });

  try {
    const t = await pool.query(`select 1 from briefing_topics where id = $1`, [topicId]);
    if (t.rowCount === 0) return res.status(404).json({ error: "Topic not found" });

    const { rows } = await pool.query(
      `
      insert into briefing_required_topics (day, topic_id)
      values ($1::date, $2)
      returning id, to_char(day, 'YYYY-MM-DD') as day, topic_id as "topicId"
      `,
      [day, topicId],
    );

    return res.status(201).json(rows[0]);
  } catch (e) {
    // unique constraint possible
    if (e?.code === "23505") {
      return res.status(409).json({ error: "Already required for that day" });
    }
    console.error("POST /briefings/required error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * DELETE /briefings/required/:requiredId
 */
router.delete("/required/:requiredId", requireRoleAdminOrDirection, async (req, res) => {
  const requiredId = String(req.params.requiredId || "").trim();
  if (!requiredId) return res.status(400).json({ error: "Missing requiredId" });

  try {
    const { rowCount } = await pool.query(
      `delete from briefing_required_topics where id = $1`,
      [requiredId],
    );
    if (rowCount === 0) return res.status(404).json({ error: "Not found" });
    return res.json({ ok: true });
  } catch (e) {
    console.error("DELETE /briefings/required/:requiredId error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/* ============================================================================
   ✅ ADMIN – RÈGLES RÉCURRENTES (pour ta 3e page)
============================================================================ */

/**
 * GET /briefings/rules
 */
router.get("/rules", requireRoleAdminOrDirection, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `
      select
        r.id,
        (r.weekday + 1) as "isoDow",
        r.team_id as "teamId",
        r.start_day as "startDay",
        r.end_day as "endDay",
        r.is_active as "isActive",
        bt.id as "topicId",
        bt.title,
        bt.description
      from briefing_required_rules r
      join briefing_topics bt on bt.id = r.topic_id
      order by r.weekday asc, bt.title asc
      `,
    );
    return res.json(rows);
  } catch (e) {
    console.error("GET /briefings/rules error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * POST /briefings/rules  body: { isoDow, topicId, teamId? , startDay?, endDay? }
 * isoDow: 1..7
 */
router.post("/rules", requireRoleAdminOrDirection, async (req, res) => {
  const isoDow = parseIsoWeekday(req.body?.isoDow);
  const topicId = String(req.body?.topicId || "").trim();
  const teamIdRaw = req.body?.teamId;
  const teamId = teamIdRaw === undefined || teamIdRaw === null || String(teamIdRaw).trim() === ""
    ? null
    : String(teamIdRaw).trim();

  const startDay = req.body?.startDay ? isoDayOrToday(req.body.startDay) : null;
  const endDay = req.body?.endDay ? isoDayOrToday(req.body.endDay) : null;

  if (isoDow === null) return res.status(400).json({ error: "isoDow must be int 1..7" });
  if (!topicId) return res.status(400).json({ error: "Missing topicId" });
  if (req.body?.startDay && !startDay) return res.status(400).json({ error: "Invalid startDay (YYYY-MM-DD)" });
  if (req.body?.endDay && !endDay) return res.status(400).json({ error: "Invalid endDay (YYYY-MM-DD)" });

  try {
    const t = await pool.query(`select 1 from briefing_topics where id = $1`, [topicId]);
    if (t.rowCount === 0) return res.status(404).json({ error: "Topic not found" });

    if (teamId) {
      const teamCheck = await pool.query(`select 1 from teams where id = $1`, [teamId]);
      if (teamCheck.rowCount === 0) return res.status(404).json({ error: "Team not found" });
    }

    const { rows } = await pool.query(
      `
      insert into briefing_required_rules (weekday, topic_id, team_id, start_day, end_day, is_active)
      values ($1 - 1, $2, $3, $4::date, $5::date, true)
      returning
        id,
        (weekday + 1) as "isoDow",
        topic_id as "topicId",
        team_id as "teamId",
        start_day as "startDay",
        end_day as "endDay",
        is_active as "isActive"
      `,
      [isoDow, topicId, teamId, startDay, endDay],
    );

    return res.status(201).json(rows[0]);
  } catch (e) {
    if (e?.code === "23505") return res.status(409).json({ error: "Already required that weekday" });
    console.error("POST /briefings/rules error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * PATCH /briefings/rules/:ruleId  body: { isActive: boolean }
 */
router.patch("/rules/:ruleId", requireRoleAdminOrDirection, async (req, res) => {
  const ruleId = String(req.params.ruleId || "").trim();
  const isActive = req.body?.isActive;

  if (!ruleId) return res.status(400).json({ error: "Missing ruleId" });
  if (typeof isActive !== "boolean") return res.status(400).json({ error: "isActive must be boolean" });

  try {
    const { rows } = await pool.query(
      `
      update briefing_required_rules
      set is_active = $2
      where id = $1
      returning id, (weekday + 1) as "isoDow", topic_id as "topicId", team_id as "teamId", is_active as "isActive"
      `,
      [ruleId, isActive],
    );

    if (rows.length === 0) return res.status(404).json({ error: "Rule not found" });
    return res.json(rows[0]);
  } catch (e) {
    console.error("PATCH /briefings/rules/:ruleId error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * DELETE /briefings/rules/:ruleId
 */
router.delete("/rules/:ruleId", requireRoleAdminOrDirection, async (req, res) => {
  const ruleId = String(req.params.ruleId || "").trim();
  if (!ruleId) return res.status(400).json({ error: "Missing ruleId" });

  try {
    const { rowCount } = await pool.query(`delete from briefing_required_rules where id = $1`, [ruleId]);
    if (rowCount === 0) return res.status(404).json({ error: "Not found" });
    return res.json({ ok: true });
  } catch (e) {
    console.error("DELETE /briefings/rules/:ruleId error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;