import { Router } from "express";
import { teams } from "../store.js";

const router = Router();

router.get("/", (req, res) => {
  res.json(teams);
});

export default router;