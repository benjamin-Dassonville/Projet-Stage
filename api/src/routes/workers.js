import { Router } from "express";

const router = Router();

// MVP placeholder
router.get("/:workerId", (req, res) => {
  const { workerId } = req.params;
  res.json({
    id: workerId,
    firstName: "Loïc",
    lastName: "Durant",
    employeeNumber: "12345",
  });
});

export default router;
