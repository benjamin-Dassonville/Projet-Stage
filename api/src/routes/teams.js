import { Router } from "express";

const router = Router();

// MVP placeholder
router.get("/", (req, res) => {
  res.json({
    teams: [
      { id: "1", name: "Équipe A" },
      { id: "2", name: "Équipe B" },
    ],
  });
});

router.get("/:teamId/workers", (req, res) => {
  const { teamId } = req.params;
  res.json({
    teamId,
    workers: [
      { id: "42", firstName: "Loïc", lastName: "Durant", status: "NOT_CHECKED" },
    ],
  });
});

export default router;

