import express from "express";
import { store } from "../store.js";

const router = express.Router();

// POST /checks
router.post("/", (req, res) => {
  const { workerId, result } = req.body;

  const att = store.attendance.get(String(workerId)) ?? "PRESENT";
  if (att === "ABS") {
    return res
      .status(400)
      .json({ error: "Worker is ABSENT, cannot submit check" });
  }

  // result attendu: "CONFORME" ou "NON_CONFORME"
  if (workerId && result) {
    const status = result === "CONFORME" ? "OK" : "KO";
    store.workerStatus.set(String(workerId), status);
  }

  console.log("CHECK RECEIVED:", JSON.stringify(req.body, null, 2));
  return res.json({ ok: true });
});

export default router;
