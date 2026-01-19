export const store = {
  workerStatus: new Map(),     // workerId -> "OK" | "KO"
  attendance: new Map(),       // workerId -> "PRESENT" | "ABS"
};