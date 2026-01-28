import express from "express";
import { pool } from "../db.js";

const router = express.Router();

const UNASSIGNED_TEAM_ID = process.env.UNASSIGNED_TEAM_ID || "UNASSIGNED";

function makeWorkerIdFromEmployeeNumber(employeeNumber) {
  // garde lettres/chiffres/_/-
  const safe = String(employeeNumber).trim().replace(/[^a-zA-Z0-9_-]/g, "_");
  return `w_${safe}`;
}

/**
 * GET /teams/:teamId/workers
 * Liste les workers d'une équipe
 */
router.get("/:teamId/workers", async (req, res) => {
  const teamId = String(req.params.teamId);

  try {
    // Vérifie que l'équipe existe
    const t = await pool.query(`select 1 from teams where id = $1`, [teamId]);
    if (t.rowCount === 0) {
      return res.status(404).json({ error: "Team not found" });
    }

    const { rows } = await pool.query(
      `
      select
        w.id,
        w.name,
        w.employee_number as "employeeNumber",
        w.role,
        w.status,
        w.attendance,
        w.team_id as "teamId",
        w.controlled,
        w.last_check_at as "lastCheckAt"
      from workers w
      where w.team_id = $1
      order by w.name asc
      `,
      [teamId]
    );

    return res.json(rows);
  } catch (e) {
    console.error("GET /teams/:teamId/workers error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * GET /teams/:teamId/workers/lookup?employeeNumber=...
 * Recherche un worker par matricule, et indique s'il est déjà dans l'équipe
 */
router.get("/:teamId/workers/lookup", async (req, res) => {
  const teamId = String(req.params.teamId);
  const employeeNumber = String(req.query.employeeNumber || "").trim();

  if (!employeeNumber) {
    return res.status(400).json({ error: "Missing employeeNumber" });
  }

  try {
    // Vérifie que l'équipe existe
    const t = await pool.query(`select 1 from teams where id = $1`, [teamId]);
    if (t.rowCount === 0) {
      return res.status(404).json({ error: "Team not found" });
    }

    const { rows } = await pool.query(
      `
      select
        w.id,
        w.name,
        w.employee_number as "employeeNumber",
        w.role,
        w.attendance,
        w.status,
        w.controlled,
        w.last_check_at as "lastCheckAt",
        w.team_id as "teamId",
        tt.name as "teamName"
      from workers w
      join teams tt on tt.id = w.team_id
      where w.employee_number = $1
      limit 1
      `,
      [employeeNumber]
    );

    if (rows.length === 0) {
      return res.json({ found: false, employeeNumber });
    }

    const worker = rows[0];
    const inTeam = String(worker.teamId) === teamId;

    return res.json({
      found: true,
      employeeNumber,
      inTeam,
      worker,
    });
  } catch (e) {
    console.error("GET /teams/:teamId/workers/lookup error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * POST /teams/:teamId/workers
 * Body: { employeeNumber, name?, role? }
 *
 * - si employeeNumber existe déjà => move de team (+ optionnel: update role si fourni)
 * - sinon => crée un nouveau worker (name requis)
 */
router.post("/:teamId/workers", async (req, res) => {
  const teamId = String(req.params.teamId);

  const employeeNumber = String(req.body?.employeeNumber || "").trim();
  const name = String(req.body?.name || "").trim();
  const role = req.body?.role === null ? null : String(req.body?.role || "").trim();

  if (!employeeNumber) {
    return res.status(400).json({ error: "Missing employeeNumber" });
  }

  try {
    // Vérifie que l'équipe existe (y compris UNASSIGNED si présent en DB)
    const t = await pool.query(`select 1 from teams where id = $1`, [teamId]);
    if (t.rowCount === 0) {
      return res.status(404).json({ error: "Team not found" });
    }

    // Existe déjà ?
    const existing = await pool.query(
      `
      select id, team_id as "teamId"
      from workers
      where employee_number = $1
      limit 1
      `,
      [employeeNumber]
    );

    // ✅ MOVE (optionnel: update role si fourni)
    if (existing.rows.length > 0) {
      const workerId = existing.rows[0].id;

      const upd = await pool.query(
        `
        update workers
        set team_id = $1,
            role = coalesce($3, role)
        where id = $2
        returning
          id, name,
          employee_number as "employeeNumber",
          role,
          attendance, status, controlled,
          team_id as "teamId",
          last_check_at as "lastCheckAt"
        `,
        [
          teamId,
          workerId,
          role === "" ? null : role, // si null => garde l'ancien
        ]
      );

      return res.json({ ok: true, mode: "moved", worker: upd.rows[0] });
    }

    // ✅ CREATE
    if (!name) {
      return res.status(400).json({
        error: "Missing name (required when creating a new worker)",
      });
    }

    const workerId = makeWorkerIdFromEmployeeNumber(employeeNumber);

    const ins = await pool.query(
      `
      insert into workers (id, name, employee_number, role, attendance, status, controlled, team_id)
      values ($1, $2, $3, $4, 'PRESENT', 'OK', false, $5)
      returning
        id, name,
        employee_number as "employeeNumber",
        role,
        attendance, status, controlled,
        team_id as "teamId",
        last_check_at as "lastCheckAt"
      `,
      [workerId, name, employeeNumber, role === "" ? null : role, teamId]
    );

    return res.json({ ok: true, mode: "created", worker: ins.rows[0] });
  } catch (e) {
    // utile si tu te reprends un 23505
    if (e?.code === "23505") {
      return res.status(409).json({ error: "Employee number or worker id already exists" });
    }

    console.error("POST /teams/:teamId/workers error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * DELETE /teams/:teamId/workers/:workerId
 * Désassigner (envoie vers UNASSIGNED)
 */
router.delete("/:teamId/workers/:workerId", async (req, res) => {
  const workerId = String(req.params.workerId);

  try {
    // Vérifie que UNASSIGNED existe en teams
    const t = await pool.query(`select 1 from teams where id = $1`, [UNASSIGNED_TEAM_ID]);
    if (t.rowCount === 0) {
      return res.status(500).json({
        error: `UNASSIGNED team missing in DB (expected id=${UNASSIGNED_TEAM_ID})`,
      });
    }

    const upd = await pool.query(
      `
      update workers
      set team_id = $1
      where id = $2
      returning
        id, name,
        employee_number as "employeeNumber",
        role,
        attendance, status, controlled,
        team_id as "teamId",
        last_check_at as "lastCheckAt"
      `,
      [UNASSIGNED_TEAM_ID, workerId]
    );

    if (upd.rowCount === 0) {
      return res.status(404).json({ error: "Worker not found" });
    }

    return res.json({ ok: true, mode: "unassigned", worker: upd.rows[0] });
  } catch (e) {
    console.error("DELETE /teams/:teamId/workers/:workerId error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;