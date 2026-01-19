import { store } from "../store.js";

export function getTeamWorkers(teamId) {
  // Base fake (MVP). Plus tard: DB.
  const base = [
    { id: "1", name: "Loïc Durant", status: "OK", teamId },
    { id: "2", name: "Jean Martin", status: "KO", teamId },
    { id: "3", name: "Paul Leroy", status: "OK", teamId },
  ];

  return base.map((w) => {
    const workerId = String(w.id);

    // attendance défaut PRESENT
    const att = store.attendance.get(workerId) ?? "PRESENT";
    if (att === "ABS") {
      return { ...w, attendance: "ABS", status: "ABS" };
    }

    // statut = dernier contrôle si existe
    const saved = store.workerStatus.get(workerId); // "OK" | "KO" | undefined
    const status = saved ?? w.status;

    // non contrôlé = présent mais jamais contrôlé (pas dans workerStatus)
    const controlled = store.workerStatus.has(workerId);

    return { ...w, attendance: "PRESENT", status, controlled };
  });
}