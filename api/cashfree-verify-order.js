import {
  adminClient, cashfreeRequest, getUser, json,
} from './_cashfree.js';

async function activate(admin, orderId, paymentId) {
  const { data, error } = await admin.rpc('activate_cashfree_order', {
    p_order_id: orderId,
    p_cf_payment_id: String(paymentId || ''),
  });
  if (error) throw error;
  return data;
}

export default async function handler(req, res) {
  if (req.method !== 'POST') return json(res, 405, { error: 'Method not allowed' });
  let admin;
  try { admin = adminClient(); } catch (e) { return json(res, 500, { error: e.message }); }
  const user = await getUser(req, admin);
  if (!user) return json(res, 401, { error: 'Please log in again.' });

  const orderId = String(req.body?.order_id || '');
  if (!/^px_[a-f0-9]{12}_\d{13}$/.test(orderId)) return json(res, 400, { error: 'Invalid order.' });

  const { data: order, error: orderError } = await admin.from('payment_orders')
    .select('order_id, user_id, status').eq('order_id', orderId).eq('user_id', user.id).maybeSingle();
  if (orderError || !order) return json(res, 404, { error: 'Payment order not found.' });
  if (order.status === 'PAID') return json(res, 200, { ok: true, already_paid: true });

  try {
    const [cashfreeOrder, payments] = await Promise.all([
      cashfreeRequest('/orders/' + encodeURIComponent(orderId)),
      cashfreeRequest('/orders/' + encodeURIComponent(orderId) + '/payments'),
    ]);
    const successful = Array.isArray(payments)
      ? payments.find(p => p.payment_status === 'SUCCESS')
      : null;
    if (cashfreeOrder.order_status !== 'PAID' || !successful) {
      return json(res, 202, { ok: false, status: cashfreeOrder.order_status || 'PENDING', message: 'Payment is not confirmed yet.' });
    }
    await activate(admin, orderId, successful.cf_payment_id);
    return json(res, 200, { ok: true, plan: 'active' });
  } catch (e) {
    console.error('Cashfree verification failed:', e.message);
    return json(res, 502, { error: 'Could not verify payment right now. Please refresh in a moment.' });
  }
}
