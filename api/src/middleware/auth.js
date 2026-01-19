export function requireAuth(req, res, next) {
  if (process.env.DEV_AUTH === "1") {
    const auth = req.headers.authorization || "";
    if (auth.startsWith("Dev ")) {
      const role = auth.slice(4).trim();
      req.user = { dev: true, role };
      return next();
    }
  }

  return res.status(401).json({ error: "Unauthorized" });
}