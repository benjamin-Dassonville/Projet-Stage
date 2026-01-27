import express from "express";
import crypto from "crypto";
import { pool } from "../db.js";

const router = express.Router();

// ✅ CHEF + DIRECTION + ADMIN peuvent gérer rôles/équipements
function requireRoleManager(req, res, next) {
  const role = req.user?.role;
  if (role === "chef" || role === "direction" || role === "admin") return next();
  return res.status(403).json({ error: "Forbidden" });
}

// ✅ Slug PRO pour ID = label
// - minuscules
// - accents supprimés
// - espaces/punct -> "-"
// - trim "-"
function slugify(label) {
  return String(label || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

// GET /roles?withCounts=1
router.get("/", requireRoleManager, async (req, res, next) => {
  try {
    const withCounts = req.query.withCounts === "1";

    if (withCounts) {
      const { rows } = await pool.query(
        `
        select
          r.id,
          r.label,
          count(re.equipment_id)::int as equipmentCount
        from roles r
        left join role_equipment re on re.role_id = r.id
        group by r.id
        order by r.label asc
        `
      );
      return res.json(rows);
    }

    const { rows } = await pool.query(
      `select id, label from roles order by label asc`
    );
    res.json(rows);
  } catch (e) {
    next(e);
  }
});

// POST /roles  { label: string }
// ✅ id auto = slug(label). Si collision => 409
router.post("/", requireRoleManager, async (req, res, next) => {
  try {
    const { label } = req.body || {};
    const cleanLabel = String(label || "").trim();

    if (!cleanLabel) {
      return res.status(400).json({ error: "Missing label" });
    }

    const roleId = slugify(cleanLabel);
    if (!roleId) {
      return res.status(400).json({ error: "Invalid label" });
    }

    // Si le slug existe déjà => 409
    const exists = await pool.query(`select 1 from roles where id = $1`, [roleId]);
    if (exists.rowCount > 0) {
      return res.status(409).json({
        error: "Role already exists",
        id: roleId,
      });
    }

    const { rows } = await pool.query(
      `insert into roles (id, label) values ($1, $2) returning id, label`,
      [roleId, cleanLabel]
    );
    res.status(201).json(rows[0]);
  } catch (e) {
    // duplicate key (au cas où)
    if (e?.code === "23505") {
      return res.status(409).json({ error: "Role id already exists" });
    }
    next(e);
  }
});

// PATCH /roles/:roleId  { label: string }
// ✅ label modifiable mais ID immuable
router.patch("/:roleId", requireRoleManager, async (req, res, next) => {
  try {
    const roleId = req.params.roleId;
    const { label } = req.body || {};

    const cleanLabel = String(label || "").trim();
    if (!cleanLabel) {
      return res.status(400).json({ error: "Missing label" });
    }

    const { rows } = await pool.query(
      `update roles set label = $2 where id = $1 returning id, label`,
      [roleId, cleanLabel]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: "Not found" });
    }
    res.json(rows[0]);
  } catch (e) {
    next(e);
  }
});

// DELETE /roles/:roleId
router.delete("/:roleId", requireRoleManager, async (req, res, next) => {
  try {
    const roleId = req.params.roleId;
    const { rowCount } = await pool.query(`delete from roles where id = $1`, [
      roleId,
    ]);
    if (rowCount === 0) return res.status(404).json({ error: "Not found" });
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

// GET /roles/:roleId/equipment
router.get("/:roleId/equipment", requireRoleManager, async (req, res, next) => {
  try {
    const roleId = req.params.roleId;

    const r = await pool.query(`select id from roles where id = $1`, [roleId]);
    if (r.rows.length === 0) return res.status(404).json({ error: "Not found" });

    const { rows } = await pool.query(
      `
      select e.id, e.name
      from role_equipment re
      join equipment e on e.id = re.equipment_id
      where re.role_id = $1
      order by e.name asc
      `,
      [roleId]
    );
    res.json(rows);
  } catch (e) {
    next(e);
  }
});

// POST /roles/:roleId/equipment
// body: { equipmentId?: string, name?: string }
router.post(
  "/:roleId/equipment",
  requireRoleManager,
  async (req, res, next) => {
    const client = await pool.connect();
    try {
      const roleId = req.params.roleId;
      const { equipmentId, name } = req.body || {};

      await client.query("begin");

      const r = await client.query(`select id from roles where id = $1`, [roleId]);
      if (r.rows.length === 0) {
        await client.query("rollback");
        return res.status(404).json({ error: "Not found" });
      }

      let eqId = equipmentId && String(equipmentId).trim();

      if (!eqId) {
        const cleanName = String(name || "").trim();
        if (!cleanName) {
          await client.query("rollback");
          return res.status(400).json({ error: "Missing equipmentId or name" });
        }

        // (Optionnel) Si tu veux aussi un ID "pro" pour equipment :
        // eqId = slugify(cleanName);  // ⚠️ à activer seulement si tu veux la même règle
        // mais ici je laisse ton UUID pour éviter collisions silencieuses :
        eqId = `eq_${crypto.randomUUID()}`;

        await client.query(`insert into equipment (id, name) values ($1, $2)`, [
          eqId,
          cleanName,
        ]);
      } else {
        const e = await client.query(`select id from equipment where id = $1`, [
          eqId,
        ]);
        if (e.rows.length === 0) {
          await client.query("rollback");
          return res.status(404).json({ error: "Equipment not found" });
        }
      }

      await client.query(
        `
        insert into role_equipment (role_id, equipment_id)
        values ($1, $2)
        on conflict do nothing
        `,
        [roleId, eqId]
      );

      await client.query("commit");

      const out = await pool.query(`select id, name from equipment where id = $1`, [
        eqId,
      ]);
      res.status(201).json({ ok: true, equipment: out.rows[0] });
    } catch (e) {
      try {
        await client.query("rollback");
      } catch {}
      next(e);
    } finally {
      client.release();
    }
  }
);

// DELETE /roles/:roleId/equipment/:equipmentId
router.delete(
  "/:roleId/equipment/:equipmentId",
  requireRoleManager,
  async (req, res, next) => {
    try {
      const { roleId, equipmentId } = req.params;
      const { rowCount } = await pool.query(
        `delete from role_equipment where role_id = $1 and equipment_id = $2`,
        [roleId, equipmentId]
      );
      if (rowCount === 0) return res.status(404).json({ error: "Not found" });
      res.json({ ok: true });
    } catch (e) {
      next(e);
    }
  }
);

export default router;