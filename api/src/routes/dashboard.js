import express from "express";
import { getTeamWorkers } from "../helpers/teamWorkers.js";

const router = express.Router();

// GET /dashboard/summary?teamId=1
router.get("/summary", (req, res) => {
  const teamId = req.query.teamId ? String(req.query.teamId) : "1";
  const workers = getTeamWorkers(teamId);

  const total = workers.length;
  const absents = workers.filter((w) => w.attendance === "ABS").length;
  const presents = total - absents;

  const ok = workers.filter((w) => w.status === "OK").length;
  const ko = workers.filter((w) => w.status === "KO").length;

  const nonControles = workers.filter(
    (w) => w.attendance === "PRESENT" && w.controlled === false
  ).length;

  const koWorkers = workers
    .filter((w) => w.status === "KO")
    .map((w) => ({ id: w.id, name: w.name }));

  res.json({
    teamId,
    kpi: { total, presents, absents, ok, ko, nonControles },
    koWorkers,
  });
});

export default router;