import crypto from 'node:crypto';
import { createClient } from '@supabase/supabase-js';

export const API_VERSION = '2025-01-01';
export const DAYS = 30;

export function adminClient() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error('Supabase server environment is not configured');
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}

export function cashfreeBase() {
  return process.env.CASHFREE_ENV === 'production'
    ? 'https://api.cashfree.com/pg'
    : 'https://sandbox.cashfree.com/pg';
}

export function cashfreeHeaders() {
  const id = process.env.CASHFREE_CLIENT_ID;
  const secret = process.env.CASHFREE_CLIENT_SECRET;
  if (!id || !secret) throw new Error('Cashfree server credentials are missing');
  return {
    'content-type': 'application/json',
    'x-client-id': id,
    'x-client-secret': secret,
    'x-api-version': API_VERSION,
  };
}

export async function getUser(req, admin) {
  const token = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const { data, error } = await admin.auth.getUser(token);
  return error ? null : data?.user || null;
}

export function json(res, status, body) {
  return res.status(status).setHeader('Content-Type', 'application/json').send(JSON.stringify(body));
}

export async function cashfreeRequest(path, options = {}) {
  const response = await fetch(cashfreeBase() + path, {
    ...options,
    headers: { ...cashfreeHeaders(), ...(options.headers || {}) },
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const err = new Error(payload.message || payload.type || 'Cashfree request failed');
    err.status = response.status;
    throw err;
  }
  return payload;
}

export function verifyWebhookSignature(rawBody, timestamp, signature) {
  const secret = process.env.CASHFREE_CLIENT_SECRET;
  if (!secret || !timestamp || !signature) return false;
  const expected = crypto.createHmac('sha256', secret).update(String(timestamp) + rawBody).digest('base64');
  const a = Buffer.from(expected);
  const b = Buffer.from(String(signature));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
