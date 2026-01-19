import express from "express";
import { getTeamWorkers } from "../helpers/teamWorkers.js";

const router = express.Router();

router.get("/:teamId/workers", (req, res) => {
  const { teamId } = req.params;
  res.json(getTeamWorkers(teamId));
});

export default router;