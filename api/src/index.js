import "./env.js";
import express from "express";
import dotenv from "dotenv";
dotenv.config({ path: "api/.env" });


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
import missesRoutes from "./routes/misses.js";
import calendarRouter from "./routes/calendar.js";
import checkAuditsRouter from "./routes/check_audits.js";
import briefingsRouter from "./routes/briefings.js";


import adminUsersRouter from "./routes/admin_users.js";



const app = express();

app.use(cors());
app.use(express.json());

// Désactiver ETag pour éviter les 304 Not Modified
app.set("etag", false);

// Connexion DB (charge aussi le .env via db.js)
await import("./db.js");

app.get("/health", (_, res) => res.json({ ok: true }));

app.use("/teams", requireAuth, teamsRoutes);
app.use("/workers", requireAuth, workersRoutes);
app.use("/checks", requireAuth, checksRoutes);
app.use("/dashboard", requireAuth, dashboardRoutes);
app.use("/attendance", requireAuth, attendanceRoutes);
app.use("/teams-meta", requireAuth, teamsMetaRouter);
app.use("/briefings", requireAuth, briefingsRouter);
app.use("/roles", requireAuth, rolesRoutes);
app.use("/equipment", requireAuth, equipmentRoutes);
app.use("/misses", requireAuth, missesRoutes);
app.use("/calendar", requireAuth, calendarRouter);


app.use("/chefs", chefsRouter);
app.use("/health", healthRoutes);
app.use("/check-audits", checkAuditsRouter);
app.use("/admin", adminUsersRouter);



app.use(requireAuth);

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

// ✅ Écoute sur le réseau (important pour téléphone)
app.listen(port, "0.0.0.0", () => {
  console.log(`API running on :${port}`);
});