import { Router } from "express";
import { chefs } from "../store.js";

const router = Router();

router.get("/", (req, res) => {
  res.json(chefs);
});

export default router;