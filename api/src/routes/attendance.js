import express from "express";
import { store } from "../store.js";

const router = express.Router();

// POST /attendance
// body: { workerId: "2", status: "ABS" | "PRESENT" }
router.post("/", (req, res) => {
  const { workerId, status } = req.body;

  if (!workerId || (status !== "ABS" && status !== "PRESENT")) {
    return res.status(400).json({ error: "Invalid payload" });
  }

  store.attendance.set(String(workerId), status);

  // si on met ABS, on force status ABS côté list
  return res.json({ ok: true });
});

export default router;