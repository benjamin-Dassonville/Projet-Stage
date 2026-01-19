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