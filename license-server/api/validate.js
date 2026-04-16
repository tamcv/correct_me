// POST /api/validate
// Validates a license key server-side.
// The app uses offline HMAC validation; this endpoint is optional but useful
// for future revocation support.
//
// Request body: { "email": "...", "key": "XXXX-XXXX-XXXX-XXXX" }
// Response:     { "valid": true }  |  { "valid": false, "reason": "..." }

const { validateKey } = require("../lib/license");

module.exports = (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(200).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { email, key } = req.body || {};

  if (!email || !key) {
    return res.status(400).json({ valid: false, reason: "email and key are required" });
  }

  const isValid = validateKey(email, key);
  if (isValid) {
    return res.json({ valid: true });
  } else {
    return res.status(403).json({ valid: false, reason: "invalid_key" });
  }
};
