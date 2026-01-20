import express from "express";
import { pool } from "../db.js";
import { getTeamWorkersDb } from "../helpers/teamWorkersDb.js";

const router = express.Router();

function normalizeRange(r) {
  const allowed = new Set(["today", "7d", "30d", "365d"]);
  if (!r) return "today";
  const s = String(r);
  return allowed.has(s) ? s : "today";
}

// GET /dashboard/summary?range=today|7d|30d|365d&teamId=1&chefId=c2
router.get("/summary", async (req, res) => {
  try {
    const range = normalizeRange(req.query.range);
    const teamId = req.query.teamId ? String(req.query.teamId) : null;
    const chefId = req.query.chefId ? String(req.query.chefId) : null;

    // ✅ Choisir les équipes à agréger (100% DB)
    let teamIds = [];

    if (teamId) {
      teamIds = [teamId];
    } else if (chefId) {
      const t = await pool.query(
        `select id from teams where chef_id = $1 order by id asc`,
        [chefId]
      );
      teamIds = t.rows.map((r) => String(r.id));
    } else {
      const t = await pool.query(`select id from teams order by id asc`);
      teamIds = t.rows.map((r) => String(r.id));
    }

    // ✅ Agréger les workers de toutes les équipes sélectionnées (DB)
    const lists = await Promise.all(teamIds.map((id) => getTeamWorkersDb(id)));
    const allWorkers = lists.flat();

    const total = allWorkers.length;
    const absents = allWorkers.filter((w) => w.attendance === "ABS").length;
    const presents = total - absents;

    const ok = allWorkers.filter((w) => w.status === "OK").length;
    const ko = allWorkers.filter((w) => w.status === "KO").length;

    const nonControles = allWorkers.filter(
      (w) => w.attendance === "PRESENT" && w.controlled === false
    ).length;

    const koWorkers = allWorkers
      .filter((w) => w.status === "KO")
      .map((w) => ({ id: w.id, name: w.name, teamId: w.teamId }));

    res.json({
      range,
      filters: { teamId, chefId },
      teamIds,
      kpi: { total, presents, absents, ok, ko, nonControles },
      koWorkers,
    });
  } catch (e) {
    console.error("GET /dashboard/summary error:", e);
    res.status(500).json({ error: "Dashboard error" });
  }
});

export default router;