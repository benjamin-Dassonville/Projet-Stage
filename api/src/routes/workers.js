import { Router } from "express";

const router = Router();

// GET /workers/:workerId
// Infos du travailleur
router.get("/:workerId", (req, res) => {
  const { workerId } = req.params;

  res.json({
    id: workerId,
    firstName: "Loïc",
    lastName: "Durant",
    employeeNumber: "12345",
  });
});

// GET /workers/:workerId/required-equipment
// Équipements requis pour la mission (FAKE pour MVP)
router.get("/:workerId/required-equipment", (req, res) => {
  const { workerId } = req.params;

  res.json({
    workerId,
    role: "debroussailleur",
    equipment: [
      { id: "e1", name: "Chaussures de sécurité" },
      { id: "e2", name: "Casque" },
      { id: "e3", name: "Gants" },
      { id: "e4", name: "Visière" },
    ],
  });
});

export default router;