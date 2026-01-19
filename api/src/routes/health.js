import { Router } from "express";
import { pool } from "../db.js";

const router = Router();

router.get("/db", async (req, res) => {
  try {
    const r = await pool.query("select now() as now");
    res.json({ ok: true, now: r.rows[0].now });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e?.message ?? e) });
  }
});

export default router;