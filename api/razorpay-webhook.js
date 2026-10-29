import crypto from 'node:crypto';
import { createClient } from '@supabase/supabase-js';

// Raw body is needed to verify Razorpay's signature, so Vercel must not parse it.
export const config = { api: { bodyParser: false } };

const admin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false }
});

// Amounts are in paise. Only these exact amounts activate a plan.
const PLANS = { 3900: 'plus', 6900: 'pro' };
const DAYS = 30;

function readRaw(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
  if (!secret) return res.status(500).json({ error: 'Webhook not configured' });

  const raw = await readRaw(req);
  const sig = String(req.headers['x-razorpay-signature'] || '');
  const expected = crypto.createHmac('sha256', secret).update(raw).digest('hex');
  const valid =
    sig.length === expected.length &&
    crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected));
  if (!valid) return res.status(400).json({ error: 'Invalid signature' });

  let event;
  try {
    event = JSON.parse(raw.toString('utf8'));
  } catch {
    return res.status(400).json({ error: 'Bad JSON' });
  }

  // Only successful payment links matter. Everything else is acknowledged and ignored.
  if (event.event !== 'payment_link.paid') return res.status(200).json({ ignored: event.event });

  const payment = event.payload?.payment?.entity || {};
  const link = event.payload?.payment_link?.entity || {};
  const email = String(payment.email || link.customer?.email || '').trim().toLowerCase();
  const plan = PLANS[payment.amount];

  // 200 so Razorpay does not retry for something we cannot match.
  if (!email || !plan) {
    console.warn('razorpay-webhook: unmatched payment', { amount: payment.amount, hasEmail: !!email });
    return res.status(200).json({ ignored: 'unknown amount or missing email' });
  }

  const { data: prof, error: findErr } = await admin
    .from('profiles')
    .select('id, plan')
    .eq('email', email)
    .maybeSingle();
  if (findErr) return res.status(500).json({ error: 'Lookup failed' });
  if (!prof) {
    console.warn('razorpay-webhook: no account for email', { email });
    return res.status(200).json({ ignored: 'no matching account' });
  }

  const expires = new Date(Date.now() + DAYS * 24 * 60 * 60 * 1000).toISOString();
  const { error: upErr } = await admin
    .from('profiles')
    .update({ plan, plan_expires_at: expires })
    .eq('id', prof.id);
  if (upErr) return res.status(500).json({ error: 'Update failed' });

  return res.status(200).json({ ok: true, plan });
}
