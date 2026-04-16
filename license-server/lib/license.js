// license.js — License key generation and validation.
// Keep LICENSE_SECRET in sync with Sources/LicenseManager.swift.
// Store the actual secret in a Vercel environment variable: LICENSE_SECRET

const crypto = require("crypto");

const SECRET = process.env.LICENSE_SECRET || "CHANGE_ME_BEFORE_SHIPPING_32BYTE_SECRET_KEY_HERE";
const PRODUCT = "correctme";

// Base32 alphabet (RFC 4648, uppercase, no padding)
const BASE32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

function base32Encode(buf) {
  let result = "";
  let buffer = 0;
  let bitsLeft = 0;

  for (const byte of buf) {
    buffer = (buffer << 8) | byte;
    bitsLeft += 8;
    while (bitsLeft >= 5) {
      bitsLeft -= 5;
      result += BASE32[(buffer >> bitsLeft) & 0x1f];
    }
  }
  if (bitsLeft > 0) {
    result += BASE32[(buffer << (5 - bitsLeft)) & 0x1f];
  }
  return result;
}

/**
 * Generate a license key for a given email.
 * Format: XXXX-XXXX-XXXX-XXXX (16 base32 chars in 4 groups of 4)
 */
function generateKey(email) {
  const normalized = email.trim().toLowerCase();
  const mac = crypto
    .createHmac("sha256", SECRET)
    .update(`${normalized}|${PRODUCT}`)
    .digest();

  // Take first 10 bytes → 16 base32 chars
  const raw = base32Encode(mac.slice(0, 10));
  return raw.match(/.{1,4}/g).join("-"); // XXXX-XXXX-XXXX-XXXX
}

/**
 * Validate a license key against an email.
 */
function validateKey(email, key) {
  const expected = generateKey(email);
  const normalize = (s) => s.replace(/-/g, "").replace(/\s/g, "").toUpperCase();
  return normalize(expected) === normalize(key);
}

module.exports = { generateKey, validateKey };
