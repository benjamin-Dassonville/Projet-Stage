import jwt from "jsonwebtoken";
import jwksClient from "jwks-rsa";

const tenantId = process.env.AZURE_TENANT_ID;
const audience = process.env.AZURE_CLIENT_ID; // l'App Registration (API) ou le clientId selon ton flux

const client = jwksClient({
  jwksUri: `https://login.microsoftonline.com/${tenantId}/discovery/v2.0/keys`,
});

function getKey(header, callback) {
  client.getSigningKey(header.kid, function (err, key) {
    if (err) return callback(err);
    const signingKey = key.getPublicKey();
    callback(null, signingKey);
  });
}

export function requireAuth(req, res, next) {
  // DEV shortcut (so you can build the MVP without Microsoft auth yet)
  // Usage: Authorization: Dev chef|admin|direction
  if (process.env.DEV_AUTH === "1") {
    const auth = req.headers.authorization || "";
    if (auth.startsWith("Dev ")) {
      const role = auth.slice(4).trim();
      req.user = { dev: true, role };
      return next();
    }
  }

  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;

  if (!token) return res.status(401).json({ error: "Missing Bearer token" });

  jwt.verify(
    token,
    getKey,
    {
      algorithms: ["RS256"],
      audience,
      issuer: `https://login.microsoftonline.com/${tenantId}/v2.0`,
    },
    (err, decoded) => {
      if (err) return res.status(401).json({ error: "Invalid token", details: err.message });
      req.user = decoded; // contient email/upn, oid, etc.
      next();
    }
  );
}