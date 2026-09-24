-- Ecomflex phase 11: business overview for the admin console (read-only figures).
-- Run once in Supabase -> SQL Editor -> a NEW snippet -> paste all of this -> Run. Safe to run again.
-- Changes no data. Adds three functions only staff can use:
--   biz_period(from, to)        internal: every figure for one stretch of time
--   business_stats(from, to, prev_from, prev_to)   the chosen period, a comparison period, today's money position,
--                               top customers and top services
--   business_trends(months)     the same figures month by month (UK months), oldest first
--
-- What the figures mean
--   revenue          what customers were charged (service orders, shipping, other charges) minus refunds.
--                    It is not profit: courier and other costs are not recorded in the system.
--   money received   top-ups: bank transfers staff confirmed, card payments and top-ups staff recorded.
--                    Top-ups whose note starts with "TEST" are left out everywhere.
--   adjustments      shown on their own; they are corrections, not revenue.
-- Months and days follow UK time (Europe/London).

drop function if exists public.business_stats(date, date);

-- figures are summed by date, so these keep them quick as the history grows
create index if not exists wallet_entries_at_idx on public.wallet_entries (at);
create index if not exists orders_responded_idx on public.orders (responded_at) where status = 'answered';

-- ============================================================ one stretch of time
create or replace function public.biz_period(p_from timestamptz, p_to timestamptz)
returns jsonb
language sql stable security definer set search_path = public as $$
  with w as (
    select * from public.wallet_entries where at >= p_from and at < p_to
  ), rev as (
    select coalesce(-sum(pence) filter (where kind in ('charge','refund')), 0) as total,
           coalesce(-sum(pence) filter (where kind in ('charge','refund') and ref_table = 'service_orders'), 0) as services,
           coalesce(-sum(pence) filter (where kind in ('charge','refund') and ref_table = 'orders'), 0) as shipping,
           coalesce(-sum(pence) filter (where kind in ('charge','refund') and coalesce(ref_table,'') not in ('service_orders','orders')), 0) as other,
           coalesce(sum(pence) filter (where kind = 'adjustment'), 0) as adjustments,
           coalesce(sum(pence) filter (where kind = 'topup' and coalesce(note,'') !~* '^\s*test'), 0) as cash_in,
           coalesce(sum(pence) filter (where kind = 'topup' and ref_table = 'payment_declarations' and coalesce(note,'') !~* '^\s*test'), 0) as cash_bank,
           coalesce(sum(pence) filter (where kind = 'topup' and ref_table = 'card_payments'), 0) as cash_card,
           coalesce(sum(pence) filter (where kind = 'topup' and coalesce(note,'') ~* '^\s*test'), 0) as test_topups,
           count(distinct user_id) filter (where kind = 'charge') as active_customers
      from w
  )
  select jsonb_build_object(
    'revenue', r.total, 'revenue_services', r.services, 'revenue_shipping', r.shipping, 'revenue_other', r.other,
    'adjustments', r.adjustments, 'cash_in', r.cash_in, 'cash_bank', r.cash_bank, 'cash_card', r.cash_card,
    'cash_manual', r.cash_in - r.cash_bank - r.cash_card, 'test_topups', r.test_topups,
    'active_customers', r.active_customers,
    'orders_dispatched', (select count(*) from public.orders o where o.status = 'answered' and o.responded_at >= p_from and o.responded_at < p_to),
    'units_out',         (select coalesce(sum(o.quantity),0) from public.orders o where o.status = 'answered' and o.responded_at >= p_from and o.responded_at < p_to),
    'deliveries_received', (select count(*) from public.inbounds i where i.status = 'received' and i.received_at >= p_from and i.received_at < p_to),
    'units_in',          (select coalesce(sum(it.qty_received),0) from public.inbound_items it join public.inbounds i on i.id = it.inbound_id
                           where i.status = 'received' and i.received_at >= p_from and i.received_at < p_to),
    'services_ordered',  (select count(*) from public.service_orders s where s.source = 'customer' and s.status <> 'cancelled' and s.created_at >= p_from and s.created_at < p_to),
    'services_done',     (select count(*) from public.service_orders s where s.source = 'customer' and s.status = 'done' and s.resolved_at >= p_from and s.resolved_at < p_to),
    'staff_charges',     (select count(*) from public.service_orders s where s.source = 'staff' and s.status <> 'cancelled' and s.created_at >= p_from and s.created_at < p_to),
    'returns_done',      (select count(*) from public.requests q where q.kind = 'return'  and q.status = 'done' and q.responded_at >= p_from and q.responded_at < p_to),
    'forwards_done',     (select count(*) from public.requests q where q.kind = 'forward' and q.status = 'done' and q.responded_at >= p_from and q.responded_at < p_to),
    'fba_done',          (select count(*) from public.requests q where q.kind = 'fba'     and q.status = 'done' and q.responded_at >= p_from and q.responded_at < p_to),
    'tickets_opened',    (select count(*) from public.tickets k where k.created_at >= p_from and k.created_at < p_to),
    'new_customers',     (select count(*) from public.clients c where c.created_at >= p_from and c.created_at < p_to)
                       + (select count(*) from public.signup_requests s where s.status = 'approved' and s.decided_at >= p_from and s.decided_at < p_to
                            and not exists (select 1 from public.clients c where lower(c.email) = lower(s.email)))
  )
  from rev r;
$$;
revoke execute on function public.biz_period(timestamptz, timestamptz) from public, anon, authenticated;

-- ============================================================ the chosen period, compared
-- The comparison period is the one given (e.g. the same days last month), or else the same number of days just before.
create or replace function public.business_stats(p_from date, p_to date, p_prev_from date default null, p_prev_to date default null)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare f timestamptz; t timestamptz; pf timestamptz; pt timestamptz; n integer; v_pf date; v_pt date;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 3700 then raise exception 'PERIOD_INVALID'; end if;
  n := p_to - p_from + 1;
  if p_prev_from is not null and p_prev_to is not null then
    if p_prev_to < p_prev_from or p_prev_to - p_prev_from > 3700 then raise exception 'PERIOD_INVALID'; end if;
    v_pf := p_prev_from; v_pt := p_prev_to;
  else
    v_pf := p_from - n; v_pt := p_from - 1;
  end if;
  f  := p_from::timestamp at time zone 'Europe/London';
  t  := (p_to + 1)::timestamp at time zone 'Europe/London';
  pf := v_pf::timestamp at time zone 'Europe/London';
  pt := (v_pt + 1)::timestamp at time zone 'Europe/London';
  return jsonb_build_object(
    'from', p_from, 'to', p_to, 'days', n, 'previous_from', v_pf, 'previous_to', v_pt,
    'current', public.biz_period(f, t),
    'previous', public.biz_period(pf, pt),
    'position', (
      with b as (select user_id, sum(pence) as bal from public.wallet_entries group by user_id)
      select jsonb_build_object(
        'held',  coalesce((select sum(bal) from b where bal > 0), 0),
        'owed',  coalesce((select -sum(bal) from b where bal < 0), 0),
        'customers_owing', (select count(*) from b where bal < 0),
        'customers', (select count(*) from public.customer_directory()),
        'units_stored', (select coalesce(sum(qty),0) from public.stock where qty > 0),
        'skus_stored', (select count(*) from public.stock where qty > 0),
        'customers_storing', (select count(distinct user_id) from public.stock where qty > 0))),
    'top_customers', coalesce((
      select jsonb_agg(x order by x.revenue desc) from (
        select w.user_id, coalesce(public.company_of(w.user_id), max(w.user_email)) as company, max(w.user_email) as email,
               -sum(w.pence) as revenue,
               (select count(*) from public.orders o where o.user_id = w.user_id and o.status = 'answered'
                  and o.responded_at >= f and o.responded_at < t) as orders
          from public.wallet_entries w
         where w.kind in ('charge','refund') and w.at >= f and w.at < t
         group by w.user_id
        having -sum(w.pence) <> 0
         order by -sum(w.pence) desc
         limit 10) x), '[]'::jsonb),
    'top_services', coalesce((
      select jsonb_agg(y order by y.revenue desc) from (
        select l.name, sum(l.qty) as qty, sum(l.line_pence) as revenue, count(distinct s.id) as orders
          from public.service_order_lines l join public.service_orders s on s.id = l.order_id
         where s.status <> 'cancelled' and s.created_at >= f and s.created_at < t
         group by l.name
         order by sum(l.line_pence) desc
         limit 10) y), '[]'::jsonb));
end $$;

-- ============================================================ month by month
create or replace function public.business_trends(p_months integer default 12)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_this date := date_trunc('month', now() at time zone 'Europe/London')::date; n integer := least(greatest(coalesce(p_months,12),1),36);
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  return (
    select jsonb_agg(jsonb_build_object('month', to_char(m, 'YYYY-MM'))
                     || public.biz_period(m::timestamp at time zone 'Europe/London', (m + interval '1 month')::timestamp at time zone 'Europe/London')
                     order by m)
      from generate_series(v_this - make_interval(months => n - 1), v_this, interval '1 month') as g(m));
end $$;
