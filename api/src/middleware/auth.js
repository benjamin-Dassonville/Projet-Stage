import "../env.js";
import { createClient } from "@supabase/supabase-js";
import { pool } from "../db.js";

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } },
);

export async function requireAuth(req, res, next) {
  try {
    const h = req.headers.authorization || "";
    const m = h.match(/^Bearer (.+)$/i);
    if (!m) return res.status(401).json({ error: "Missing Bearer token" });

    const token = m[1];

    const { data, error } = await supabaseAdmin.auth.getUser(token);
    if (error || !data?.user) {
      return res.status(401).json({ error: "Invalid token" });
    }

    const user = data.user;

    // récupère le role applicatif dans profiles
    const prof = await pool.query(
      `select role from profiles where id = $1 limit 1`,
      [user.id],
    );

    let role = "non_assigne";
    if (prof.rows.length > 0 && prof.rows[0].role) role = prof.rows[0].role;

    req.user = {
      id: user.id,
      email: user.email,
      role,
    };

    return next();
  } catch (e) {
    console.error("requireAuth error:", e);
    return res.status(500).json({ error: "Server error" });
  }
}
