import express from "express";
import { pool } from "../db.js";

const router = express.Router();

/**
 * Rôles:
 * - chef / direction / admin : peuvent consulter + cocher + marquer "done" + gérer custom topics
 * - direction / admin : peuvent gérer le catalogue + les obligations (date / weekday)
 */
function requireRoleBriefing(req, res, next) {
  const role = req.user?.role;
  if (role === "chef" || role === "direction" || role === "admin")
    return next();
  return res.status(403).json({ error: "Forbidden" });
}

function requireRoleAdminOrDirection(req, res, next) {
  const role = req.user?.role;
  if (role === "direction" || role === "admin") return next();
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
  if (n < 1 || n > 7) return null; // ISO: 1=Mon ... 7=Sun
  return n;
}

/**
 * ✅ GET /briefings/team/:teamId?day=YYYY-MM-DD
 * Retourne:
 * - briefing (id, day, done, doneAt)
 * - requiredTopics[] (date + weekday) + checked
 * - customTopics[] (créés sur ce briefing)
 */
router.get("/team/:teamId", requireRoleBriefing, async (req, res) => {
  const teamId = String(req.params.teamId || "").trim();
  const day = isoDayOrToday(req.query.day);

  if (!teamId) return res.status(400).json({ error: "Missing teamId" });
  if (!day) return res.status(400).json({ error: "Invalid day (YYYY-MM-DD)" });

  try {
    // team exists ?
    const t = await pool.query(`select 1 from teams where id = $1`, [teamId]);
    if (t.rowCount === 0)
      return res.status(404).json({ error: "Team not found" });

    // ensure briefing row exists for (team, day)
    const bUpsert = await pool.query(
      `
      insert into briefings (team_id, day, done)
      values ($1, $2::date, false)
      on conflict (team_id, day) do update
        set team_id = excluded.team_id,
            updated_at = now()
      returning
        id,
        team_id as "teamId",
        to_char(day, 'YYYY-MM-DD') as day,
        done,
        done_at as "doneAt",
        created_at as "createdAt",
        updated_at as "updatedAt"
      `,
      [teamId, day],
    );

    const briefing = bUpsert.rows[0];

    // required topics = date + weekly rules (merge, avoid duplicates)
    const { rows: reqRows } = await pool.query(
      `
    with required_topic_ids as (
        -- Obligatoire à une date précise
        select brt.topic_id
        from briefing_required_topics brt
        where brt.day = $2::date

        union

        -- Obligatoire selon règles (ex: tous les jeudis), optionnellement bornées par dates
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
    const reqTopicsRes = { rows: reqRows };

    // custom topics for this briefing
    const customRes = await pool.query(
      `
      select
        id,
        briefing_id as "briefingId",
        title,
        description,
        checked,
        checked_at as "checkedAt",
        created_by_role as "createdByRole",
        created_at as "createdAt",
        updated_at as "updatedAt"
      from briefing_custom_topics
      where briefing_id = $1
      order by created_at asc
      `,
      [briefing.id],
    );

    return res.json({
      teamId,
      day,
      briefing,
      requiredTopics: reqTopicsRes.rows,
      customTopics: customRes.rows,
    });
  } catch (e) {
    console.error("GET /briefings/team/:teamId error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * ✅ PATCH /briefings/:briefingId/done { done: boolean }
 */
router.patch("/:briefingId/done", requireRoleBriefing, async (req, res) => {
  const briefingId = String(req.params.briefingId || "").trim();
  const done = req.body?.done;

  if (!briefingId) return res.status(400).json({ error: "Missing briefingId" });
  if (typeof done !== "boolean")
    return res.status(400).json({ error: "done must be boolean" });

  try {
    // 1) briefing existe + récupérer day
    const bRes = await pool.query(
      `select id, team_id as "teamId", to_char(day, 'YYYY-MM-DD') as day
       from briefings
       where id = $1
       limit 1`,
      [briefingId],
    );
    if (bRes.rowCount === 0)
      return res.status(404).json({ error: "Briefing not found" });

    const briefingDay = bRes.rows[0].day;

    // 2) Si on passe done=true -> vérifier que tous les REQUIRED topics sont cochés
    if (done === true) {
      const missingRes = await pool.query(
        `
        with required_topics as (
          -- Obligatoires par date
          select brt.topic_id
          from briefing_required_topics brt
          join briefing_topics bt on bt.id = brt.topic_id
          where brt.day = $2::date
            and bt.is_active = true

          union

          -- Obligatoires par weekday ISO
          select brw.topic_id
          from briefing_required_weekdays brw
          join briefing_topics bt on bt.id = brw.topic_id
          where brw.weekday = extract(isodow from $2::date)
            and bt.is_active = true
        )
        select
          bt.id as "topicId",
          bt.title
        from required_topics rt
        join briefing_topics bt on bt.id = rt.topic_id
        left join briefing_topic_checks btc
          on btc.briefing_id = $1
         and btc.topic_id = rt.topic_id
        where coalesce(btc.checked, false) = false
        order by bt.title asc
        `,
        [briefingId, briefingDay],
      );

      if (missingRes.rowCount > 0) {
        return res.status(400).json({
          error: "Cannot mark done: required topics not all checked",
          missingRequiredTopics: missingRes.rows, // [{topicId,title}]
        });
      }
    }

    // 3) OK -> on applique done
    const { rows } = await pool.query(
      `
      update briefings
      set
        done = $2,
        done_at = case when $2 = true then now() else null end,
        updated_at = now()
      where id = $1
      returning
        id,
        team_id as "teamId",
        to_char(day, 'YYYY-MM-DD') as day,
        done,
        done_at as "doneAt",
        updated_at as "updatedAt"
      `,
      [briefingId, done],
    );

    return res.json({ ok: true, briefing: rows[0] });
  } catch (e) {
    console.error("PATCH /briefings/:briefingId/done error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * ✅ PATCH /briefings/:briefingId/topics/:topicId { checked: boolean }
 * -> upsert dans briefing_topic_checks
 */
router.patch(
  "/:briefingId/topics/:topicId",
  requireRoleBriefing,
  async (req, res) => {
    const briefingId = String(req.params.briefingId || "").trim();
    const topicId = String(req.params.topicId || "").trim();
    const checked = req.body?.checked;

    if (!briefingId)
      return res.status(400).json({ error: "Missing briefingId" });
    if (!topicId) return res.status(400).json({ error: "Missing topicId" });
    if (typeof checked !== "boolean")
      return res.status(400).json({ error: "checked must be boolean" });

    try {
      const b = await pool.query(`select 1 from briefings where id = $1`, [
        briefingId,
      ]);
      if (b.rowCount === 0)
        return res.status(404).json({ error: "Briefing not found" });

      const t = await pool.query(
        `select 1 from briefing_topics where id = $1`,
        [topicId],
      );
      if (t.rowCount === 0)
        return res.status(404).json({ error: "Topic not found" });

      const up = await pool.query(
        `
      insert into briefing_topic_checks (briefing_id, topic_id, checked, checked_at, updated_at)
      values ($1, $2, $3, case when $3 = true then now() else null end, now())
      on conflict (briefing_id, topic_id) do update
        set checked = excluded.checked,
            checked_at = excluded.checked_at,
            updated_at = now()
      returning
        id,
        briefing_id as "briefingId",
        topic_id as "topicId",
        checked,
        checked_at as "checkedAt"
      `,
        [briefingId, topicId, checked],
      );

      return res.json({ ok: true, check: up.rows[0] });
    } catch (e) {
      console.error("PATCH /briefings/:briefingId/topics/:topicId error:", e);
      return res.status(500).json({ error: "Server error" });
    }
  },
);

//
// --------------------- CUSTOM TOPICS (chef / admin / direction) ---------------------
//

/**
 * ✅ POST /briefings/:briefingId/custom-topics { title, description? }
 */
router.post(
  "/:briefingId/custom-topics",
  requireRoleBriefing,
  async (req, res) => {
    const briefingId = String(req.params.briefingId || "").trim();
    const title = String(req.body?.title || "").trim();
    const description =
      req.body?.description === undefined
        ? null
        : String(req.body.description || "").trim();

    if (!briefingId)
      return res.status(400).json({ error: "Missing briefingId" });
    if (!title) return res.status(400).json({ error: "Missing title" });

    try {
      const b = await pool.query(`select 1 from briefings where id = $1`, [
        briefingId,
      ]);
      if (b.rowCount === 0)
        return res.status(404).json({ error: "Briefing not found" });

      const { rows } = await pool.query(
        `
      insert into briefing_custom_topics (briefing_id, title, description, created_by_role)
      values ($1, $2, $3, $4)
      returning
        id,
        briefing_id as "briefingId",
        title,
        description,
        checked,
        created_by_role as "createdByRole",
        created_at as "createdAt"
      `,
        [briefingId, title, description, req.user?.role ?? null],
      );

      return res.status(201).json(rows[0]);
    } catch (e) {
      console.error("POST /briefings/:briefingId/custom-topics error:", e);
      return res.status(500).json({ error: "Server error" });
    }
  },
);

/**
 * ✅ PATCH /briefings/:briefingId/custom-topics/:customId { checked: boolean }
 */
router.patch(
  "/:briefingId/custom-topics/:customId",
  requireRoleBriefing,
  async (req, res) => {
    const briefingId = String(req.params.briefingId || "").trim();
    const customId = String(req.params.customId || "").trim();
    const checked = req.body?.checked;

    if (!briefingId)
      return res.status(400).json({ error: "Missing briefingId" });
    if (!customId) return res.status(400).json({ error: "Missing customId" });
    if (typeof checked !== "boolean")
      return res.status(400).json({ error: "checked must be boolean" });

    try {
      const { rows } = await pool.query(
        `
      update briefing_custom_topics
      set
        checked = $3,
        checked_at = case when $3 = true then now() else null end,
        updated_at = now()
      where id = $2 and briefing_id = $1
      returning
        id,
        briefing_id as "briefingId",
        title,
        description,
        checked,
        checked_at as "checkedAt",
        updated_at as "updatedAt"
      `,
        [briefingId, customId, checked],
      );

      if (rows.length === 0)
        return res.status(404).json({ error: "Custom topic not found" });
      return res.json({ ok: true, customTopic: rows[0] });
    } catch (e) {
      console.error(
        "PATCH /briefings/:briefingId/custom-topics/:customId error:",
        e,
      );
      return res.status(500).json({ error: "Server error" });
    }
  },
);

//
// --------------------- ADMIN / DIRECTION (catalogue + obligations) ---------------------
//

/**
 * ✅ GET /briefings/topics
 */
router.get("/topics", requireRoleAdminOrDirection, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `
      select id, title, description, is_active as "isActive", created_at as "createdAt"
      from briefing_topics
      order by title asc
      `,
    );
    return res.json(rows);
  } catch (e) {
    console.error("GET /briefings/topics error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * ✅ POST /briefings/topics { title, description? }
 */
router.post("/topics", requireRoleAdminOrDirection, async (req, res) => {
  const title = String(req.body?.title || "").trim();
  const description =
    req.body?.description === undefined
      ? null
      : String(req.body.description || "").trim();

  if (!title) return res.status(400).json({ error: "Missing title" });

  try {
    const { rows } = await pool.query(
      `
      insert into briefing_topics (title, description, is_active)
      values ($1, $2, true)
      returning id, title, description, is_active as "isActive"
      `,
      [title, description],
    );
    return res.status(201).json(rows[0]);
  } catch (e) {
    console.error("POST /briefings/topics error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * ✅ PATCH /briefings/topics/:topicId { title?, description?, isActive? }
 */
router.patch(
  "/topics/:topicId",
  requireRoleAdminOrDirection,
  async (req, res) => {
    const topicId = String(req.params.topicId || "").trim();
    if (!topicId) return res.status(400).json({ error: "Missing topicId" });

    const title =
      req.body?.title === undefined
        ? null
        : String(req.body.title || "").trim();
    const description =
      req.body?.description === undefined
        ? null
        : String(req.body.description || "").trim();
    const isActive = req.body?.isActive;

    if (title !== null && title.length === 0)
      return res.status(400).json({ error: "Invalid title" });
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
        is_active = coalesce($4, is_active),
        updated_at = now()
      where id = $1
      returning id, title, description, is_active as "isActive"
      `,
        [topicId, title, description, isActive === undefined ? null : isActive],
      );

      if (rows.length === 0)
        return res.status(404).json({ error: "Topic not found" });
      return res.json(rows[0]);
    } catch (e) {
      console.error("PATCH /briefings/topics/:topicId error:", e);
      return res.status(500).json({ error: "Server error" });
    }
  },
);

/**
 * ✅ GET /briefings/required?day=YYYY-MM-DD
 * Obligations par date
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
 * ✅ POST /briefings/required { day: YYYY-MM-DD, topicId }
 */
router.post("/required", requireRoleAdminOrDirection, async (req, res) => {
  const day = isoDayOrToday(req.body?.day);
  const topicId = String(req.body?.topicId || "").trim();

  if (!day) return res.status(400).json({ error: "Invalid day (YYYY-MM-DD)" });
  if (!topicId) return res.status(400).json({ error: "Missing topicId" });

  try {
    const t = await pool.query(`select 1 from briefing_topics where id = $1`, [
      topicId,
    ]);
    if (t.rowCount === 0)
      return res.status(404).json({ error: "Topic not found" });

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
    if (e?.code === "23505")
      return res.status(409).json({ error: "Already required for that day" });
    console.error("POST /briefings/required error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * ✅ DELETE /briefings/required/:requiredId
 */
router.delete(
  "/required/:requiredId",
  requireRoleAdminOrDirection,
  async (req, res) => {
    const requiredId = String(req.params.requiredId || "").trim();
    if (!requiredId)
      return res.status(400).json({ error: "Missing requiredId" });

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
  },
);

/**
 * ✅ GET /briefings/required-weekdays?weekday=1..7
 * Obligations récurrentes (ISO weekday)
 */
router.get(
  "/required-weekdays",
  requireRoleAdminOrDirection,
  async (req, res) => {
    const weekday = parseIsoWeekday(req.query.weekday);
    if (weekday === null)
      return res.status(400).json({ error: "weekday must be int 1..7 (ISO)" });

    try {
      const { rows } = await pool.query(
        `
      select
        brw.id,
        brw.weekday,
        bt.id as "topicId",
        bt.title,
        bt.description
      from briefing_required_weekdays brw
      join briefing_topics bt on bt.id = brw.topic_id
      where brw.weekday = $1
      order by bt.title asc
      `,
        [weekday],
      );
      return res.json({ weekday, required: rows });
    } catch (e) {
      console.error("GET /briefings/required-weekdays error:", e);
      return res.status(500).json({ error: "Server error" });
    }
  },
);

/**
 * ✅ POST /briefings/required-weekdays { weekday: 1..7, topicId }
 */
router.post(
  "/required-weekdays",
  requireRoleAdminOrDirection,
  async (req, res) => {
    const weekday = parseIsoWeekday(req.body?.weekday);
    const topicId = String(req.body?.topicId || "").trim();

    if (weekday === null)
      return res.status(400).json({ error: "weekday must be int 1..7 (ISO)" });
    if (!topicId) return res.status(400).json({ error: "Missing topicId" });

    try {
      const t = await pool.query(
        `select 1 from briefing_topics where id = $1`,
        [topicId],
      );
      if (t.rowCount === 0)
        return res.status(404).json({ error: "Topic not found" });

      const { rows } = await pool.query(
        `
      insert into briefing_required_weekdays (weekday, topic_id)
      values ($1, $2)
      returning id, weekday, topic_id as "topicId"
      `,
        [weekday, topicId],
      );

      return res.status(201).json(rows[0]);
    } catch (e) {
      if (e?.code === "23505")
        return res
          .status(409)
          .json({ error: "Already required for that weekday" });
      console.error("POST /briefings/required-weekdays error:", e);
      return res.status(500).json({ error: "Server error" });
    }
  },
);

/**
 * ✅ DELETE /briefings/required-weekdays/:id
 */
router.delete(
  "/required-weekdays/:id",
  requireRoleAdminOrDirection,
  async (req, res) => {
    const id = String(req.params.id || "").trim();
    if (!id) return res.status(400).json({ error: "Missing id" });

    try {
      const { rowCount } = await pool.query(
        `delete from briefing_required_weekdays where id = $1`,
        [id],
      );
      if (rowCount === 0) return res.status(404).json({ error: "Not found" });
      return res.json({ ok: true });
    } catch (e) {
      console.error("DELETE /briefings/required-weekdays/:id error:", e);
      return res.status(500).json({ error: "Server error" });
    }
  },
);

/**
 * Weekly rules management (briefing_required_rules)
 * ✅ GET /briefings/rules
 */
router.get("/rules", requireRoleAdminOrDirection, async (req, res) => {
  try {
    const { rows } = await pool.query(`
            select
                r.id,
                (r.weekday + 1) as "isoDow",
                r.is_active as "isActive",
                r.created_at as "createdAt",
                bt.id as "topicId",
                bt.title,
                bt.description
            from briefing_required_rules r
            join briefing_topics bt on bt.id = r.topic_id
            order by r.weekday asc, bt.title asc
    `);
    res.json(rows);
  } catch (e) {
    console.error("GET /briefings/rules error:", e);
    res.status(500).json({ error: "Server error" });
  }
});

/**
 * ✅ POST /briefings/rules  body: { isoDow, topicId }
 */
router.post("/rules", requireRoleAdminOrDirection, async (req, res) => {
  const isoDow = Number(req.body?.isoDow);
  const topicId = String(req.body?.topicId || "").trim();

  if (!Number.isInteger(isoDow) || isoDow < 1 || isoDow > 7) {
    return res.status(400).json({ error: "isoDow must be integer 1..7" });
  }
  if (!topicId) return res.status(400).json({ error: "Missing topicId" });

  try {
    const t = await pool.query(`select 1 from briefing_topics where id = $1`, [
      topicId,
    ]);
    if (t.rowCount === 0)
      return res.status(404).json({ error: "Topic not found" });

    const { rows } = await pool.query(
      `
    insert into briefing_required_rules (weekday, topic_id, is_active)
    values ($1 - 1, $2, true)
    returning id, (weekday + 1) as "isoDow", topic_id as "topicId", is_active as "isActive"
      `,
      [isoDow, topicId],
    );

    return res.status(201).json(rows[0]);
  } catch (e) {
    if (e?.code === "23505")
      return res.status(409).json({ error: "Already required that weekday" });
    console.error("POST /briefings/rules error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * ✅ PATCH /briefings/rules/:ruleId body { isActive: boolean }
 */
router.patch(
  "/rules/:ruleId",
  requireRoleAdminOrDirection,
  async (req, res) => {
    const ruleId = String(req.params.ruleId || "").trim();
    const isActive = req.body?.isActive;

    if (!ruleId) return res.status(400).json({ error: "Missing ruleId" });
    if (typeof isActive !== "boolean")
      return res.status(400).json({ error: "isActive must be boolean" });

    try {
      const { rows } = await pool.query(
        `
    update briefing_required_rules
    set is_active = $2
    where id = $1
    returning id, (weekday + 1) as "isoDow", topic_id as "topicId", is_active as "isActive"
      `,
        [ruleId, isActive],
      );

      if (rows.length === 0)
        return res.status(404).json({ error: "Rule not found" });
      return res.json(rows[0]);
    } catch (e) {
      console.error("PATCH /briefings/rules/:ruleId error:", e);
      return res.status(500).json({ error: "Server error" });
    }
  },
);

/**
 * ✅ DELETE /briefings/rules/:ruleId
 */
router.delete(
  "/rules/:ruleId",
  requireRoleAdminOrDirection,
  async (req, res) => {
    const ruleId = String(req.params.ruleId || "").trim();
    if (!ruleId) return res.status(400).json({ error: "Missing ruleId" });

    try {
      const { rowCount } = await pool.query(
        `delete from briefing_required_rules where id = $1`,
        [ruleId],
      );
      if (rowCount === 0) return res.status(404).json({ error: "Not found" });
      return res.json({ ok: true });
    } catch (e) {
      console.error("DELETE /briefings/rules/:ruleId error:", e);
      return res.status(500).json({ error: "Server error" });
    }
  },
);

export default router;
