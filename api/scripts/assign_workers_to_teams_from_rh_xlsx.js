import fs from "fs";
import path from "path";
import xlsx from "xlsx";

import { pool } from "../src/db.js"; // adapte si ton db.js exporte autrement

const filePath = process.argv[2];
if (!filePath) {
  console.error('Usage: node api/scripts/assign_workers_to_teams_from_rh_xlsx.js "<path.xlsx>"');
  process.exit(1);
}

function normStr(s) {
  return String(s ?? "")
    .trim()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "") // enlève accents pour comparer
    .toLowerCase();
}

function workerName(firstName, lastName) {
  // Tu as dit: accents/majuscules on les respecte => on prend tel quel
  return `${String(firstName ?? "").trim()} ${String(lastName ?? "").trim()}`.trim();
}

(async () => {
  const wb = xlsx.readFile(filePath);
  const sheetName = wb.SheetNames[0];
  const ws = wb.Sheets[sheetName];

  const rows = xlsx.utils.sheet_to_json(ws, { defval: null });

  // On garde uniquement rolePrincipal == "Utilisateur"
  const users = rows.filter(r => String(r.rolePrincipal ?? "").trim() === "Utilisateur");

  // Précharge chefs+teams pour matcher en mémoire
  const chefsRes = await pool.query(`select id, name from chefs`);
  const teamsRes = await pool.query(`select id, name, chef_id from teams`);

  const chefs = chefsRes.rows.map(c => ({ ...c, _n: normStr(c.name) }));
  const teams = teamsRes.rows.map(t => ({ ...t }));

  // Map: managerNormalized -> teamId (via chefs.name == manager)
  const managerToTeamId = new Map();
  for (const c of chefs) {
    const team = teams.find(t => String(t.chef_id) === String(c.id));
    if (team) managerToTeamId.set(c._n, String(team.id));
  }

  let updated = 0;
  let unassigned = 0;

  // Génère un SQL d’updates (tu peux aussi exécuter directement)
  const out = [];
  out.push("-- Generated workers team assignment");
  out.push("begin;");

  for (const r of users) {
    // ignore lignes “mortes” si jamais
    const login = String(r.login ?? "").trim();
    if (!login || login === "paie") continue;

    const mgr = String(r.manager ?? "").trim();
    const mgrKey = normStr(mgr);
    const teamId = managerToTeamId.get(mgrKey) ?? "UNASSIGNED";

    const name = workerName(r.firstName, r.lastName);

    // IMPORTANT: on ne crée pas les équipes ici, on ASSIGNE uniquement
    // On update le worker existant par name (ou tu peux par id si tu veux)
    out.push(
      `update workers set team_id = '${teamId.replace(/'/g, "''")}' where name = '${name.replace(/'/g, "''")}';`
    );

    if (teamId === "UNASSIGNED") unassigned++;
    else updated++;
  }

  out.push("commit;");

  const outPath = path.resolve(process.cwd(), "assign_workers_teams.sql");
  fs.writeFileSync(outPath, out.join("\n"), "utf8");

  console.log("✅ SQL généré:", outPath);
  console.log("➡️ Utilisateurs traités:", users.length);
  console.log("✅ Affectés à une team:", updated);
  console.log("⚠️ Restés UNASSIGNED:", unassigned);

  process.exit(0);
})().catch((e) => {
  console.error("Script error:", e);
  process.exit(1);
});