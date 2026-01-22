import { Router } from "express";
import { pool } from "../db.js";

const router = Router();

// GET /teams-meta
// Optional: /teams-meta?withCounts=1  => ajoute workerCount (inclut PRESENT + ABS)
router.get("/", async (req, res) => {
  const withCounts =
    String(req.query.withCounts || "").toLowerCase() === "1" ||
    String(req.query.withCounts || "").toLowerCase() === "true";

  try {
    if (!withCounts) {
      const { rows } = await pool.query(
        `
        select
          id,
          name,
          chef_id as "chefId"
        from teams
        order by name asc
        `
      );
      return res.json(rows);
    }

    // withCounts = true
    // count inclut tous les workers (PRESENT + ABS)
    const { rows } = await pool.query(
      `
      select
        t.id,
        t.name,
        t.chef_id as "chefId",
        coalesce(count(w.id), 0)::int as "workerCount"
      from teams t
      left join workers w on w.team_id = t.id
      group by t.id, t.name, t.chef_id
      order by t.name asc
      `
    );

    return res.json(rows);
  } catch (e) {
    console.error("GET /teams-meta error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;