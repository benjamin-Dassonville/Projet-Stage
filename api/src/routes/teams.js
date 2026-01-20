import { Router } from "express";
import { getTeamWorkersDb } from "../helpers/teamWorkersDb.js";

const router = Router();

// GET /teams/:teamId/workers
router.get("/:teamId/workers", async (req, res) => {
  try {
    const { teamId } = req.params;
    const workers = await getTeamWorkersDb(String(teamId));
    res.json(workers);
  } catch (e) {
    res.status(500).json({ error: "DB error", details: String(e?.message ?? e) });
  }
});

export default router;