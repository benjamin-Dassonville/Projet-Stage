import fs from "fs";
import path from "path";
import xlsx from "xlsx";

// ========== CONFIG ==========
const INPUT_XLSX = process.argv[2]; // ex: ./data/rh.xlsx
if (!INPUT_XLSX) {
  console.error("Usage: node import_teams_from_rh_xlsx.js <path_to_xlsx>");
  process.exit(1);
}

// ========== HELPERS ==========
function slugify(str) {
  // garde le rendu "name" intact ailleurs, ici on fabrique juste un ID stable
  return String(str)
    .trim()
    .normalize("NFD")                  // sépare accents
    .replace(/[\u0300-\u036f]/g, "")   // enlève accents
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")       // tout le reste -> _
    .replace(/^_+|_+$/g, "");          // trim _
}

function sqlEscape(str) {
  return String(str).replace(/'/g, "''");
}

// ========== READ XLSX ==========
const wb = xlsx.readFile(INPUT_XLSX);
const sheetName = wb.SheetNames[0];
const ws = wb.Sheets[sheetName];

// JSON: header auto par la 1ère ligne
const rows = xlsx.utils.sheet_to_json(ws, { defval: "" });

// On ignore les “lignes mortes” que tu as mentionnées :
// - ligne où login est vide
// - ligne où manager est vide + first/last vides etc.
const cleaned = rows.filter((r) => {
  const login = String(r.login || "").trim();
  const manager = String(r.manager || "").trim();
  const firstName = String(r.firstName || "").trim();
  const lastName = String(r.lastName || "").trim();

  // Tu as dit : "première ligne inutile / ligne morte" -> on filtre les lignes vides
  if (!login && !manager && !firstName && !lastName) return false;
  // si login = "paie" ou autre compte générique tu peux filtrer ici si besoin
  return true;
});

// ========== EXTRACT MANAGERS ==========
const managers = new Map(); // key = manager exact, value = {chefId, teamId, managerName}

for (const r of cleaned) {
  const managerName = String(r.manager || "").trim();
  if (!managerName) continue; // (au cas où) ira dans UNASSIGNED plus tard

  const base = slugify(managerName);
  if (!base) continue;

  const chefId = `chef_${base}`;
  const teamId = `team_${base}`;

  if (!managers.has(managerName)) {
    managers.set(managerName, { chefId, teamId, managerName });
  }
}

// ========== BUILD SQL ==========
let sql = "";
sql += "BEGIN;\n\n";

// optionnel (si tu veux repartir clean sur chefs/teams à chaque import)
// sql += "TRUNCATE TABLE teams;\n";
// sql += "TRUNCATE TABLE chefs;\n\n";

sql += "INSERT INTO chefs(id, name)\nVALUES\n";
sql += Array.from(managers.values())
  .map((m) => `('${sqlEscape(m.chefId)}', '${sqlEscape(m.managerName)}')`)
  .join(",\n");
sql += "\nON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;\n\n";

sql += "INSERT INTO teams(id, name, chef_id)\nVALUES\n";
sql += Array.from(managers.values())
  .map((m) => `('${sqlEscape(m.teamId)}', '${sqlEscape("Équipe " + m.managerName)}', '${sqlEscape(m.chefId)}')`)
  .join(",\n");
sql += "\nON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, chef_id = EXCLUDED.chef_id;\n\n";

// UNASSIGNED si pas déjà là
sql += "INSERT INTO teams(id, name, chef_id)\n";
sql += "VALUES ('UNASSIGNED', 'Non affectés', NULL)\n";
sql += "ON CONFLICT (id) DO NOTHING;\n\n";

sql += "COMMIT;\n";

// ========== OUTPUT ==========
const outPath = path.resolve(process.cwd(), "import_teams.sql");
fs.writeFileSync(outPath, sql, "utf8");
console.log(`✅ SQL généré: ${outPath}`);
console.log(`➡️  Managers trouvés: ${managers.size}`);