import express from "express";
import cors from "cors";
import dotenv from "dotenv";

import { requireAuth } from "./middleware/auth.js";

import teamsRoutes from "./routes/teams.js";
import workersRoutes from "./routes/workers.js";
import checksRoutes from "./routes/checks.js";
import dashboardRoutes from "./routes/dashboard.js";
import attendanceRoutes from "./routes/attendance.js";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.get("/health", (_, res) => res.json({ ok: true }));

// Routes protégées
app.use("/teams", requireAuth, teamsRoutes);
app.use("/workers", requireAuth, workersRoutes);
app.use("/checks", requireAuth, checksRoutes);
app.use("/dashboard", requireAuth, dashboardRoutes);
app.use("/attendance", requireAuth, attendanceRoutes);


const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`API running on :${port}`));