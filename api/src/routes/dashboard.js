import { Router } from "express";

const router = Router();

// MVP placeholder
router.get("/summary", (req, res) => {
  res.json({
    checked: 10,
    notChecked: 2,
    compliant: 9,
    nonCompliant: 1,
  });
});

export default router;
