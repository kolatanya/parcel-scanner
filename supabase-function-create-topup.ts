// Supabase Edge Function: create-topup
// Paste into Supabase -> Edge Functions -> create-topup (index.ts). "Verify JWT" stays ON.
//
// Starts a Stripe card payment for the signed-in customer and returns the client secret
// for Stripe's embedded checkout. No money is credited here: that happens only in
// stripe-webhook, after Stripe confirms the payment.
//
// Needs one secret (Supabase -> Edge Functions -> Secrets): STRIPE_SECRET_KEY
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
// No key is written in this file.

const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const ALLOWED_ORIGINS = ['https://kolatanya.github.io', 'https://panel.ecomflex.co.uk'];
const MIN_PENCE = 5000;    // £50
const MAX_PENCE = 500000;  // £5,000

function cors(req: Request): Record<string, string> {
  const origin = req.headers.get('origin') ?? '';
  return {
    'Access-Control-Allow-Origin': ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0],
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  };
}

function reply(req: Request, status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { ...cors(req), 'Content-Type': 'application/json' },
  });
}

async function rpc(name: string, args: unknown): Promise<{ ok: boolean; data: unknown }> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(args),
  });
  const text = await r.text();
  let data: unknown = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { ok: r.ok, data };
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors(req) });
  if (req.method !== 'POST') return reply(req, 405, { error: 'METHOD' });
  if (!STRIPE_SECRET_KEY) return reply(req, 500, { error: 'NOT_CONFIGURED' });

  // who is asking: the customer's own login, checked by Supabase
  const auth = req.headers.get('authorization') ?? '';
  const u = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: ANON_KEY, Authorization: auth } });
  if (!u.ok) return reply(req, 401, { error: 'NOT_SIGNED_IN' });
  const user = await u.json();
  if (!user?.id) return reply(req, 401, { error: 'NOT_SIGNED_IN' });

  let pence = 0;
  try { pence = Math.round(Number((await req.json())?.pence)); } catch { /* handled below */ }
  if (!Number.isInteger(pence) || pence < MIN_PENCE) return reply(req, 400, { error: 'AMOUNT_TOO_SMALL' });
  if (pence > MAX_PENCE) return reply(req, 400, { error: 'AMOUNT_TOO_LARGE' });

  const who = await rpc('customer_email', { p_user: user.id });
  if (!who.ok || !who.data) return reply(req, 403, { error: 'NOT_A_CUSTOMER' });
  const email = String(who.data);

  const form = new URLSearchParams({
    'mode': 'payment',
    'ui_mode': 'embedded',
    'redirect_on_completion': 'never',
    'payment_method_types[0]': 'card',
    'line_items[0][quantity]': '1',
    'line_items[0][price_data][currency]': 'gbp',
    'line_items[0][price_data][unit_amount]': String(pence),
    'line_items[0][price_data][product_data][name]': 'ecomFLEX bakiye yükleme',
    'customer_email': email,
    'client_reference_id': user.id,
    'metadata[user_id]': user.id,
    'payment_intent_data[metadata][user_id]': user.id,
    'payment_intent_data[description]': `ecomFLEX top-up ${email}`,
    'locale': 'tr',
    'expires_at': String(Math.floor(Date.now() / 1000) + 3600),
  });
  const s = await fetch('https://api.stripe.com/v1/checkout/sessions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      'Stripe-Version': '2024-06-20',
    },
    body: form,
  });
  const session = await s.json();
  if (!s.ok || !session?.id || !session?.client_secret) {
    console.error('stripe error', JSON.stringify(session?.error ?? session));
    return reply(req, 502, { error: 'STRIPE_ERROR' });
  }

  // record that this payment was started, so the webhook can match it later
  const opened = await rpc('open_card_payment', { p_user: user.id, p_pence: pence, p_session: session.id });
  if (!opened.ok) {
    console.error('db error', JSON.stringify(opened.data));
    return reply(req, 500, { error: 'DB_ERROR' });
  }

  return reply(req, 200, { clientSecret: session.client_secret });
});
