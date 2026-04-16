// POST /api/create-checkout
// Creates a Stripe Checkout session and returns the redirect URL.
//
// Environment variables required:
//   STRIPE_SECRET_KEY   — from Stripe Dashboard → Developers → API Keys
//   STRIPE_PRICE_ID     — create a one-time Price in Stripe Dashboard (e.g. $9.99)
//   SITE_URL            — your site, e.g. https://correctme.app

const Stripe = require("stripe");

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const PRICE_ID = process.env.STRIPE_PRICE_ID;
const SITE_URL = process.env.SITE_URL || "https://correctme.app";

module.exports = async (req, res) => {
  // CORS for the landing page
  res.setHeader("Access-Control-Allow-Origin", SITE_URL);
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(200).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  try {
    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      line_items: [{ price: PRICE_ID, quantity: 1 }],
      success_url: `${SITE_URL}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${SITE_URL}/#pricing`,
      // Collect email so we can use it in the webhook to generate the key
      customer_email: req.body?.email || undefined,
    });

    return res.json({ url: session.url });
  } catch (err) {
    console.error("Stripe error:", err.message);
    return res.status(500).json({ error: "Failed to create checkout session." });
  }
};
