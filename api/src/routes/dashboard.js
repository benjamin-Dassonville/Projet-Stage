import express from "express";
import { getTeamWorkersDb } from "../helpers/teamWorkersDb.js";
import { teams } from "../store.js";

const router = express.Router();

function normalizeRange(r) {
  const allowed = new Set(["today", "7d", "30d", "365d"]);
  if (!r) return "today";
  const s = String(r);
  return allowed.has(s) ? s : "today";
}

// GET /dashboard/summary?range=today|7d|30d|365d&teamId=1&chefId=c2
router.get("/summary", (req, res) => {
  const range = normalizeRange(req.query.range);
  const teamId = req.query.teamId ? String(req.query.teamId) : null;
  const chefId = req.query.chefId ? String(req.query.chefId) : null;

  // ✅ choisir les équipes à agréger
  let teamIds = [];

  if (teamId) {
    teamIds = [teamId];
  } else if (chefId) {
    teamIds = teams.filter((t) => t.chefId === chefId).map((t) => String(t.id));
  } else {
    teamIds = teams.map((t) => String(t.id));
  }

  // ✅ agréger les workers de toutes les équipes sélectionnées
  const allWorkers = teamIds.flatMap((id) => getTeamWorkers(id));

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
});

export default router;