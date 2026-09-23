-- Ecomflex phase 8: new balance page, bank-transfer payment declarations, card top-ups (Stripe).
-- Safe to re-run. Run once in Supabase -> SQL Editor -> Create a new snippet.
--
-- Money rules unchanged: whole pence, append-only ledger, the browser never writes to it.
-- Card payments are credited ONLY by the stripe-webhook Edge Function (service role),
-- after Stripe has confirmed the payment, and never twice for the same payment.

-- ------------------------------------------------------------ balance page totals
-- Spend is charges minus refunds. Days and months are UK time.
create or replace function public.my_wallet_summary()
returns jsonb
language sql stable security definer set search_path = public as $$
  with w as (
    select pence, kind, (at at time zone 'Europe/London') as t
      from public.wallet_entries where user_id = auth.uid()
  ), now_uk as (select (now() at time zone 'Europe/London') as t)
  select jsonb_build_object(
    'balance',        coalesce((select sum(pence) from w), 0),
    'today_spend',    coalesce(-(select sum(pence) from w, now_uk n
                                  where kind in ('charge','refund') and w.t::date = n.t::date), 0),
    'month_spend',    coalesce(-(select sum(pence) from w, now_uk n
                                  where kind in ('charge','refund') and date_trunc('month', w.t) = date_trunc('month', n.t)), 0),
    'lifetime_topups',coalesce((select sum(pence) from w where kind = 'topup'), 0),
    'lifetime_spend', coalesce(-(select sum(pence) from w where kind in ('charge','refund')), 0),
    'company',        (select company from public.clients where user_id = auth.uid()),
    'card_min',       5000,
    'card_max',       500000
  )
  where auth.uid() is not null;
$$;

-- ------------------------------------------------------------ payment declarations (bank transfer)
create table if not exists public.payment_declarations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references auth.users(id) on delete cascade,
  user_email text not null,
  amount_pence bigint not null check (amount_pence > 0),
  sent_on date,
  reference text,
  status text not null default 'pending' check (status in ('pending','confirmed','rejected','cancelled')),
  decided_at timestamptz,
  decided_by text,
  decision_note text,
  wallet_entry_id uuid
);
create index if not exists payment_declarations_status_idx on public.payment_declarations (status, created_at);
create index if not exists payment_declarations_user_idx on public.payment_declarations (user_id, created_at desc);
alter table public.payment_declarations enable row level security;

drop policy if exists "declarations: own or admin read" on public.payment_declarations;
create policy "declarations: own or admin read" on public.payment_declarations
  for select to authenticated
  using ((user_id = auth.uid()) or public.is_admin());
-- no insert/update/delete policies: every change goes through the functions below

-- customer: "I have sent £X"
create or replace function public.declare_payment(p_pence bigint, p_sent_on date default null, p_reference text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_pence is null or p_pence < 100 then raise exception 'amount must be at least £1'; end if;
  if p_pence > 10000000 then raise exception 'amount too large'; end if;
  if (select count(*) from public.payment_declarations
       where user_id = auth.uid() and status = 'pending') >= 5 then
    raise exception 'TOO_MANY_PENDING';
  end if;
  insert into public.payment_declarations (user_id, user_email, amount_pence, sent_on, reference)
  values (auth.uid(), auth.jwt() ->> 'email', p_pence, p_sent_on, nullif(trim(p_reference),''))
  returning id into v_id;
  insert into public.activity (actor, action, entity, entity_id, detail)
  values (auth.jwt() ->> 'email', 'payment declared', 'payment_declarations', v_id,
          jsonb_build_object('pence', p_pence, 'reference', p_reference));
  return v_id;
end $$;

-- customer: withdraw their own pending declaration
create or replace function public.cancel_declaration(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.payment_declarations set status = 'cancelled', decided_at = now()
   where id = p_id and user_id = auth.uid() and status = 'pending';
  if not found then raise exception 'not found or already handled'; end if;
end $$;

-- admin: money has landed. p_pence = amount actually received (defaults to what was declared).
create or replace function public.confirm_declaration(p_id uuid, p_pence bigint default null, p_note text default null)
returns bigint
language plpgsql security definer set search_path = public as $$
declare d public.payment_declarations%rowtype; v_amt bigint; v_entry uuid;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select * into d from public.payment_declarations where id = p_id for update;
  if not found then raise exception 'no such declaration'; end if;
  if d.status <> 'pending' then raise exception 'already handled'; end if;
  v_amt := coalesce(p_pence, d.amount_pence);
  if v_amt <= 0 then raise exception 'amount must be positive'; end if;

  insert into public.wallet_entries (user_id, user_email, pence, kind, ref_table, ref_id, note, created_by)
  values (d.user_id, d.user_email, v_amt, 'topup', 'payment_declarations', d.id,
          'Havale' || coalesce(' — ' || d.reference, ''), auth.jwt() ->> 'email')
  returning id into v_entry;

  update public.payment_declarations
     set status = 'confirmed', decided_at = now(), decided_by = auth.jwt() ->> 'email',
         decision_note = p_note, wallet_entry_id = v_entry
   where id = p_id;  -- the declared amount stays as filed; the ledger holds what was actually received

  return public.balance_of(d.user_id);
end $$;

-- admin: money never arrived / wrong amount etc. Reason required.
create or replace function public.reject_declaration(p_id uuid, p_note text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if coalesce(trim(p_note),'') = '' then raise exception 'a rejection needs a reason'; end if;
  update public.payment_declarations
     set status = 'rejected', decided_at = now(), decided_by = auth.jwt() ->> 'email', decision_note = p_note
   where id = p_id and status = 'pending';
  if not found then raise exception 'not found or already handled'; end if;
end $$;

-- admin: waiting declarations with the customer's company name
create or replace function public.pending_declarations()
returns table(id uuid, created_at timestamptz, user_id uuid, email text, company text,
              amount_pence bigint, sent_on date, reference text, balance_pence bigint)
language sql stable security definer set search_path = public as $$
  select d.id, d.created_at, d.user_id, d.user_email,
         coalesce((select nullif(c.company,'') from public.clients c where c.user_id = d.user_id),
                  (select s.business_name from public.signup_requests s where s.user_id = d.user_id
                    order by s.created_at desc limit 1), d.user_email),
         d.amount_pence, d.sent_on, d.reference, public.balance_of(d.user_id)
    from public.payment_declarations d
   where d.status = 'pending' and public.is_admin()
   order by d.created_at;
$$;

-- ------------------------------------------------------------ card payments (Stripe)
create table if not exists public.card_payments (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references auth.users(id) on delete restrict,
  user_email text not null,
  amount_pence bigint not null check (amount_pence > 0),
  stripe_session_id text not null unique,
  stripe_payment_intent text,
  status text not null default 'open' check (status in ('open','paid')),
  paid_at timestamptz,
  wallet_entry_id uuid
);
create index if not exists card_payments_user_idx on public.card_payments (user_id, created_at desc);
alter table public.card_payments enable row level security;

drop policy if exists "card payments: own or admin read" on public.card_payments;
create policy "card payments: own or admin read" on public.card_payments
  for select to authenticated
  using ((user_id = auth.uid()) or public.is_admin());

-- Called only by the create-topup Edge Function once Stripe has made the checkout session.
create or replace function public.open_card_payment(p_user uuid, p_pence bigint, p_session text)
returns void
language plpgsql security definer set search_path = public as $$
declare v_email text;
begin
  v_email := public.customer_email(p_user);
  if v_email is null then raise exception 'no such customer'; end if;
  if p_pence < 5000 or p_pence > 500000 then raise exception 'amount out of range'; end if;
  insert into public.card_payments (user_id, user_email, amount_pence, stripe_session_id)
  values (p_user, v_email, p_pence, p_session)
  on conflict (stripe_session_id) do nothing;
end $$;

-- Called only by the stripe-webhook Edge Function after Stripe confirms payment.
-- Credits the balance once; a repeated message from Stripe changes nothing.
create or replace function public.record_card_topup(p_session text, p_pence bigint, p_payment_intent text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare cp public.card_payments%rowtype; v_entry uuid;
begin
  select * into cp from public.card_payments where stripe_session_id = p_session for update;
  if not found then raise exception 'UNKNOWN_SESSION %', p_session; end if;
  if cp.status = 'paid' then
    return jsonb_build_object('status', 'already_recorded');
  end if;
  if p_pence is distinct from cp.amount_pence then
    raise exception 'AMOUNT_MISMATCH expected % got %', cp.amount_pence, p_pence;
  end if;

  insert into public.wallet_entries (user_id, user_email, pence, kind, ref_table, ref_id, note, created_by)
  values (cp.user_id, cp.user_email, cp.amount_pence, 'topup', 'card_payments', cp.id,
          'Kart ödemesi', 'stripe')
  returning id into v_entry;

  update public.card_payments
     set status = 'paid', paid_at = now(), stripe_payment_intent = p_payment_intent, wallet_entry_id = v_entry
   where id = cp.id;

  insert into public.activity (actor, action, entity, entity_id, detail)
  values ('stripe', 'card top-up', 'card_payments', cp.id,
          jsonb_build_object('customer', cp.user_email, 'pence', cp.amount_pence));

  return jsonb_build_object('status', 'recorded', 'balance', public.balance_of(cp.user_id));
end $$;

revoke execute on function public.open_card_payment(uuid, bigint, text) from public, anon, authenticated;
revoke execute on function public.record_card_topup(text, bigint, text) from public, anon, authenticated;
grant execute on function public.open_card_payment(uuid, bigint, text) to service_role;
grant execute on function public.record_card_topup(text, bigint, text) to service_role;
grant execute on function public.customer_email(uuid) to service_role;

-- ------------------------------------------------------------ Today board: payments to confirm
create or replace function public.today_counts()
returns jsonb
language sql security definer set search_path = public as $$
  select jsonb_build_object(
    'orders_waiting',   (select count(*) from public.orders   where status = 'pending'),
    'inbound_expected', (select count(*) from public.inbounds where status = 'expected'),
    'inbound_overdue',  (select count(*) from public.inbounds where status = 'expected' and expected_on < current_date),
    'access_waiting',   (select count(*) from public.signup_requests where status = 'pending'),
    'low_stock',        (select count(*) from public.stock where low_at > 0 and qty <= low_at),
    'returns_waiting',  (select count(*) from public.requests where kind = 'return'  and status = 'pending'),
    'forward_waiting',  (select count(*) from public.requests where kind = 'forward' and status = 'pending'),
    'fba_waiting',      (select count(*) from public.requests where kind = 'fba' and status in ('pending','labelled')),
    'fba_with_customer',(select count(*) from public.requests where kind = 'fba' and status = 'boxed'),
    'payments_waiting', (select count(*) from public.payment_declarations where status = 'pending'),
    'no_funds',         (select count(*) from public.customer_directory() d
                          where d.user_id is not null
                            and public.balance_of(d.user_id)
                                <= coalesce((select floor_pence from public.client_settings c where c.user_id = d.user_id),0))
  )
  where public.is_admin();
$$;
