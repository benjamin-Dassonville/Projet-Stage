import { pool } from "../db.js";

/**
 * Retourne la liste des workers d'une équipe au format attendu par Flutter:
 * [{ id, name, status, attendance, teamId, controlled }]
 */
export async function getTeamWorkersDb(teamId) {
  const { rows } = await pool.query(
    `
    select
      id,
      name,
      status,
      attendance,
      team_id as "teamId",
      controlled
    from workers
    where team_id = $1
    order by name asc
    `,
    [teamId]
  );

  return rows;
}