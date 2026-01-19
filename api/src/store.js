export const store = {
  workerStatus: new Map(),
  attendance: new Map(),
};

// ✅ MVP: chefs + teams (remplaçables plus tard par DB)
export const chefs = [
  { id: "c1", name: "Pierre" },
  { id: "c2", name: "Alexandre" },
];

export const teams = [
  { id: "1", name: "Équipe 1", chefId: "c2" },
  { id: "2", name: "Équipe 2", chefId: "c2" },
];