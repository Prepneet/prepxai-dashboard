import {
  adminClient, cashfreeRequest, getUser, json,
} from './_cashfree.js';

const PRICE = {
  first: 900,
  plus: 3900,
  pro: 6900,
};

export default async function handler(req, res) {
  if (req.method !== 'POST') return json(res, 405, { error: 'Method not allowed' });
  let admin;
  try { admin = adminClient(); } catch (e) { return json(res, 500, { error: e.message }); }

  const user = await getUser(req, admin);
  if (!user) return json(res, 401, { error: 'Please log in again.' });

  const plan = String(req.body?.plan || '').toLowerCase();
  if (!['plus', 'pro'].includes(plan)) return json(res, 400, { error: 'Choose a valid plan.' });

  const { data: profile, error: profileError } = await admin
    .from('profiles').select('id, plan, plan_expires_at, name')
    .eq('id', user.id).maybeSingle();
  if (profileError) return json(res, 500, { error: 'Could not load your account.' });

  const phone = String(req.body?.phone || user.phone || '').replace(/\D/g, '');
  if (phone.length !== 10 && phone.length !== 12) {
    return json(res, 400, { error: 'Please add a valid 10-digit mobile number to your account before paying.' });
  }

  const currentPlan = String(profile?.plan || 'free').toLowerCase();
  const firstPurchase = currentPlan === 'free';
  const amount = firstPurchase ? PRICE.first : PRICE[plan];
  const orderId = 'px_' + user.id.replace(/-/g, '').slice(0, 12) + '_' + Date.now();

  const { data: pending, error: insertError } = await admin.from('payment_orders').insert({
    order_id: orderId,
    user_id: user.id,
    plan,
    amount_paise: amount,
    status: 'CREATED',
  }).select('order_id').single();
  if (insertError || !pending) return json(res, 500, { error: 'Could not start payment. Please try again.' });

  const origin = String(req.headers.origin || '').replace(/\/$/, '');
  const forwardedHost = String(req.headers['x-forwarded-host'] || req.headers.host || '');
  const forwardedProto = String(req.headers['x-forwarded-proto'] || 'https').split(',')[0].trim();
  const baseUrl = process.env.APP_BASE_URL || origin || (forwardedHost ? forwardedProto + '://' + forwardedHost : '');
  if (!baseUrl || !/^https:\/\//i.test(baseUrl)) return json(res, 500, { error: 'APP_BASE_URL must be configured as your HTTPS dashboard URL.' });

  try {
    const result = await cashfreeRequest('/orders', {
      method: 'POST',
      headers: { 'x-idempotency-key': orderId },
      body: JSON.stringify({
        order_id: orderId,
        order_amount: amount / 100,
        order_currency: 'INR',
        customer_details: {
          customer_id: user.id,
          customer_name: String(profile?.name || user.user_metadata?.name || 'PrepX Student').slice(0, 100),
          customer_email: user.email,
          customer_phone: phone,
        },
        order_note: 'PrepX Ai ' + plan.toUpperCase() + ' plan',
        order_meta: { return_url: baseUrl + '/?payment=return&order_id=' + encodeURIComponent(orderId) },
      }),
    });

    await admin.from('payment_orders').update({ cf_order_id: result.cf_order_id || null, payment_session_id: result.payment_session_id }).eq('order_id', orderId);
    return json(res, 200, {
      order_id: orderId,
      payment_session_id: result.payment_session_id,
      amount: amount / 100,
      plan,
      mode: process.env.CASHFREE_ENV === 'production' ? 'production' : 'sandbox',
    });
  } catch (e) {
    await admin.from('payment_orders').update({ status: 'FAILED' }).eq('order_id', orderId);
    console.error('Cashfree create order failed:', e.message);
    return json(res, 502, { error: 'Cashfree could not start the payment. Please try again.' });
  }
}
