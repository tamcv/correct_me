// POST /api/webhook
// Stripe webhook handler. On successful payment: generates license key + emails it.
//
// Environment variables required:
//   STRIPE_SECRET_KEY         — Stripe secret key
//   STRIPE_WEBHOOK_SECRET     — from Stripe Dashboard → Webhooks → signing secret
//   RESEND_API_KEY            — from resend.com (free: 3000 emails/month)
//   EMAIL_FROM                — e.g. "CorrectMe <license@correctme.app>"
//   LICENSE_SECRET            — must match Sources/LicenseManager.swift

const Stripe = require("stripe");
const { Resend } = require("resend");
const { generateKey } = require("../lib/license");

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const resend = new Resend(process.env.RESEND_API_KEY);
const FROM = process.env.EMAIL_FROM || "CorrectMe <license@correctme.app>";
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).end();

  // Verify Stripe signature to prevent spoofing
  let event;
  try {
    const rawBody = await getRawBody(req);
    event = stripe.webhooks.constructEvent(rawBody, req.headers["stripe-signature"], WEBHOOK_SECRET);
  } catch (err) {
    console.error("Webhook signature error:", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Only process successful payments
  if (event.type !== "checkout.session.completed") {
    return res.json({ received: true });
  }

  const session = event.data.object;
  const email = session.customer_details?.email || session.customer_email;

  if (!email) {
    console.error("No email in session:", session.id);
    return res.status(400).json({ error: "No customer email found" });
  }

  const licenseKey = generateKey(email);
  console.log(`License generated for ${email}: ${licenseKey}`);

  // Send license email
  try {
    await resend.emails.send({
      from: FROM,
      to: email,
      subject: "Your CorrectMe License Key",
      html: licenseEmailHTML(email, licenseKey),
    });
    console.log(`License email sent to ${email}`);
  } catch (err) {
    // Don't fail the webhook — log and investigate manually
    console.error("Email send failed:", err.message);
  }

  return res.json({ received: true });
};

function licenseEmailHTML(email, key) {
  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 520px; margin: 0 auto; padding: 32px 16px; color: #1a1a1a;">
  <h1 style="font-size: 24px; margin-bottom: 8px;">Thank you for buying CorrectMe! ✏️</h1>
  <p style="color: #555; margin-bottom: 32px;">Here is your license key. Keep this email safe.</p>

  <div style="background: #f5f5f7; border-radius: 12px; padding: 24px; text-align: center; margin-bottom: 32px;">
    <p style="font-size: 12px; color: #888; margin: 0 0 8px;">LICENSE KEY</p>
    <p style="font-family: 'SF Mono', Menlo, monospace; font-size: 22px; letter-spacing: 2px; font-weight: 600; margin: 0; color: #1a1a1a;">${key}</p>
    <p style="font-size: 12px; color: #888; margin: 8px 0 0;">Registered to: ${email}</p>
  </div>

  <h2 style="font-size: 16px; margin-bottom: 12px;">How to activate</h2>
  <ol style="color: #555; padding-left: 20px; line-height: 1.8;">
    <li>Click the CorrectMe ✏️ icon in your menu bar</li>
    <li>Select <strong>Activate License…</strong></li>
    <li>Enter your email and paste the key above</li>
    <li>Click <strong>Activate</strong></li>
  </ol>

  <hr style="border: none; border-top: 1px solid #e5e5e5; margin: 32px 0;">

  <p style="font-size: 12px; color: #aaa;">
    Need help? Reply to this email.<br>
    CorrectMe — AI text correction for macOS
  </p>
</body>
</html>`;
}

// Vercel gives us a readable stream, not a Buffer — read it manually
function getRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}
