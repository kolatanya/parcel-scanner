-- Ecomflex phase 10: services paid from the balance, customer statements, customer chat.
-- Run once in Supabase -> SQL Editor -> a NEW snippet -> paste all of this -> Run. Safe to run again.
--
-- What this adds
--   price_items.orderable                  lines customers may order themselves (storage stays staff-only)
--   the Ecomflex price list                added only where a line with the same name and unit is missing
--   service_orders + service_order_lines   one order = one or more price-list lines
--   buy_services(items, note)              customer: order services, paid from the balance straight away
--   cancel_service_order(id, reason)       customer (own, still waiting) or staff (waiting or done): cancel + full refund
--   resolve_service_order(id, note)        staff: mark a waiting order done
--   staff_add_charge(user, lines, note, date)  staff: add service charges to an account, like the old spreadsheets
--   customer_statement(user)               the account statement with service lines and running balance
--   customer_profile(user)                 staff: one customer's details and totals
--   chat_messages + send_chat / chat_mark_delivered / chat_mark_read / chat_threads
--   today_counts()                         + service_orders_waiting, chats_unread
--   dispatch_order(), adjust_balance()     unchanged, except they now take the same per-customer lock
--
-- Money rules kept: whole pence, the ledger is append-only, browsers never write to it, and a price a
-- customer pays always comes from the database, never from the page.

-- ============================================================ price list: what customers may order
-- Off unless staff tick "Can order". On the first run only, lines already typed in that match the
-- Ecomflex price list below (storage excluded, free lines excluded) are switched on.
do $$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'price_items' and column_name = 'orderable') then
    alter table public.price_items add column orderable boolean not null default false;
    update public.price_items p set orderable = true
     where p.price_pence > 0
       and lower(p.name) in ('koli hazırlık','fnsku etiketleme','poly bag','parcel forwarding - hazır koliyi taşıyıcıya teslim etme',
         'return - iade adresi temini','ürünün incelenmesi - teslim alınması','ürünün amazon''a iadesi','sipariş hazırlık',
         'karton kutu - parcel box (small parcel)','karton kutu - parcel box (big parcel)',
         'sipariş gönderimi - max 2 kg royal mail 48 saat','sipariş gönderimi - max 2 kg royal mail 24 saat',
         'sipariş gönderimi - max 25 kg fedex 24 saat','ürünün müşteriden iade alınması - max 25 kg',
         'ürünün müşteriden iade alınması - max 2 kg');
  end if;
end $$;

insert into public.price_items (category, name, unit, price_pence, sort, orderable)
select v.category, v.name, v.unit, v.price_pence, v.sort, v.orderable
  from (values
    ('FBA Hazırlık',   'Koli hazırlık',                                        'adet',     1500, 101, true),
    ('FBA Hazırlık',   'FNSKU etiketleme',                                     'adet',       40, 102, true),
    ('FBA Hazırlık',   'Poly bag',                                             'adet',      100, 103, true),
    ('FBA Hazırlık',   'Parcel forwarding - hazır koliyi taşıyıcıya teslim etme', 'adet',   1000, 104, true),
    ('İade Yönetimi',  'Return - iade adresi temini',                          'yıllık',  20000, 201, true),
    ('İade Yönetimi',  'Return - iade adresi temini',                          'aylık',    2000, 202, true),
    ('İade Yönetimi',  'Ürünün incelenmesi - teslim alınması',                 'adet',      300, 203, true),
    ('İade Yönetimi',  'Ürünün Amazon''a iadesi',                              'adet',      500, 204, true),
    ('İade Yönetimi',  'Sipariş hazırlık',                                     'adet',      200, 205, true),
    ('İade Yönetimi',  'Karton kutu - Parcel Box (small parcel)',              'adet',      200, 206, true),
    ('İade Yönetimi',  'Karton kutu - Parcel Box (big parcel)',                'adet',      300, 207, true),
    ('İade Yönetimi',  'Sipariş gönderimi - max 2 kg Royal Mail 48 saat',      'adet',      420, 208, true),
    ('İade Yönetimi',  'Sipariş gönderimi - max 2 kg Royal Mail 24 saat',      'adet',      620, 209, true),
    ('İade Yönetimi',  'Sipariş gönderimi - max 25 kg FedEx 24 saat',          'adet',     1280, 210, true),
    ('İade Yönetimi',  'Ürünün müşteriden iade alınması - max 25 kg',          'adet',     1280, 211, true),
    ('İade Yönetimi',  'Ürünün müşteriden iade alınması - max 2 kg',           'adet',      500, 212, true),
    ('Stoklama',       'Palet stoklama',                                       'palet/ay', 4500, 301, false),
    ('Stoklama',       'Koli stoklama',                                        'koli/ay',   700, 302, false)
  ) as v(category, name, unit, price_pence, sort, orderable)
 where not exists (select 1 from public.price_items p
                    where lower(p.name) = lower(v.name) and lower(coalesce(p.unit,'')) = lower(v.unit));

-- ============================================================ internal: is this user id a customer?
create or replace function public.customer_exists(p_user uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select p_user is not null and (
    exists (select 1 from public.clients where user_id = p_user)
    or exists (select 1 from public.signup_requests where user_id = p_user and status = 'approved'));
$$;
revoke execute on function public.customer_exists(uuid) from public, anon, authenticated;

-- ============================================================ service orders
create table if not exists public.service_orders (
  id uuid primary key default gen_random_uuid(),
  no bigint generated by default as identity unique,
  user_id uuid not null references auth.users(id) on delete restrict,
  user_email text not null,
  company text,
  source text not null default 'customer' check (source in ('customer','staff')),
  status text not null default 'pending' check (status in ('pending','done','cancelled')),
  total_pence bigint not null check (total_pence > 0),
  note text,
  service_date date not null default current_date,
  created_at timestamptz not null default now(),
  created_by text,
  resolved_at timestamptz,
  resolved_by text,
  staff_note text
);
create index if not exists service_orders_user_idx  on public.service_orders (user_id, created_at desc);
create index if not exists service_orders_queue_idx on public.service_orders (status, created_at);

create table if not exists public.service_order_lines (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.service_orders(id) on delete cascade,
  price_item_id uuid references public.price_items(id) on delete set null,
  name text not null,
  unit text,
  qty integer not null check (qty between 1 and 100000),
  unit_pence bigint not null check (unit_pence >= 0),
  line_pence bigint not null check (line_pence >= 0),
  sort integer not null default 0
);
create index if not exists service_order_lines_order_idx on public.service_order_lines (order_id);

-- read only: every change goes through the functions below
alter table public.service_orders enable row level security;
alter table public.service_order_lines enable row level security;
drop policy if exists "service orders: own or admin read" on public.service_orders;
create policy "service orders: own or admin read" on public.service_orders
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists "service lines: own or admin read" on public.service_order_lines;
create policy "service lines: own or admin read" on public.service_order_lines
  for select to authenticated
  using (exists (select 1 from public.service_orders o
                  where o.id = service_order_lines.order_id and (o.user_id = auth.uid() or public.is_admin())));

-- the company name shown on orders and statements
create or replace function public.company_of(p_user uuid)
returns text
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select nullif(company,'') from public.clients where user_id = p_user),
    (select business_name from public.signup_requests where user_id = p_user order by created_at desc limit 1));
$$;
revoke execute on function public.company_of(uuid) from public, anon, authenticated;

-- customer orders services from the price list; paid from the balance at once.
-- p_items: [{"id": "<price_items.id>", "qty": 3, "price": 40}, ...]  The price charged always comes from the
-- database; "price" is what the customer saw, and the order is refused (PRICE_CHANGED) if it no longer matches.
create or replace function public.buy_services(p_items jsonb, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_email text; it jsonb; v_item public.price_items%rowtype;
  v_qty int; v_total bigint := 0; v_id uuid; v_no bigint; v_bal bigint; v_seen uuid[] := '{}';
  v_lines jsonb := '[]'::jsonb; v_sort int := 0; v_item_id uuid;
begin
  if not public.is_customer() then raise exception 'NOT_A_CUSTOMER'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'NO_ITEMS'; end if;
  if jsonb_array_length(p_items) > 50 then raise exception 'TOO_MANY_ITEMS'; end if;
  if length(coalesce(p_note,'')) > 1000 then raise exception 'NOTE_TOO_LONG'; end if;

  -- one money movement at a time per customer, so two quick orders cannot both spend the same pounds
  perform pg_advisory_xact_lock(hashtext('wallet:' || v_uid::text));

  for it in select * from jsonb_array_elements(p_items) loop
    if coalesce(it ->> 'id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'ITEM_INVALID'; end if;
    if coalesce(it ->> 'qty','') !~ '^[0-9]{1,5}$' then raise exception 'QTY_INVALID'; end if;
    v_qty := (it ->> 'qty')::int;
    if v_qty < 1 or v_qty > 10000 then raise exception 'QTY_INVALID'; end if;
    v_item_id := (it ->> 'id')::uuid;
    if v_item_id = any(v_seen) then raise exception 'DUPLICATE_ITEM'; end if;
    v_seen := v_seen || v_item_id;
    select * into v_item from public.price_items where id = v_item_id and active and orderable and price_pence > 0;
    if not found then raise exception 'ITEM_UNAVAILABLE'; end if;
    -- the customer agreed to the price on their screen; if staff changed it since, stop and show the new one
    if it ? 'price' and (it ->> 'price') is distinct from v_item.price_pence::text then raise exception 'PRICE_CHANGED'; end if;
    v_total := v_total + v_item.price_pence * v_qty;
    v_sort := v_sort + 1;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object('id', v_item.id, 'name', v_item.name, 'unit', v_item.unit,
                 'qty', v_qty, 'unit_pence', v_item.price_pence, 'sort', v_sort));
  end loop;
  if v_total <= 0 then raise exception 'NOTHING_TO_PAY'; end if;

  v_bal := public.balance_of(v_uid);
  if v_bal < v_total then raise exception 'INSUFFICIENT_FUNDS balance % needed %', v_bal, v_total; end if;

  v_email := public.customer_email(v_uid);
  insert into public.service_orders (user_id, user_email, company, source, status, total_pence, note, created_by)
  values (v_uid, v_email, public.company_of(v_uid), 'customer', 'pending', v_total, nullif(trim(p_note),''), v_email)
  returning id, no into v_id, v_no;

  insert into public.service_order_lines (order_id, price_item_id, name, unit, qty, unit_pence, line_pence, sort)
  select v_id, (l ->> 'id')::uuid, l ->> 'name', l ->> 'unit', (l ->> 'qty')::int, (l ->> 'unit_pence')::bigint,
         (l ->> 'unit_pence')::bigint * (l ->> 'qty')::int, (l ->> 'sort')::int
    from jsonb_array_elements(v_lines) l;

  insert into public.wallet_entries (user_id, user_email, pence, kind, ref_table, ref_id, note, created_by)
  values (v_uid, v_email, -v_total, 'charge', 'service_orders', v_id, 'Hizmet siparişi #' || v_no, v_email);

  insert into public.activity (actor, action, entity, entity_id, detail)
  values (v_email, 'services ordered', 'service_orders', v_id, jsonb_build_object('no', v_no, 'pence', v_total));

  return jsonb_build_object('id', v_id, 'no', v_no, 'total', v_total, 'balance', public.balance_of(v_uid));
end $$;

-- staff mark a waiting order done; the note is shown to the customer
create or replace function public.resolve_service_order(p_id uuid, p_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare o public.service_orders%rowtype;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select * into o from public.service_orders where id = p_id for update;
  if not found then raise exception 'no such order'; end if;
  if o.status <> 'pending' then raise exception 'ONLY_WAITING'; end if;
  update public.service_orders
     set status = 'done', resolved_at = now(), resolved_by = auth.jwt() ->> 'email', staff_note = left(nullif(trim(p_note),''), 1000)
   where id = p_id;
  insert into public.activity (actor, action, entity, entity_id, detail)
  values (auth.jwt() ->> 'email', 'service order done', 'service_orders', p_id, jsonb_build_object('no', o.no));
end $$;

-- cancel with a full refund. Customers: their own orders while still waiting.
-- Staff: waiting or done orders (a reason is required; the customer sees it).
create or replace function public.cancel_service_order(p_id uuid, p_reason text default null)
returns bigint
language plpgsql security definer set search_path = public as $$
declare o public.service_orders%rowtype; v_staff boolean := public.is_admin(); v_who text := auth.jwt() ->> 'email';
begin
  select * into o from public.service_orders where id = p_id for update;
  if not found then raise exception 'no such order'; end if;
  if not v_staff then
    if o.user_id is distinct from auth.uid() then raise exception 'not your order'; end if;
    if o.status <> 'pending' then raise exception 'ONLY_WAITING'; end if;
  else
    if o.status = 'cancelled' then raise exception 'ALREADY_CANCELLED'; end if;
    if coalesce(trim(p_reason),'') = '' then raise exception 'REASON_REQUIRED'; end if;
  end if;
  perform pg_advisory_xact_lock(hashtext('wallet:' || o.user_id::text));
  update public.service_orders
     set status = 'cancelled', resolved_at = now(), resolved_by = v_who,
         staff_note = case when v_staff then left(nullif(trim(p_reason),''), 1000) else null end
   where id = p_id;
  insert into public.wallet_entries (user_id, user_email, pence, kind, ref_table, ref_id, note, created_by)
  values (o.user_id, o.user_email, o.total_pence, 'refund', 'service_orders', o.id,
          'İade: hizmet siparişi #' || o.no, coalesce(v_who, 'system'));
  insert into public.activity (actor, action, entity, entity_id, detail)
  values (v_who, 'service order cancelled', 'service_orders', p_id, jsonb_build_object('no', o.no, 'pence', o.total_pence));
  return public.balance_of(o.user_id);
end $$;

-- staff add service charges to an account (what the per-customer spreadsheets were for).
-- p_lines: [{"id": "<price item, optional>", "name": "...", "unit": "...", "qty": 2, "unit_pence": 500}, ...]
-- Staff may change the price on a line. Unlike a customer order, this may take the balance below zero.
create or replace function public.staff_add_charge(p_user uuid, p_lines jsonb, p_note text default null, p_date date default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_email text; it jsonb; v_item public.price_items%rowtype; v_name text; v_unit text; v_qty int; v_unit_p bigint;
  v_total bigint := 0; v_id uuid; v_no bigint; v_lines jsonb := '[]'::jsonb; v_sort int := 0; v_date date := coalesce(p_date, current_date);
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if not public.customer_exists(p_user) then raise exception 'no such customer'; end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then raise exception 'NO_ITEMS'; end if;
  if jsonb_array_length(p_lines) > 50 then raise exception 'TOO_MANY_ITEMS'; end if;
  if v_date < current_date - 3650 or v_date > current_date + 31 then raise exception 'DATE_INVALID'; end if;
  if length(coalesce(p_note,'')) > 1000 then raise exception 'NOTE_TOO_LONG'; end if;

  for it in select * from jsonb_array_elements(p_lines) loop
    v_item := null;
    if coalesce(it ->> 'id','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      select * into v_item from public.price_items where id = (it ->> 'id')::uuid;
    end if;
    v_name := coalesce(nullif(trim(it ->> 'name'),''), v_item.name);
    v_unit := coalesce(nullif(trim(it ->> 'unit'),''), v_item.unit);
    if v_name is null or length(v_name) > 200 then raise exception 'NAME_INVALID'; end if;
    if coalesce(it ->> 'qty','') !~ '^[0-9]{1,6}$' then raise exception 'QTY_INVALID'; end if;
    v_qty := (it ->> 'qty')::int;
    if v_qty < 1 or v_qty > 100000 then raise exception 'QTY_INVALID'; end if;
    if (it ->> 'unit_pence') is not null then
      if (it ->> 'unit_pence') !~ '^[0-9]{1,9}$' then raise exception 'PRICE_INVALID'; end if;
      v_unit_p := (it ->> 'unit_pence')::bigint;
    elsif v_item.id is not null then v_unit_p := v_item.price_pence;
    else raise exception 'PRICE_INVALID'; end if;
    v_total := v_total + v_unit_p * v_qty;
    v_sort := v_sort + 1;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object('id', v_item.id, 'name', v_name, 'unit', v_unit,
                 'qty', v_qty, 'unit_pence', v_unit_p, 'sort', v_sort));
  end loop;
  if v_total <= 0 then raise exception 'NOTHING_TO_PAY'; end if;

  perform pg_advisory_xact_lock(hashtext('wallet:' || p_user::text));
  v_email := public.customer_email(p_user);
  insert into public.service_orders (user_id, user_email, company, source, status, total_pence, note, service_date,
                                     created_by, resolved_at, resolved_by)
  values (p_user, v_email, public.company_of(p_user), 'staff', 'done', v_total, nullif(trim(p_note),''), v_date,
          auth.jwt() ->> 'email', now(), auth.jwt() ->> 'email')
  returning id, no into v_id, v_no;

  insert into public.service_order_lines (order_id, price_item_id, name, unit, qty, unit_pence, line_pence, sort)
  select v_id, nullif(l ->> 'id','')::uuid, l ->> 'name', l ->> 'unit', (l ->> 'qty')::int, (l ->> 'unit_pence')::bigint,
         (l ->> 'unit_pence')::bigint * (l ->> 'qty')::int, (l ->> 'sort')::int
    from jsonb_array_elements(v_lines) l;

  insert into public.wallet_entries (user_id, user_email, pence, kind, ref_table, ref_id, note, created_by)
  values (p_user, v_email, -v_total, 'charge', 'service_orders', v_id,
          'Hizmet bedeli #' || v_no || coalesce(' · ' || nullif(trim(p_note),''), ''), auth.jwt() ->> 'email');

  insert into public.activity (actor, action, entity, entity_id, detail)
  values (auth.jwt() ->> 'email', 'charge added', 'service_orders', v_id, jsonb_build_object('no', v_no, 'pence', v_total));

  return jsonb_build_object('id', v_id, 'no', v_no, 'total', v_total, 'balance', public.balance_of(p_user));
end $$;

-- ============================================================ statement
-- Every ledger entry, oldest first, with the balance after it and what it was for:
-- service lines for service orders, the parcel for dispatched orders.
create or replace function public.customer_statement(p_user uuid default null)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := coalesce(p_user, auth.uid());
begin
  if v_uid is null then raise exception 'not signed in'; end if;
  if v_uid is distinct from auth.uid() and not public.is_admin() then raise exception 'not allowed'; end if;
  return coalesce((
    select jsonb_agg(to_jsonb(x) order by x.at, x.id)
      from (
        select w.id, w.at, w.kind, w.pence, w.note, w.created_by, w.ref_table,
               sum(w.pence) over (order by w.at, w.id) as balance_after,
               case
                 when w.ref_table = 'service_orders' then (
                   select jsonb_build_object('no', o.no, 'source', o.source, 'status', o.status,
                            'service_date', o.service_date, 'note', o.note, 'staff_note', o.staff_note,
                            'lines', (select coalesce(jsonb_agg(jsonb_build_object('name', l.name, 'unit', l.unit, 'qty', l.qty,
                                              'unit_pence', l.unit_pence, 'line_pence', l.line_pence) order by l.sort), '[]'::jsonb)
                                        from public.service_order_lines l where l.order_id = o.id))
                     from public.service_orders o where o.id = w.ref_id)
                 when w.ref_table = 'orders' then (
                   select jsonb_build_object('product', d.product_name, 'qty', d.quantity, 'recipient', d.recipient_name,
                            'courier', d.courier, 'service', d.service, 'tracking', d.tracking, 'order_ref', d.order_ref)
                     from public.orders d where d.id = w.ref_id)
               end as detail
          from public.wallet_entries w
         where w.user_id = v_uid
      ) x), '[]'::jsonb);
end $$;

-- staff: one customer's details and money totals
create or replace function public.customer_profile(p_user uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c public.clients%rowtype; s public.signup_requests%rowtype;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if not public.customer_exists(p_user) then raise exception 'no such customer'; end if;
  select * into c from public.clients where user_id = p_user;
  select * into s from public.signup_requests where user_id = p_user order by created_at desc limit 1;
  return jsonb_build_object(
    'user_id', p_user,
    'email', public.customer_email(p_user),
    'company', coalesce(nullif(c.company,''), s.business_name),
    'full_name', coalesce(c.full_name, s.full_name),
    'phone', coalesce(c.phone, s.phone),
    'address', coalesce(c.company_address, s.business_address),
    'unit', c.unit_number,
    'code', c.code,
    'notes', c.notes,
    'kind', case when c.user_id is not null then 'signup' else 'legacy' end,
    'since', coalesce(c.created_at, s.created_at),
    'balance', public.balance_of(p_user),
    'topped', (select coalesce(sum(pence),0) from public.wallet_entries where user_id = p_user and kind = 'topup'),
    'spent', (select coalesce(-sum(pence),0) from public.wallet_entries where user_id = p_user and kind in ('charge','refund')),
    'month_spent', (select coalesce(-sum(pence),0) from public.wallet_entries
                     where user_id = p_user and kind in ('charge','refund')
                       and at >= (date_trunc('month', now() at time zone 'Europe/London') at time zone 'Europe/London')),
    'orders_open', (select count(*) from public.service_orders where user_id = p_user and status = 'pending'),
    'unread', (select count(*) from public.chat_messages where user_id = p_user and not from_staff and read_at is null));
end $$;

-- ============================================================ chat, one conversation per customer
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,  -- the customer the conversation belongs to
  from_staff boolean not null,
  author text,
  body text not null check (length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  delivered_at timestamptz,   -- two grey ticks: the other side's panel has received it
  read_at timestamptz         -- two blue ticks: the other side has opened the conversation
);
create index if not exists chat_messages_user_idx on public.chat_messages (user_id, created_at desc);
create index if not exists chat_messages_open_idx on public.chat_messages (from_staff) where read_at is null;
alter table public.chat_messages enable row level security;
drop policy if exists "chat: own or admin read" on public.chat_messages;
create policy "chat: own or admin read" on public.chat_messages
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- send a message. Staff pass the customer's user id; customers write in their own conversation.
create or replace function public.send_chat(p_body text, p_user uuid default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_body text := trim(coalesce(p_body,'')); v_uid uuid; v_staff boolean := false; r public.chat_messages%rowtype;
begin
  if v_body = '' then raise exception 'EMPTY'; end if;
  if length(v_body) > 4000 then raise exception 'TOO_LONG'; end if;
  if p_user is not null then
    if not public.is_admin() then raise exception 'admins only'; end if;
    if not public.customer_exists(p_user) then raise exception 'no such customer'; end if;
    v_uid := p_user; v_staff := true;
  else
    if not public.is_customer() then raise exception 'NOT_A_CUSTOMER'; end if;
    v_uid := auth.uid();
    if (select count(*) from public.chat_messages
         where user_id = v_uid and not from_staff and created_at > now() - interval '1 minute') >= 20 then
      raise exception 'SLOW_DOWN';
    end if;
  end if;
  insert into public.chat_messages (user_id, from_staff, author, body)
  values (v_uid, v_staff, auth.jwt() ->> 'email', v_body)
  returning * into r;
  return to_jsonb(r);
end $$;

-- the caller's panel has received the other side's messages (two grey ticks)
create or replace function public.chat_mark_delivered()
returns integer
language plpgsql security definer set search_path = public as $$
declare n integer := 0;
begin
  if public.is_admin() then
    update public.chat_messages set delivered_at = now() where not from_staff and delivered_at is null;
    get diagnostics n = row_count;
  elsif auth.uid() is not null then
    update public.chat_messages set delivered_at = now()
     where user_id = auth.uid() and from_staff and delivered_at is null;
    get diagnostics n = row_count;
  end if;
  return n;
end $$;

-- the caller has opened the conversation (two blue ticks). Staff pass the customer's user id.
create or replace function public.chat_mark_read(p_user uuid default null)
returns integer
language plpgsql security definer set search_path = public as $$
declare n integer := 0;
begin
  if p_user is not null then
    if not public.is_admin() then raise exception 'admins only'; end if;
    update public.chat_messages set read_at = now(), delivered_at = coalesce(delivered_at, now())
     where user_id = p_user and not from_staff and read_at is null;
  elsif auth.uid() is not null then
    update public.chat_messages set read_at = now(), delivered_at = coalesce(delivered_at, now())
     where user_id = auth.uid() and from_staff and read_at is null;
  end if;
  get diagnostics n = row_count;
  return n;
end $$;

-- staff: every conversation, newest first, with unread counts
create or replace function public.chat_threads()
returns table(user_id uuid, email text, company text, full_name text, last_body text, last_at timestamptz,
              last_from_staff boolean, last_delivered boolean, last_read boolean, unread bigint)
language sql stable security definer set search_path = public as $$
  select m.user_id, public.customer_email(m.user_id), public.company_of(m.user_id),
         coalesce((select full_name from public.clients c where c.user_id = m.user_id),
                  (select full_name from public.signup_requests s where s.user_id = m.user_id order by created_at desc limit 1)),
         m.body, m.created_at, m.from_staff, m.delivered_at is not null, m.read_at is not null,
         (select count(*) from public.chat_messages u where u.user_id = m.user_id and not u.from_staff and u.read_at is null)
    from (select distinct on (c.user_id) c.* from public.chat_messages c order by c.user_id, c.created_at desc) m
   where public.is_admin()
   order by m.created_at desc;
$$;

-- ============================================================ one lock for every debit
-- Dispatching and adjustments take the same per-customer lock as service orders, so a dispatch and a
-- purchase at the same moment cannot both spend the same pounds. (Same functions as before, plus the lock.)
create or replace function public.dispatch_order(p_id uuid, p_pence bigint, p_courier text default null, p_service text default null,
  p_eta text default null, p_tracking text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare o public.orders%rowtype; v_bal bigint;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select * into o from public.orders where id = p_id for update;
  if not found then raise exception 'no such order'; end if;
  if o.status = 'answered' then raise exception 'already dispatched'; end if;
  if p_pence is null or p_pence < 0 then raise exception 'price must be zero or more'; end if;
  perform pg_advisory_xact_lock(hashtext('wallet:' || o.user_id::text));

  v_bal := public.balance_of(o.user_id);
  if p_pence > 0 and v_bal < p_pence then
    raise exception 'INSUFFICIENT_FUNDS balance % needed %', v_bal, p_pence;
  end if;

  if p_pence > 0 then
    insert into public.wallet_entries (user_id, user_email, pence, kind, ref_table, ref_id, note, created_by)
    values (o.user_id, o.user_email, -p_pence, 'charge', 'orders', o.id,
            coalesce(p_courier,'') || case when p_tracking is not null then ' ' || p_tracking else '' end,
            auth.jwt() ->> 'email');
  end if;

  update public.orders
     set status='answered', courier=p_courier, service=p_service, eta=p_eta,
         tracking=p_tracking, charged_pence=p_pence,
         responded_at=now(), responded_by=auth.jwt() ->> 'email'
   where id = p_id;

  return jsonb_build_object('balance', public.balance_of(o.user_id), 'charged', p_pence);
end $$;

create or replace function public.adjust_balance(p_user uuid, p_pence bigint, p_note text)
returns bigint
language plpgsql security definer set search_path = public as $$
declare v_email text;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if p_pence is null or p_pence = 0 then raise exception 'amount must not be zero'; end if;
  if coalesce(trim(p_note),'') = '' then raise exception 'an adjustment needs a reason'; end if;
  v_email := public.customer_email(p_user);
  if v_email is null then raise exception 'no such customer'; end if;
  perform pg_advisory_xact_lock(hashtext('wallet:' || p_user::text));

  insert into public.wallet_entries (user_id, user_email, pence, kind, note, created_by)
  values (p_user, v_email, p_pence, 'adjustment', p_note, auth.jwt() ->> 'email');

  return public.balance_of(p_user);
end $$;

-- ============================================================ Today board: service orders and unread chat
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
    'tickets_waiting',  (select count(*) from public.tickets where status = 'open'),
    'service_orders_waiting', (select count(*) from public.service_orders where status = 'pending'),
    'chats_unread',     (select count(*) from public.chat_messages where not from_staff and read_at is null),
    'no_funds',         (select count(*) from public.customer_directory() d
                          where d.user_id is not null
                            and public.balance_of(d.user_id)
                                <= coalesce((select floor_pence from public.client_settings c where c.user_id = d.user_id),0))
  )
  where public.is_admin();
$$;
