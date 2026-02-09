import path from "path";
import dotenv from "dotenv";
import { Pool } from "pg";

// Charge TOUJOURS le .env à la racine du projet, peu importe le dossier depuis lequel tu lances `npm run dev`.
dotenv.config({ path: path.resolve(process.cwd(), ".env") });

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL manquante (le .env racine n'est pas lu)");
}

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

// Mini test au démarrage: si la DB est down, on préfère crasher net plutôt que de tourner en “semi-mort”.
await pool.query("select 1");

const info = await pool.query(`
  select
    current_database() as db,
    current_schema() as schema,
    inet_server_addr() as server_ip,
    version() as version
`);
console.log("DB INFO =", info.rows[0]);

const cols = await pool.query(`
  select column_name
  from information_schema.columns
  where table_schema='public' and table_name='briefing_topic_checks'
  order by ordinal_position
`);
console.log("briefing_topic_checks columns =", cols.rows.map(r => r.column_name));