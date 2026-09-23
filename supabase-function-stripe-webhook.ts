// Supabase Edge Function: stripe-webhook
// Paste into Supabase -> Edge Functions -> stripe-webhook (index.ts). "Verify JWT" must be OFF:
// Stripe cannot log in, so instead every message is checked against Stripe's signature.
//
// When Stripe confirms a card payment, this adds the money to the customer's balance.
// The database refuses to credit the same payment twice, so Stripe repeating a message is harmless.
//
// Needs one secret (Supabase -> Edge Functions -> Secrets): STRIPE_WEBHOOK_SECRET (starts whsec_)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase. No key is written in this file.

const WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const TOLERANCE_SECONDS = 300;

function hex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// Stripe-Signature: t=<unix time>,v1=<hex hmac>[,v1=...]
async function signedByStripe(body: string, header: string, secret: string): Promise<boolean> {
  if (!secret || !header) return false;
  let t = '';
  const sigs: string[] = [];
  for (const part of header.split(',')) {
    const i = part.indexOf('=');
    const k = part.slice(0, i).trim(), v = part.slice(i + 1).trim();
    if (k === 't') t = v;
    if (k === 'v1') sigs.push(v);
  }
  if (!t || !sigs.length) return false;
  if (Math.abs(Date.now() / 1000 - Number(t)) > TOLERANCE_SECONDS) return false;
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = hex(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${t}.${body}`)));
  return sigs.some((s) => sameText(s, mac));
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return new Response('method not allowed', { status: 405 });
  const body = await req.text();
  if (!(await signedByStripe(body, req.headers.get('stripe-signature') ?? '', WEBHOOK_SECRET))) {
    return new Response('bad signature', { status: 400 });
  }

  const event = JSON.parse(body);
  const paidEvents = ['checkout.session.completed', 'checkout.session.async_payment_succeeded'];
  if (paidEvents.includes(event?.type)) {
    const s = event.data?.object ?? {};
    if (s.payment_status === 'paid' && s.currency === 'gbp') {
      const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/record_card_topup`, {
        method: 'POST',
        headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_session: s.id, p_pence: s.amount_total, p_payment_intent: s.payment_intent ?? null }),
      });
      if (!r.ok) {
        // Stripe shows this as failed and retries for up to 3 days
        console.error('could not credit', s.id, await r.text());
        return new Response('not recorded', { status: 500 });
      }
    }
  }
  return new Response(JSON.stringify({ received: true }), { status: 200, headers: { 'Content-Type': 'application/json' } });
});
