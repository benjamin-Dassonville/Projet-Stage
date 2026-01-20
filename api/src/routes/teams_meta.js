import { Router } from "express";
import { pool } from "../db.js";

const router = Router();

// GET /teams-meta
router.get("/", async (req, res) => {
  try {
    const { rows } = await pool.query(
      `select id, name, chef_id as "chefId"
       from teams
       order by name asc`
    );
    res.json(rows);
  } catch (e) {
    console.error("GET /teams-meta error:", e);
    res.status(500).json({ error: "Server error" });
  }
});

export default router;