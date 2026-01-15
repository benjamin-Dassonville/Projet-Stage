import { Router } from "express";

const router = Router();

// MVP placeholder
router.post("/start", (req, res) => {
  res.json({ checkId: "chk_1" });
});

router.post("/:checkId/submit", (req, res) => {
  const { checkId } = req.params;
  res.json({ checkId, submitted: true });
});

export default router;
