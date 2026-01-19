import express from "express";

const router = express.Router();

// GET /teams/:teamId/workers
router.get("/:teamId/workers", (req, res) => {
  const { teamId } = req.params;

  // Données FAKE pour le moment
  res.json([
    {
      id: "1",
      name: "Loïc Durant",
      status: "OK",
      teamId,
    },
    {
      id: "2",
      name: "Jean Martin",
      status: "KO",
      teamId,
    },
    {
      id: "3",
      name: "Paul Leroy",
      status: "ABS",
      teamId,
    },
  ]);
});

export default router;