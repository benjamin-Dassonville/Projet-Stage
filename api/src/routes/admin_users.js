import express from "express";
import { pool } from "../db.js";
import { requireAuth } from "../middleware/auth.js";

const router = express.Router();

function requireAdminOrDirection(req, res, next) {
  const r = req.user?.role;
  if (r === "admin" || r === "direction") return next();
  return res.status(403).json({ error: "Forbidden" });
}

// Liste des non assignés
router.get("/unassigned", requireAuth, requireAdminOrDirection, async (req, res) => {
  const { rows } = await pool.query(
    `select id, email, role, created_at
     from profiles
     where role = 'non_assigne'
     order by created_at asc`
  );
  res.json(rows);
});

// Changer role d'un user
router.patch("/users/:id/role", requireAuth, requireAdminOrDirection, async (req, res) => {
  const id = String(req.params.id || "").trim();
  const role = String(req.body?.role || "").trim(); // admin/direction/chef/non_assigne
  if (!id) return res.status(400).json({ error: "Missing id" });
  if (!role) return res.status(400).json({ error: "Missing role" });

  const { rows } = await pool.query(
    `update profiles set role = $2 where id = $1 returning id, email, role`,
    [id, role]
  );
  if (rows.length === 0) return res.status(404).json({ error: "User not found" });
  res.json(rows[0]);
});

export default router;