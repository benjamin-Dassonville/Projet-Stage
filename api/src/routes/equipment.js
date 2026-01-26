import express from "express";
import crypto from "crypto";

import { pool } from "../db.js";

const router = express.Router();

function requireRoleManager(req, res, next) {
  const role = req.user?.role;
  if (role === "chef" || role === "direction") return next();
  return res.status(403).json({ error: "Forbidden" });
}

// GET /equipment
router.get("/", requireRoleManager, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `select id, name from equipment order by name asc`
    );
    res.json(rows);
  } catch (e) {
    next(e);
  }
});

// POST /equipment  { id?: string, name: string }
router.post("/", requireRoleManager, async (req, res, next) => {
  try {
    const { id, name } = req.body || {};
    if (!name || String(name).trim().length === 0) {
      return res.status(400).json({ error: "Missing name" });
    }

    const equipmentId = (id && String(id).trim()) || `eq_${crypto.randomUUID()}`;

    const { rows } = await pool.query(
      `insert into equipment (id, name) values ($1, $2) returning id, name`,
      [equipmentId, String(name).trim()]
    );
    res.status(201).json(rows[0]);
  } catch (e) {
    if (e?.code === "23505") {
      return res.status(409).json({ error: "Equipment id already exists" });
    }
    next(e);
  }
});

// PATCH /equipment/:equipmentId  { name: string }
router.patch("/:equipmentId", requireRoleManager, async (req, res, next) => {
  try {
    const { equipmentId } = req.params;
    const { name } = req.body || {};
    if (!name || String(name).trim().length === 0) {
      return res.status(400).json({ error: "Missing name" });
    }

    const { rows } = await pool.query(
      `update equipment set name = $2 where id = $1 returning id, name`,
      [equipmentId, String(name).trim()]
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
    const { equipmentId } = req.params;
    const { rowCount } = await pool.query(`delete from equipment where id = $1`, [
      equipmentId,
    ]);
    if (rowCount === 0) return res.status(404).json({ error: "Not found" });
    res.json({ ok: true });
  } catch (e) {
    // FK restrict (equipment used in check_items)
    if (e?.code === "23503") {
      return res
        .status(409)
        .json({ error: "Equipment is used in checks and can't be deleted" });
    }
    next(e);
  }
});

export default router;
