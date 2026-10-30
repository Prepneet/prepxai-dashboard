import { adminClient, cashfreeRequest, json, verifyWebhookSignature } from './_cashfree.js';

export const config = { api: { bodyParser: false } };

function readRaw(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

export default async function handler(req, res) {
  if (req.method !== 'POST') return json(res, 405, { error: 'Method not allowed' });
  const raw = await readRaw(req);
  const timestamp = req.headers['x-webhook-timestamp'];
  const signature = req.headers['x-webhook-signature'];
  if (!verifyWebhookSignature(raw, timestamp, signature)) return json(res, 400, { error: 'Invalid signature' });

  let event;
  try { event = JSON.parse(raw.toString('utf8')); }
  catch { return json(res, 400, { error: 'Invalid JSON' }); }

  const orderId = String(event.data?.order?.order_id || event.order_id || '');
  const paymentStatus = event.data?.payment?.payment_status;
  const paymentId = event.data?.payment?.cf_payment_id;
  if (!orderId || paymentStatus !== 'SUCCESS' || !paymentId) return json(res, 200, { received: true, ignored: true });

  try {
    const admin = adminClient();
    const { data: order } = await admin.from('payment_orders').select('order_id, status').eq('order_id', orderId).maybeSingle();
    if (!order) return json(res, 200, { received: true, ignored: true });
    const confirmed = await cashfreeRequest('/orders/' + encodeURIComponent(orderId));
    if (confirmed.order_status !== 'PAID') return json(res, 200, { received: true, pending: true });
    const { error } = await admin.rpc('activate_cashfree_order', {
      p_order_id: orderId,
      p_cf_payment_id: String(paymentId),
    });
    if (error) throw error;
    return json(res, 200, { received: true, activated: true });
  } catch (e) {
    console.error('Cashfree webhook processing failed:', e.message);
    return json(res, 500, { error: 'Webhook processing failed' });
  }
}
