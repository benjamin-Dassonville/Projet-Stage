import express from "express";
import { pool } from "../db.js";

const router = express.Router();

// ✅ CHEF + DIRECTION + ADMIN peuvent gérer
function requireRoleManager(req, res, next) {
  const role = req.user?.role;
  if (role === "chef" || role === "direction" || role === "admin") return next();
  return res.status(403).json({ error: "Forbidden" });
}

function slugify(label) {
  return String(label || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function toMax(value) {
  if (value === undefined || value === null || value === "") return 0;
  const n = Number(value);
  if (!Number.isFinite(n)) return 0;
  if (n < 0) return 0;
  return Math.floor(n);
}

// GET /equipment
router.get("/", requireRoleManager, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `
      select
        id,
        name,
        max_misses_before_notif as "maxMissesBeforeNotif"
      from equipment
      order by name asc
      `
    );
    res.json(rows);
  } catch (e) {
    next(e);
  }
});

// POST /equipment { name: string, maxMissesBeforeNotif?: number }
// ✅ id = slug(name)
router.post("/", requireRoleManager, async (req, res, next) => {
  try {
    const { name, maxMissesBeforeNotif } = req.body || {};
    const cleanName = String(name || "").trim();
    if (!cleanName) return res.status(400).json({ error: "Missing name" });

    const equipmentId = slugify(cleanName);
    if (!equipmentId) return res.status(400).json({ error: "Invalid name" });

    const max = toMax(maxMissesBeforeNotif);

    const exists = await pool.query(`select 1 from equipment where id = $1`, [
      equipmentId,
    ]);
    if (exists.rowCount > 0) {
      return res.status(409).json({
        error: "Equipment already exists",
        id: equipmentId,
      });
    }

    const { rows } = await pool.query(
      `
      insert into equipment (id, name, max_misses_before_notif)
      values ($1, $2, $3)
      returning
        id,
        name,
        max_misses_before_notif as "maxMissesBeforeNotif"
      `,
      [equipmentId, cleanName, max]
    );

    res.status(201).json(rows[0]);
  } catch (e) {
    if (e?.code === "23505") {
      return res.status(409).json({ error: "Equipment id already exists" });
    }
    next(e);
  }
});

// PATCH /equipment/:equipmentId { name?: string, maxMissesBeforeNotif?: number }
router.patch("/:equipmentId", requireRoleManager, async (req, res, next) => {
  try {
    const equipmentId = String(req.params.equipmentId);
    const { name, maxMissesBeforeNotif } = req.body || {};

    const cleanName =
      name === undefined ? undefined : String(name || "").trim();
    const max =
      maxMissesBeforeNotif === undefined
        ? undefined
        : toMax(maxMissesBeforeNotif);

    if (cleanName !== undefined && cleanName.length === 0) {
      return res.status(400).json({ error: "Missing name" });
    }

    const { rows } = await pool.query(
      `
      update equipment
      set
        name = coalesce($2, name),
        max_misses_before_notif = coalesce($3, max_misses_before_notif)
      where id = $1
      returning
        id,
        name,
        max_misses_before_notif as "maxMissesBeforeNotif"
      `,
      [equipmentId, cleanName ?? null, max ?? null]
    );

    if (rows.length === 0) return res.status(404).json({ error: "Not found" });
    res.json(rows[0]);
  } catch (e) {
    next(e);
  }
});

// DELETE /equipment/:equipmentId
router.delete("/:equipmentId", requireRoleManager, async (req, res, next) => {
  try {
    const equipmentId = String(req.params.equipmentId);
    const { rowCount } = await pool.query(
      `delete from equipment where id = $1`,
      [equipmentId]
    );
    if (rowCount === 0) return res.status(404).json({ error: "Not found" });
    res.json({ ok: true });
  } catch (e) {
    if (e?.code === "23503") {
      return res.status(409).json({
        error:
          "Cannot delete equipment: it is referenced (checks or role_equipment).",
      });
    }
    next(e);
  }
});

export default router;