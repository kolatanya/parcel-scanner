-- Ecomflex phase 9: the new customer panel (panel2.html) and the admin screens behind it.
-- Safe to re-run. Run once in Supabase -> SQL Editor -> Create a new snippet.
--
--   products     extra details on each stock row (ASIN, barcode, damaged units, active/passive)
--   contacts     each customer's saved recipients
--   announcements, announcement_reads   news posted by staff, with read/unread per customer
--   price_items  the price list staff maintain
--   documents    PDFs staff share with every customer (agreements, payment methods ...)
--   invoices     PDFs staff upload for one customer
--   tickets, ticket_messages   support conversations
--   my_dashboard(), my_trends()   figures for the customer dashboard
--   create_inbound(), add_fba_label()   safer versions of two customer actions
--   is_customer()  only real customers may use the customer functions
--
-- Money rules unchanged: nothing here writes to wallet_entries.

-- ============================================================ products (stock rows)
alter table public.stock add column if not exists asin text;
alter table public.stock add column if not exists barcode text;
alter table public.stock add column if not exists damaged_qty integer not null default 0;
alter table public.stock add column if not exists active boolean not null default true;
alter table public.stock add column if not exists created_at timestamptz not null default now();
do $$ begin
  alter table public.stock add constraint stock_damaged_qty_check check (damaged_qty >= 0);
exception when duplicate_object then null; end $$;

-- a signed-in account that is a real customer (self-signup client, or approved in the old flow).
-- Supabase lets anyone create a login, so customer functions check this, not just auth.uid().
create or replace function public.is_customer()
returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    exists (select 1 from public.clients where user_id = auth.uid())
    or exists (select 1 from public.signup_requests where user_id = auth.uid() and status = 'approved'));
$$;

-- customer adds or edits one of their own products. Quantities are never touched here:
-- only staff change stock levels.
create or replace function public.save_my_product(p_sku text, p_name text default null,
  p_asin text default null, p_barcode text default null, p_low integer default null)
returns void
language plpgsql security definer set search_path = public as $$
declare v_sku text := upper(trim(coalesce(p_sku,'')));
begin
  if not public.is_customer() then raise exception 'NOT_A_CUSTOMER'; end if;
  if v_sku = '' or length(v_sku) > 64 then raise exception 'SKU_INVALID'; end if;
  insert into public.stock (user_id, user_email, sku, product_name, asin, barcode, low_at, qty)
  values (auth.uid(), auth.jwt() ->> 'email', v_sku, nullif(trim(p_name),''),
          nullif(upper(trim(p_asin)),''), nullif(trim(p_barcode),''), greatest(0, coalesce(p_low,0)), 0)
  on conflict (user_id, sku) do update
     set product_name = nullif(trim(p_name),''),
         asin = nullif(upper(trim(p_asin)),''),
         barcode = nullif(trim(p_barcode),''),
         low_at = greatest(0, coalesce(p_low, public.stock.low_at)),
         updated_at = now();
end $$;

-- customer marks a product active / passive (passive products are hidden from order forms)
create or replace function public.set_my_product_active(p_sku text, p_active boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.stock set active = coalesce(p_active, true), updated_at = now()
   where user_id = auth.uid() and sku = upper(trim(p_sku));
  if not found then raise exception 'no such product'; end if;
end $$;

-- customer uploads a product list. Fills gaps; never blanks out details already saved.
create or replace function public.import_my_products(p_rows jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb; v_sku text; n_saved int := 0; n_skipped int := 0;
begin
  if not public.is_customer() then raise exception 'NOT_A_CUSTOMER'; end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then raise exception 'no rows'; end if;
  if jsonb_array_length(p_rows) > 5000 then raise exception 'TOO_MANY_ROWS'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    v_sku := upper(trim(coalesce(r ->> 'sku','')));
    if v_sku = '' or length(v_sku) > 64 then n_skipped := n_skipped + 1; continue; end if;
    insert into public.stock (user_id, user_email, sku, product_name, asin, barcode, qty)
    values (auth.uid(), auth.jwt() ->> 'email', v_sku, nullif(trim(r ->> 'name'),''),
            nullif(upper(trim(r ->> 'asin')),''), nullif(trim(r ->> 'barcode'),''), 0)
    on conflict (user_id, sku) do update
       set product_name = coalesce(nullif(trim(r ->> 'name'),''), public.stock.product_name),
           asin = coalesce(nullif(upper(trim(r ->> 'asin')),''), public.stock.asin),
           barcode = coalesce(nullif(trim(r ->> 'barcode'),''), public.stock.barcode),
           updated_at = now();
    n_saved := n_saved + 1;
  end loop;
  return jsonb_build_object('saved', n_saved, 'skipped', n_skipped);
end $$;

-- ============================================================ saved recipients
create table if not exists public.contacts (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 200),
  phone text,
  address text,
  country text,
  email text,
  note text
);
create index if not exists contacts_user_idx on public.contacts (user_id, name);
alter table public.contacts enable row level security;
drop policy if exists "contacts: own" on public.contacts;
create policy "contacts: own" on public.contacts
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
drop policy if exists "contacts: admin read" on public.contacts;
create policy "contacts: admin read" on public.contacts
  for select to authenticated
  using (public.is_admin());

-- ============================================================ announcements
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  title text not null,
  body text not null,
  created_by text,
  active boolean not null default true
);
alter table public.announcements enable row level security;
drop policy if exists "announcements: read" on public.announcements;
create policy "announcements: read" on public.announcements
  for select to authenticated
  using (active or public.is_admin());
drop policy if exists "announcements: admin write" on public.announcements;
create policy "announcements: admin write" on public.announcements
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create table if not exists public.announcement_reads (
  user_id uuid not null references auth.users(id) on delete cascade,
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (user_id, announcement_id)
);
alter table public.announcement_reads enable row level security;
drop policy if exists "announcement reads: own" on public.announcement_reads;
create policy "announcement reads: own" on public.announcement_reads
  for select to authenticated
  using (user_id = auth.uid());

create or replace function public.my_announcements()
returns table(id uuid, created_at timestamptz, title text, body text, is_read boolean)
language sql stable security definer set search_path = public as $$
  select a.id, a.created_at, a.title, a.body,
         exists (select 1 from public.announcement_reads r where r.announcement_id = a.id and r.user_id = auth.uid())
    from public.announcements a
   where a.active and auth.uid() is not null
   order by a.created_at desc
   limit 50;
$$;

create or replace function public.mark_announcements_read()
returns void
language sql security definer set search_path = public as $$
  insert into public.announcement_reads (user_id, announcement_id)
  select auth.uid(), a.id from public.announcements a
   where a.active and auth.uid() is not null
  on conflict do nothing;
$$;

-- ============================================================ price list
create table if not exists public.price_items (
  id uuid primary key default gen_random_uuid(),
  category text,
  name text not null,
  price_pence bigint not null check (price_pence >= 0),
  unit text,
  sort integer not null default 0,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.price_items enable row level security;
drop policy if exists "prices: read" on public.price_items;
create policy "prices: read" on public.price_items
  for select to authenticated
  using (active or public.is_admin());
drop policy if exists "prices: admin write" on public.price_items;
create policy "prices: admin write" on public.price_items
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ============================================================ documents (shared with every customer)
create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  title text not null,
  description text,
  path text not null,
  file_name text,
  sort integer not null default 0,
  active boolean not null default true
);
alter table public.documents enable row level security;
drop policy if exists "documents: read" on public.documents;
create policy "documents: read" on public.documents
  for select to authenticated
  using (active or public.is_admin());
drop policy if exists "documents: admin write" on public.documents;
create policy "documents: admin write" on public.documents
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ============================================================ invoices (one customer each)
create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_id uuid not null references auth.users(id) on delete cascade,
  user_email text,
  title text not null,
  period text,
  amount_pence bigint,
  path text not null,
  file_name text,
  created_by text
);
create index if not exists invoices_user_idx on public.invoices (user_id, created_at desc);
alter table public.invoices enable row level security;
drop policy if exists "invoices: own or admin read" on public.invoices;
create policy "invoices: own or admin read" on public.invoices
  for select to authenticated
  using ((user_id = auth.uid()) or public.is_admin());
drop policy if exists "invoices: admin write" on public.invoices;
create policy "invoices: admin write" on public.invoices
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ============================================================ file storage for documents and invoices
insert into storage.buckets (id, name, public) values ('documents', 'documents', false) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('invoices', 'invoices', false) on conflict (id) do nothing;

drop policy if exists "documents: signed-in read" on storage.objects;
create policy "documents: signed-in read" on storage.objects
  for select to authenticated
  using (bucket_id = 'documents' and (public.is_admin()
         or exists (select 1 from public.documents d where d.path = storage.objects.name and d.active)));
drop policy if exists "documents: admin upload" on storage.objects;
create policy "documents: admin upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'documents' and public.is_admin());
drop policy if exists "documents: admin change" on storage.objects;
create policy "documents: admin change" on storage.objects
  for update to authenticated
  using (bucket_id = 'documents' and public.is_admin());
drop policy if exists "documents: admin delete" on storage.objects;
create policy "documents: admin delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'documents' and public.is_admin());

-- invoice files live at invoices/<customer user id>/<file>
drop policy if exists "invoices: own or admin file read" on storage.objects;
create policy "invoices: own or admin file read" on storage.objects
  for select to authenticated
  using (bucket_id = 'invoices' and (((storage.foldername(name))[1] = (auth.uid())::text) or public.is_admin()));
drop policy if exists "invoices: admin upload" on storage.objects;
create policy "invoices: admin upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'invoices' and public.is_admin());
drop policy if exists "invoices: admin change" on storage.objects;
create policy "invoices: admin change" on storage.objects
  for update to authenticated
  using (bucket_id = 'invoices' and public.is_admin());
drop policy if exists "invoices: admin delete" on storage.objects;
create policy "invoices: admin delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'invoices' and public.is_admin());

-- ============================================================ support tickets
create table if not exists public.tickets (
  id uuid primary key default gen_random_uuid(),
  no bigint generated always as identity,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  user_id uuid not null references auth.users(id) on delete cascade,
  user_email text not null,
  company text,
  subject text not null,
  category text,
  status text not null default 'open' check (status in ('open','answered','closed')),
  last_from text not null default 'customer' check (last_from in ('customer','staff'))
);
alter table public.tickets add column if not exists customer_seen boolean not null default true;
create index if not exists tickets_user_idx on public.tickets (user_id, updated_at desc);
create index if not exists tickets_status_idx on public.tickets (status, updated_at desc);
alter table public.tickets enable row level security;
drop policy if exists "tickets: own or admin read" on public.tickets;
create policy "tickets: own or admin read" on public.tickets
  for select to authenticated
  using ((user_id = auth.uid()) or public.is_admin());

create table if not exists public.ticket_messages (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  ticket_id uuid not null references public.tickets(id) on delete cascade,
  author text,
  from_staff boolean not null default false,
  body text not null
);
create index if not exists ticket_messages_idx on public.ticket_messages (ticket_id, created_at);
alter table public.ticket_messages enable row level security;
drop policy if exists "ticket messages: own or admin read" on public.ticket_messages;
create policy "ticket messages: own or admin read" on public.ticket_messages
  for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.tickets t where t.id = ticket_messages.ticket_id and t.user_id = auth.uid()));
-- no write policies: tickets change only through the functions below

create or replace function public.open_ticket(p_subject text, p_category text, p_body text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_company text;
begin
  if not public.is_customer() then raise exception 'NOT_A_CUSTOMER'; end if;
  if coalesce(trim(p_subject),'') = '' or length(p_subject) > 150 then raise exception 'SUBJECT_INVALID'; end if;
  if coalesce(trim(p_body),'') = '' or length(p_body) > 5000 then raise exception 'BODY_INVALID'; end if;
  if (select count(*) from public.tickets where user_id = auth.uid() and status = 'open') >= 10 then
    raise exception 'TOO_MANY_OPEN';
  end if;
  v_company := coalesce(
    (select nullif(company,'') from public.clients where user_id = auth.uid()),
    (select business_name from public.signup_requests where user_id = auth.uid() order by created_at desc limit 1));
  insert into public.tickets (user_id, user_email, company, subject, category)
  values (auth.uid(), auth.jwt() ->> 'email', v_company, trim(p_subject), nullif(trim(p_category),''))
  returning id into v_id;
  insert into public.ticket_messages (ticket_id, author, from_staff, body)
  values (v_id, auth.jwt() ->> 'email', false, trim(p_body));
  insert into public.activity (actor, action, entity, entity_id, detail)
  values (auth.jwt() ->> 'email', 'ticket opened', 'tickets', v_id, jsonb_build_object('subject', trim(p_subject)));
  return v_id;
end $$;

-- the customer (own ticket) or staff (any ticket) adds a message
create or replace function public.reply_ticket(p_id uuid, p_body text)
returns void
language plpgsql security definer set search_path = public as $$
declare t public.tickets%rowtype; v_staff boolean := public.is_admin();
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if coalesce(trim(p_body),'') = '' or length(p_body) > 5000 then raise exception 'BODY_INVALID'; end if;
  select * into t from public.tickets where id = p_id for update;
  if not found then raise exception 'no such ticket'; end if;
  if not v_staff and t.user_id <> auth.uid() then raise exception 'not your ticket'; end if;
  insert into public.ticket_messages (ticket_id, author, from_staff, body)
  values (p_id, auth.jwt() ->> 'email', v_staff, trim(p_body));
  update public.tickets
     set status = case when v_staff then 'answered' else 'open' end,
         last_from = case when v_staff then 'staff' else 'customer' end,
         customer_seen = not v_staff,
         updated_at = now()
   where id = p_id;
end $$;

-- the customer has read the staff reply
create or replace function public.mark_ticket_seen(p_id uuid)
returns void
language sql security definer set search_path = public as $$
  update public.tickets set customer_seen = true where id = p_id and user_id = auth.uid();
$$;

create or replace function public.close_ticket(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.tickets set status = 'closed', updated_at = now()
   where id = p_id and (user_id = auth.uid() or public.is_admin());
  if not found then raise exception 'no such ticket'; end if;
end $$;

-- ============================================================ customer actions made safer
-- payment declarations: same as phase 8, plus the customer check
create or replace function public.declare_payment(p_pence bigint, p_sent_on date default null, p_reference text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.is_customer() then raise exception 'NOT_A_CUSTOMER'; end if;
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

-- a delivery notice and its lines are saved together, or not at all
create or replace function public.create_inbound(p_courier text, p_tracking text, p_boxes integer,
  p_expected date, p_note text, p_items jsonb)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; it jsonb; n int := 0; v_biz text; v_qty int;
begin
  if not public.is_customer() then raise exception 'NOT_A_CUSTOMER'; end if;
  if coalesce(p_boxes,0) < 1 then raise exception 'BOXES_INVALID'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'NO_ITEMS'; end if;
  if jsonb_array_length(p_items) > 500 then raise exception 'TOO_MANY_ITEMS'; end if;
  v_biz := coalesce(
    (select nullif(company,'') from public.clients where user_id = auth.uid()),
    (select business_name from public.signup_requests where user_id = auth.uid() order by created_at desc limit 1));
  insert into public.inbounds (user_id, user_email, business_name, courier, tracking, boxes, expected_on, note, status)
  values (auth.uid(), auth.jwt() ->> 'email', v_biz, nullif(trim(p_courier),''), nullif(trim(p_tracking),''),
          p_boxes, p_expected, nullif(trim(p_note),''), 'expected')
  returning id into v_id;
  for it in select * from jsonb_array_elements(p_items) loop
    v_qty := case when (it ->> 'qty') ~ '^[0-9]{1,7}$' then (it ->> 'qty')::int else 0 end;
    if coalesce(trim(it ->> 'sku'),'') = '' or length(trim(it ->> 'sku')) > 64 or v_qty < 1 then continue; end if;
    insert into public.inbound_items (inbound_id, sku, product_name, qty_declared)
    values (v_id, upper(trim(it ->> 'sku')), nullif(trim(it ->> 'product_name'),''), v_qty);
    n := n + 1;
  end loop;
  if n = 0 then raise exception 'NO_ITEMS'; end if;   -- undoes the notice as well
  return v_id;
end $$;

-- customers may add lines to their own expected deliveries, but never pre-fill the counted quantity
drop policy if exists "items: customer files" on public.inbound_items;
create policy "items: customer files" on public.inbound_items
  for insert to authenticated
  with check (qty_received is null and exists (select 1 from public.inbounds i
    where i.id = inbound_items.inbound_id and i.user_id = auth.uid() and i.status = 'expected'));

-- one FBA box label at a time, merged on the server so two quick uploads cannot overwrite each other.
-- The job only becomes 'labelled' once every box has a label.
create or replace function public.add_fba_label(p_id uuid, p_label jsonb)
returns text
language plpgsql security definer set search_path = public as $$
declare r public.requests%rowtype; v_no int; v_labels jsonb; v_boxes int; v_have int; v_status text;
begin
  select * into r from public.requests where id = p_id for update;
  if not found then raise exception 'no such job'; end if;
  if r.user_id <> auth.uid() then raise exception 'not your job'; end if;
  if r.kind <> 'fba' then raise exception 'not an FBA job'; end if;
  if r.status not in ('boxed','labelled') then raise exception 'not ready for labels'; end if;
  if coalesce(p_label ->> 'no','') !~ '^[0-9]{1,4}$' or coalesce(p_label ->> 'path','') not like (auth.uid()::text || '/%') then
    raise exception 'LABEL_INVALID';
  end if;
  v_no := (p_label ->> 'no')::int;
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_labels
    from jsonb_array_elements(coalesce(r.details -> 'box_labels','[]'::jsonb)) x
   where (x ->> 'no') is distinct from v_no::text;
  v_labels := v_labels || jsonb_build_array(jsonb_build_object('no', v_no, 'path', p_label ->> 'path', 'name', p_label ->> 'name'));
  v_boxes := jsonb_array_length(coalesce(r.outcome -> 'boxes','[]'::jsonb));
  select count(distinct x ->> 'no') into v_have
    from jsonb_array_elements(v_labels) x
   where (x ->> 'no') in (select b ->> 'no' from jsonb_array_elements(coalesce(r.outcome -> 'boxes','[]'::jsonb)) b);
  v_status := case when v_boxes > 0 and v_have >= v_boxes then 'labelled' else 'boxed' end;
  update public.requests
     set details = coalesce(details,'{}'::jsonb) || jsonb_build_object('box_labels', v_labels), status = v_status
   where id = p_id;
  return v_status;
end $$;

-- ============================================================ customer dashboard
create or replace function public.my_dashboard()
returns jsonb
language sql stable security definer set search_path = public as $$
  with nowuk as (select (now() at time zone 'Europe/London') as n),
  w as (select pence, kind, (at at time zone 'Europe/London') as t
          from public.wallet_entries where user_id = auth.uid())
  select jsonb_build_object(
    'company',         (select company from public.clients where user_id = auth.uid()),
    'full_name',       (select full_name from public.clients where user_id = auth.uid()),
    'units',           (select coalesce(sum(greatest(qty,0)),0) from public.stock where user_id = auth.uid()),
    'damaged',         (select coalesce(sum(damaged_qty),0) from public.stock where user_id = auth.uid()),
    'active_products', (select count(*) from public.stock where user_id = auth.uid() and active),
    'skus_in_stock',   (select count(*) from public.stock where user_id = auth.uid() and qty > 0),
    'low_stock',       (select count(*) from public.stock where user_id = auth.uid() and active and low_at > 0 and qty <= low_at),
    'units_in_month',  (select coalesce(sum(it.qty_received),0)
                          from public.inbound_items it join public.inbounds i on i.id = it.inbound_id, nowuk
                         where i.user_id = auth.uid() and i.status = 'received'
                           and date_trunc('month', i.received_at at time zone 'Europe/London') = date_trunc('month', nowuk.n)),
    'units_out_month', (select coalesce(sum(o.quantity),0) from public.orders o, nowuk
                         where o.user_id = auth.uid() and o.status = 'answered'
                           and date_trunc('month', o.responded_at at time zone 'Europe/London') = date_trunc('month', nowuk.n)),
    'balance',         (select coalesce(sum(pence),0) from w),
    'month_net',       (select coalesce(sum(pence),0) from w, nowuk where date_trunc('month', w.t) = date_trunc('month', nowuk.n)),
    'topped_month',    (select coalesce(sum(pence),0) from w, nowuk where kind = 'topup' and date_trunc('month', w.t) = date_trunc('month', nowuk.n)),
    'spent_month',     (select coalesce(-sum(pence),0) from w, nowuk where kind in ('charge','refund') and date_trunc('month', w.t) = date_trunc('month', nowuk.n)),
    'spent_last_month',(select coalesce(-sum(pence),0) from w, nowuk where kind in ('charge','refund') and date_trunc('month', w.t) = date_trunc('month', nowuk.n) - interval '1 month'),
    'pending_declarations', (select count(*) from public.payment_declarations where user_id = auth.uid() and status = 'pending'),
    'orders_pending',  (select count(*) from public.orders where user_id = auth.uid() and status = 'pending'),
    'inbounds_expected', (select count(*) from public.inbounds where user_id = auth.uid() and status = 'expected'),
    'services_open',   (select count(*) from public.requests where user_id = auth.uid() and status in ('pending','boxed','labelled')),
    'fba_needs_labels',(select count(*) from public.requests where user_id = auth.uid() and kind = 'fba' and status = 'boxed'),
    'tickets_answered',(select count(*) from public.tickets where user_id = auth.uid() and status = 'answered' and not customer_seen),
    'unread_announcements', (select count(*) from public.announcements a where a.active
                               and not exists (select 1 from public.announcement_reads r
                                                where r.announcement_id = a.id and r.user_id = auth.uid()))
  )
  where auth.uid() is not null;
$$;

-- twelve months of stock and money movement, oldest first
create or replace function public.my_trends()
returns jsonb
language sql stable security definer set search_path = public as $$
  with m as (
    select generate_series(date_trunc('month', now() at time zone 'Europe/London') - interval '11 months',
                           date_trunc('month', now() at time zone 'Europe/London'),
                           interval '1 month') as m
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'month', to_char(m.m, 'YYYY-MM'),
    'units_in', (select coalesce(sum(it.qty_received),0)
                   from public.inbound_items it join public.inbounds i on i.id = it.inbound_id
                  where i.user_id = auth.uid() and i.status = 'received'
                    and date_trunc('month', i.received_at at time zone 'Europe/London') = m.m),
    'units_out', (select coalesce(sum(o.quantity),0) from public.orders o
                   where o.user_id = auth.uid() and o.status = 'answered'
                     and date_trunc('month', o.responded_at at time zone 'Europe/London') = m.m),
    'topups', (select coalesce(sum(pence),0) from public.wallet_entries w
                where w.user_id = auth.uid() and w.kind = 'topup'
                  and date_trunc('month', w.at at time zone 'Europe/London') = m.m),
    'spend', (select coalesce(-sum(pence),0) from public.wallet_entries w
               where w.user_id = auth.uid() and w.kind in ('charge','refund')
                 and date_trunc('month', w.at at time zone 'Europe/London') = m.m)
  ) order by m.m), '[]'::jsonb)
  from m
  where auth.uid() is not null;
$$;

-- ============================================================ Today board: support tickets waiting
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
    'no_funds',         (select count(*) from public.customer_directory() d
                          where d.user_id is not null
                            and public.balance_of(d.user_id)
                                <= coalesce((select floor_pence from public.client_settings c where c.user_id = d.user_id),0))
  )
  where public.is_admin();
$$;
