import express from "express";
import { pool } from "../db.js";

const router = express.Router();

function requireRoleManager(req, res, next) {
  const role = req.user?.role;
  if (role === "chef" || role === "direction" || role === "admin") return next();
  return res.status(403).json({ error: "Forbidden" });
}

// POST /misses/reset  { workerId, equipmentId }
router.post("/reset", requireRoleManager, async (req, res) => {
  try {
    const workerId = String(req.body?.workerId || "").trim();
    const equipmentId = String(req.body?.equipmentId || "").trim();
    if (!workerId || !equipmentId) {
      return res.status(400).json({ error: "Missing workerId/equipmentId" });
    }

    const { rowCount } = await pool.query(
      `
      update worker_equipment_misses
      set miss_count = 0,
          notified_at = null
      where worker_id = $1 and equipment_id = $2
      `,
      [workerId, equipmentId]
    );

    return res.json({ ok: true, reset: rowCount > 0 });
  } catch (e) {
    console.error("POST /misses/reset error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;