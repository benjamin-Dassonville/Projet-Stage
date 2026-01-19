import { store } from "../store.js";

// Génère des IDs uniques globalement : "<teamId>-<localId>"
function wid(teamId, localId) {
  return `${String(teamId)}-${String(localId)}`;
}

export function getTeamWorkers(teamId) {
  // ⚠️ Demo data. L’important = IDs uniques + teamId présent.
  // Tu peux changer les noms plus tard sans impact.
  const base =
    String(teamId) === "1"
      ? [
          { id: wid(teamId, 1), name: "Loïc Durant", status: "OK", teamId: String(teamId) },
          { id: wid(teamId, 2), name: "Jean Martin", status: "KO", teamId: String(teamId) },
          { id: wid(teamId, 3), name: "Paul Leroy", status: "OK", teamId: String(teamId) },
        ]
      : [
          { id: wid(teamId, 1), name: "Sofia Bernard", status: "OK", teamId: String(teamId) },
          { id: wid(teamId, 2), name: "Nadia Benali", status: "KO", teamId: String(teamId) },
          { id: wid(teamId, 3), name: "Hugo Morel", status: "OK", teamId: String(teamId) },
        ];

  return base.map((w) => {
    const workerId = String(w.id);

    // attendance défaut PRESENT
    const att = store.attendance.get(workerId) ?? "PRESENT";
    if (att === "ABS") {
      return { ...w, attendance: "ABS", status: "ABS", controlled: false };
    }

    // statut = dernier contrôle si existe
    const saved = store.workerStatus.get(workerId); // "OK" | "KO" | undefined
    const status = saved ?? w.status;

    // contrôlé = présent + déjà un statut enregistré
    const controlled = store.workerStatus.has(workerId);

    return { ...w, attendance: "PRESENT", status, controlled };
  });
}