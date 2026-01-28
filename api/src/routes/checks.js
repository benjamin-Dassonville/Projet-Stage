import express from "express";
import { pool } from "../db.js";

const router = express.Router();

const ALLOWED_ITEM_STATUS = new Set(["OK", "MANQUANT", "KO"]);

// ✅ result global : KO > NON_CONFORME > CONFORME
function computeResult(items) {
  const hasKO = items.some((it) => it.status === "KO");
  if (hasKO) return "KO";

  const hasMissing = items.some((it) => it.status === "MANQUANT");
  if (hasMissing) return "NON_CONFORME";

  return "CONFORME";
}

function workerStatusFromResult(result) {
  if (result === "CONFORME") return "OK";
  if (result === "NON_CONFORME") return "NON_CONFORME";
  return "KO";
}

// POST /checks
// body: { workerId: "w1", teamId:"t1", items:[{equipmentId:"botte", status:"OK"}] }
router.post("/", async (req, res) => {
  console.log("POST /checks AUTH =", req.headers.authorization);
  console.log("POST /checks body =", req.body);

  const client = await pool.connect();
  try {
    const { workerId, teamId, items } = req.body ?? {};

    // 1) validation payload
    if (!workerId || !teamId) {
      return res
        .status(400)
        .json({ error: "Invalid payload: workerId/teamId required" });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res
        .status(400)
        .json({ error: "Invalid payload: items must be a non-empty array" });
    }

    for (const it of items) {
      if (!it?.equipmentId || !ALLOWED_ITEM_STATUS.has(it.status)) {
        return res.status(400).json({
          error:
            "Invalid payload: each item needs equipmentId + status in OK|MANQUANT|KO",
        });
      }
    }

    // 2) worker existe + team + attendance + role
    const wRes = await client.query(
      `
      select id, team_id as "teamId", attendance, role, name
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
      return res
        .status(400)
        .json({ error: "Worker does not belong to this team" });
    }

    if (w.attendance === "ABS") {
      return res
        .status(400)
        .json({ error: "Worker is ABSENT, cannot submit check" });
    }

    // 3) Vérifier que les equipmentId existent
    const uniqueEq = Array.from(new Set(items.map((it) => String(it.equipmentId))));

    const eqRes = await client.query(
      `
      select id, name, max_misses_before_notif as "maxMissesBeforeNotif"
      from equipment
      where id = any($1)
      `,
      [uniqueEq]
    );

    const found = new Map(eqRes.rows.map((r) => [String(r.id), r]));
    const missing = uniqueEq.filter((id) => !found.has(String(id)));
    if (missing.length > 0) {
      return res.status(400).json({ error: "Unknown equipmentId(s)", missing });
    }

    // 4) vérifier équipements autorisés par rôle
    if (w.role) {
      const roleEqRes = await client.query(
        `
        select re.equipment_id as id
        from role_equipment re
        where re.role_id = $1
          and re.equipment_id = any($2)
        `,
        [String(w.role), uniqueEq]
      );
      const allowed = new Set(roleEqRes.rows.map((r) => String(r.id)));
      const notAllowed = uniqueEq.filter((id) => !allowed.has(String(id)));
      if (notAllowed.length > 0) {
        return res.status(400).json({
          error: "Equipment not allowed for worker role",
          role: w.role,
          notAllowed,
        });
      }
    }

    // 5) résultat global
    const result = computeResult(items);
    const newWorkerStatus = workerStatusFromResult(result);

    // 6) transaction atomique
    await client.query("begin");

    // insert checks
    const checkRes = await client.query(
      `
      insert into checks(worker_id, team_id, role, result, created_at)
      values ($1, $2, $3, $4, now())
      returning id
      `,
      [String(workerId), String(teamId), w.role ?? null, result]
    );

    const checkId = checkRes.rows[0].id;

    // insert items
    for (const it of items) {
      await client.query(
        `
        insert into check_items(check_id, equipment_id, status)
        values ($1, $2, $3)
        `,
        [checkId, String(it.equipmentId), String(it.status)]
      );
    }

    // update worker (status lisible)
    await client.query(
      `
      update workers
      set status = $2,
          controlled = true,
          last_check_at = now()
      where id = $1
      `,
      [String(workerId), newWorkerStatus]
    );

    // 7) règle "misses" + notification
    // KO compte aussi ✅ (KO + MANQUANT)
    const missItems = items.filter(
      (it) => it.status === "MANQUANT" || it.status === "KO"
    );

    for (const it of missItems) {
      const equipmentId = String(it.equipmentId);
      const eq = found.get(equipmentId);
      const max = Number(eq?.maxMissesBeforeNotif ?? 0);

      // upsert compteur
      const up = await client.query(
        `
        insert into worker_equipment_misses(worker_id, equipment_id, miss_count, last_miss_at)
        values ($1, $2, 1, now())
        on conflict (worker_id, equipment_id)
        do update set
          miss_count = worker_equipment_misses.miss_count + 1,
          last_miss_at = now()
        returning miss_count, notified_at
        `,
        [String(workerId), equipmentId]
      );

      const missCount = Number(up.rows[0]?.miss_count ?? 0);
      const notifiedAt = up.rows[0]?.notified_at ?? null;

      // notif seulement si max>0 et on atteint la limite, et pas déjà notifié
      if (max > 0 && missCount >= max && !notifiedAt) {
        // récupérer chef_id de l'équipe (si existe)
        const t = await client.query(
          `select chef_id as "chefId", name from teams where id = $1 limit 1`,
          [String(teamId)]
        );
        const chefId = t.rows[0]?.chefId ?? null;
        const teamName = t.rows[0]?.name ?? String(teamId);

        const workerName = w.name ?? String(workerId);
        const equipName = eq?.name ?? equipmentId;

        const message = `Limite atteinte (${missCount}/${max}) : ${workerName} a oublié / KO "${equipName}" (équipe ${teamName}). RDV redressement.`;

        await client.query(
          `
          insert into notifications(type, team_id, chef_id, worker_id, equipment_id, message)
          values ($1, $2, $3, $4, $5, $6)
          `,
          [
            "EQUIPMENT_MISS_LIMIT_REACHED",
            String(teamId),
            chefId,
            String(workerId),
            equipmentId,
            message,
          ]
        );

        // verrou anti-spam : on marque notified_at
        await client.query(
          `
          update worker_equipment_misses
          set notified_at = now()
          where worker_id = $1 and equipment_id = $2
          `,
          [String(workerId), equipmentId]
        );
      }
    }

    await client.query("commit");
    return res.json({ ok: true, checkId: String(checkId), result });
  } catch (e) {
    try {
      await client.query("rollback");
    } catch (_) {}

    console.error("POST /checks error:", e);
    return res.status(500).json({ error: "Server error" });
  } finally {
    client.release();
  }
});

export default router;