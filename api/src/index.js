import express from "express";
import cors from "cors";

import dashboardRoutes from "./routes/dashboard.js";
import attendanceRoutes from "./routes/attendance.js";
import chefsRouter from "./routes/chefs.js";
import teamsMetaRouter from "./routes/teams_meta.js";
import healthRoutes from "./routes/health.js";
import checksRoutes from "./routes/checks.js";
import workersRoutes from "./routes/workers.js";
import teamsRoutes from "./routes/teams.js";
import rolesRoutes from "./routes/roles.js";
import equipmentRoutes from "./routes/equipment.js";
import { requireAuth } from "./middleware/auth.js";

const app = express();

app.use(cors());
app.use(express.json());

// Connexion DB (charge aussi le .env via db.js)
await import("./db.js");

app.get("/health", (_, res) => res.json({ ok: true }));

app.use("/teams", requireAuth, teamsRoutes);
app.use("/workers", requireAuth, workersRoutes);
app.use("/checks", requireAuth, checksRoutes);
app.use("/dashboard", requireAuth, dashboardRoutes);
app.use("/attendance", requireAuth, attendanceRoutes);
app.use("/teams-meta", requireAuth, teamsMetaRouter);

// Roles & Equipment management (Chef + Direction)
app.use("/roles", requireAuth, rolesRoutes);
app.use("/equipment", requireAuth, equipmentRoutes);

app.use("/chefs", chefsRouter);
app.use("/health", healthRoutes);

const port = process.env.PORT || 3000;

// 404 JSON (route non trouvée)
app.use((req, res) => {
  res.status(404).json({ error: "Not found", path: req.originalUrl });
});

// Error handler JSON (erreurs serveur)
app.use((err, req, res, next) => {
  console.error("API ERROR:", err);
  res.status(500).json({ error: "Server error" });
});

app.listen(port, () => console.log(`API running on :${port}`));