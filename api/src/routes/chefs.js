import { Router } from "express";
import { pool } from "../db.js";

const router = Router();

// GET /chefs
router.get("/", async (req, res) => {
  try {
    const { rows } = await pool.query(
      `select id, name from chefs order by name asc`
    );
    res.json(rows);
  } catch (e) {
    console.error("GET /chefs error:", e);
    res.status(500).json({ error: "Server error" });
  }
});

export default router;