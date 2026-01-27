import express from "express";
import { pool } from "../db.js";

const router = express.Router();

const ALLOWED_ITEM_STATUS = new Set(["OK", "MANQUANT", "KO"]);

function computeResult(items) {
  const bad = items.some((it) => it.status === "MANQUANT" || it.status === "KO");
  return bad ? "NON_CONFORME" : "CONFORME";
}

// POST /checks
// body: { workerId: "1-2", teamId:"1", items:[{equipmentId:"botte", status:"OK"}] }
router.post("/", async (req, res) => {
  // ✅ DEBUG ICI (req existe ici)
  console.log("POST /checks AUTH =", req.headers.authorization);
  console.log("POST /checks body =", req.body);

  try {
    const { workerId, teamId, items } = req.body ?? {};

    // 1) validation payload
    if (!workerId || !teamId) {
      return res.status(400).json({ error: "Invalid payload: workerId/teamId required" });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: "Invalid payload: items must be a non-empty array" });
    }

    for (const it of items) {
      if (!it?.equipmentId || !ALLOWED_ITEM_STATUS.has(it.status)) {
        return res.status(400).json({
          error: "Invalid payload: each item needs equipmentId + status in OK|MANQUANT|KO",
        });
      }
    }

    // 2) worker existe + appartient à l'équipe + attendance
    const wRes = await pool.query(
      `
      select id, team_id as "teamId", attendance, role
      from workers
      where id = $1
      limit 1
      `,
      [String(workerId)]
    );

    if (wRes.rowCount === 0) {
      return res.status(404).json({ error: "Worker not found" });
    }

    const w = wRes.rows[0];

    if (String(w.teamId) !== String(teamId)) {
      return res.status(400).json({ error: "Worker does not belong to this team" });
    }

    if (w.attendance === "ABS") {
      return res.status(400).json({ error: "Worker is ABSENT, cannot submit check" });
    }

    // 3) Vérifier que les equipmentId existent
    const uniqueEq = Array.from(new Set(items.map((it) => String(it.equipmentId))));
    const eqRes = await pool.query(
      `select id from equipment where id = any($1)`,
      [uniqueEq]
    );

    const found = new Set(eqRes.rows.map((r) => String(r.id)));
    const missing = uniqueEq.filter((id) => !found.has(id));
    if (missing.length > 0) {
      return res.status(400).json({ error: "Unknown equipmentId(s)", missing });
    }

    // 4) vérifier que ces équipements font partie du rôle du worker
    if (w.role) {
      const roleEqRes = await pool.query(
        `
        select re.equipment_id as id
        from role_equipment re
        where re.role_id = $1
          and re.equipment_id = any($2)
        `,
        [String(w.role), uniqueEq]
      );
      const allowed = new Set(roleEqRes.rows.map((r) => String(r.id)));
      const notAllowed = uniqueEq.filter((id) => !allowed.has(id));
      if (notAllowed.length > 0) {
        return res.status(400).json({
          error: "Equipment not allowed for worker role",
          role: w.role,
          notAllowed,
        });
      }
    }

    // 5) calcul résultat côté serveur
    const result = computeResult(items);

    // 6) transaction DB atomique
    await pool.query("begin");

    const checkRes = await pool.query(
      `
      insert into checks(worker_id, team_id, role, result, created_at)
      values ($1, $2, $3, $4, now())
      returning id
      `,
      [String(workerId), String(teamId), w.role ?? null, result]
    );

    const checkId = checkRes.rows[0].id;

    for (const it of items) {
      await pool.query(
        `
        insert into check_items(check_id, equipment_id, status)
        values ($1, $2, $3)
        `,
        [checkId, String(it.equipmentId), String(it.status)]
      );
    }

    const newStatus = result === "CONFORME" ? "OK" : "KO";
    await pool.query(
      `
      update workers
      set status = $2,
          controlled = true,
          last_check_at = now()
      where id = $1
      `,
      [String(workerId), newStatus]
    );

    await pool.query("commit");

    return res.json({ ok: true, checkId: String(checkId), result });
  } catch (e) {
    try {
      await pool.query("rollback");
    } catch (_) {}

    console.error("POST /checks error:", e);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;