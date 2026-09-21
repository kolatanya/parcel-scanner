-- Ecomflex database schema: a snapshot of the LIVE Supabase database, taken 21 September 2026.
--
-- The original migration files (supabase-setup.sql ... supabase-phase6.sql) were lost.
-- This file was rebuilt from the live database and replaces them as the record of what exists.
--
-- DO NOT run this on the live database. It is for rebuilding from an EMPTY Supabase project
-- (disaster recovery or a test copy), and as the reference for how everything works.
-- New changes go in new, separate migration files (supabase-phase7.sql and onwards).
--
-- Contains no data, no keys and no passwords.

set check_function_bodies = off;

create extension if not exists pgcrypto;

-- ============================================================ tables
create sequence if not exists public.activity_id_seq;

create table if not exists public.admins (
  email text not null,
  constraint admins_pkey PRIMARY KEY (email)
);

create table if not exists public.app_settings (
  key text not null,
  value text,
  constraint app_settings_pkey PRIMARY KEY (key)
);

create table if not exists public.ref_counter (
  day date not null,
  n integer not null default 0,
  constraint ref_counter_pkey PRIMARY KEY (day)
);

create table if not exists public.access_codes (
  code text not null,
  created_at timestamp with time zone not null default now(),
  claimed_by uuid,
  claimed_at timestamp with time zone,
  constraint access_codes_pkey PRIMARY KEY (code),
  constraint access_codes_claimed_by_fkey FOREIGN KEY (claimed_by) REFERENCES auth.users(id) ON DELETE CASCADE
);

create table if not exists public.activity (
  id bigint not null default nextval('activity_id_seq'::regclass),
  at timestamp with time zone not null default now(),
  actor text,
  action text not null,
  entity text not null,
  entity_id uuid,
  detail jsonb,
  constraint activity_pkey PRIMARY KEY (id)
);

create table if not exists public.signup_requests (
  id uuid not null default gen_random_uuid(),
  created_at timestamp with time zone not null default now(),
  full_name text not null,
  phone text not null,
  email text not null,
  business_name text not null,
  business_address text not null,
  status text not null default 'pending'::text,
  decided_at timestamp with time zone,
  decided_by text,
  user_id uuid,
  constraint signup_requests_pkey PRIMARY KEY (id)
);

create table if not exists public.clients (
  user_id uuid not null,
  created_at timestamp with time zone not null default now(),
  code text,
  email text not null,
  full_name text not null,
  company text not null,
  company_address text,
  phone text,
  work_methods text[] default '{}'::text[],
  services text[] default '{}'::text[],
  details text,
  heard_from text[] default '{}'::text[],
  unit_number text,
  form_sent boolean not null default false,
  notes text,
  constraint clients_pkey PRIMARY KEY (user_id),
  constraint clients_code_fkey FOREIGN KEY (code) REFERENCES access_codes(code),
  constraint clients_code_key UNIQUE (code),
  constraint clients_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

create table if not exists public.client_settings (
  user_id uuid not null,
  user_email text,
  floor_pence bigint not null default 0,
  default_pence bigint not null default 0,
  updated_at timestamp with time zone not null default now(),
  constraint client_settings_pkey PRIMARY KEY (user_id),
  constraint client_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

create table if not exists public.inbounds (
  id uuid not null default gen_random_uuid(),
  created_at timestamp with time zone not null default now(),
  user_id uuid not null default auth.uid(),
  user_email text not null,
  business_name text,
  courier text,
  tracking text,
  boxes integer,
  expected_on date,
  note text,
  status text not null default 'expected'::text,
  received_at timestamp with time zone,
  received_by text,
  receive_note text,
  constraint inbounds_pkey PRIMARY KEY (id),
  constraint inbounds_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

create table if not exists public.inbound_items (
  id uuid not null default gen_random_uuid(),
  inbound_id uuid not null,
  sku text not null,
  product_name text,
  qty_declared integer not null,
  qty_received integer,
  constraint inbound_items_pkey PRIMARY KEY (id),
  constraint inbound_items_inbound_id_fkey FOREIGN KEY (inbound_id) REFERENCES inbounds(id) ON DELETE CASCADE,
  constraint inbound_items_qty_declared_check CHECK ((qty_declared > 0))
);

create table if not exists public.orders (
  id uuid not null default gen_random_uuid(),
  created_at timestamp with time zone not null default now(),
  user_id uuid not null default auth.uid(),
  user_email text not null,
  business_name text,
  form_key text not null default 'temp1'::text,
  recipient_name text not null,
  recipient_address text not null,
  recipient_country text not null,
  recipient_phone text not null,
  product_name text not null,
  quantity integer not null,
  note text,
  status text not null default 'pending'::text,
  courier text,
  service text,
  eta text,
  tracking text,
  responded_at timestamp with time zone,
  responded_by text,
  sku text,
  marketplace text,
  order_ref text,
  charged_pence bigint,
  constraint orders_pkey PRIMARY KEY (id),
  constraint orders_quantity_check CHECK ((quantity > 0)),
  constraint orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

create table if not exists public.requests (
  id uuid not null default gen_random_uuid(),
  created_at timestamp with time zone not null default now(),
  user_id uuid not null default auth.uid(),
  user_email text not null,
  business_name text,
  kind text not null,
  status text not null default 'pending'::text,
  details jsonb not null default '{}'::jsonb,
  note text,
  outcome jsonb not null default '{}'::jsonb,
  reply_note text,
  responded_at timestamp with time zone,
  responded_by text,
  ref text,
  constraint requests_pkey PRIMARY KEY (id),
  constraint requests_kind_check CHECK ((kind = ANY (ARRAY['return'::text, 'forward'::text, 'fba'::text]))),
  constraint requests_ref_unique UNIQUE (ref),
  constraint requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

create table if not exists public.stock (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  user_email text not null,
  sku text not null,
  product_name text,
  qty integer not null default 0,
  location text,
  low_at integer not null default 0,
  updated_at timestamp with time zone not null default now(),
  constraint stock_pkey PRIMARY KEY (id),
  constraint stock_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  constraint stock_user_id_sku_key UNIQUE (user_id, sku)
);

create table if not exists public.wallet_entries (
  id uuid not null default gen_random_uuid(),
  at timestamp with time zone not null default now(),
  user_id uuid not null,
  user_email text not null,
  pence bigint not null,
  kind text not null,
  ref_table text,
  ref_id uuid,
  note text,
  created_by text not null default COALESCE((auth.jwt() ->> 'email'::text), 'system'::text),
  constraint wallet_entries_pkey PRIMARY KEY (id),
  constraint wallet_entries_kind_check CHECK ((kind = ANY (ARRAY['topup'::text, 'charge'::text, 'refund'::text, 'adjustment'::text]))),
  constraint wallet_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE RESTRICT
);

alter sequence public.activity_id_seq owned by public.activity.id;

-- ============================================================ indexes
create index if not exists activity_at_idx ON public.activity USING btree (at DESC);
create index if not exists clients_code_idx ON public.clients USING btree (code);
create index if not exists inbound_items_idx ON public.inbound_items USING btree (inbound_id);
create index if not exists inbounds_status_idx ON public.inbounds USING btree (status, expected_on);
create index if not exists inbounds_user_idx ON public.inbounds USING btree (user_id, created_at DESC);
create index if not exists orders_ref_idx ON public.orders USING btree (order_ref) WHERE (order_ref IS NOT NULL);
create index if not exists orders_status_idx ON public.orders USING btree (status, created_at DESC);
create index if not exists orders_user_idx ON public.orders USING btree (user_id, created_at DESC);
create index if not exists requests_queue_idx ON public.requests USING btree (kind, status, created_at);
create index if not exists requests_user_idx ON public.requests USING btree (user_id, created_at DESC);
create index if not exists signup_requests_email_idx ON public.signup_requests USING btree (lower(email));
create index if not exists stock_user_idx ON public.stock USING btree (user_id);
create index if not exists wallet_ref_idx ON public.wallet_entries USING btree (ref_table, ref_id);
create index if not exists wallet_user_idx ON public.wallet_entries USING btree (user_id, at DESC);

-- ============================================================ row-level security
alter table public.admins enable row level security;
alter table public.app_settings enable row level security;
alter table public.ref_counter enable row level security;
alter table public.access_codes enable row level security;
alter table public.activity enable row level security;
alter table public.signup_requests enable row level security;
alter table public.clients enable row level security;
alter table public.client_settings enable row level security;
alter table public.inbounds enable row level security;
alter table public.inbound_items enable row level security;
alter table public.orders enable row level security;
alter table public.requests enable row level security;
alter table public.stock enable row level security;
alter table public.wallet_entries enable row level security;
-- public.admins has RLS on and NO policies on purpose: only reachable through is_admin().

-- ============================================================ functions
-- add_admin(p_email text)
CREATE OR REPLACE FUNCTION public.add_admin(p_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if p_email is null or position('@' in p_email) = 0 then raise exception 'not an email address'; end if;
  insert into public.admins (email) values (lower(trim(p_email))) on conflict do nothing;
  insert into public.activity (actor, action, entity, detail)
  values (auth.jwt() ->> 'email', 'admin added', 'admins', jsonb_build_object('email', lower(trim(p_email))));
end $function$;

-- adjust_balance(p_user uuid, p_pence bigint, p_note text)
CREATE OR REPLACE FUNCTION public.adjust_balance(p_user uuid, p_pence bigint, p_note text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_email text;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if p_pence is null or p_pence = 0 then raise exception 'amount must not be zero'; end if;
  if coalesce(trim(p_note),'') = '' then raise exception 'an adjustment needs a reason'; end if;

  select email into v_email from public.signup_requests
   where user_id = p_user order by created_at desc limit 1;

  insert into public.wallet_entries (user_id, user_email, pence, kind, note, created_by)
  values (p_user, coalesce(v_email,'unknown'), p_pence,
          case when p_pence > 0 then 'refund' else 'adjustment' end,
          p_note, auth.jwt() ->> 'email');

  return public.balance_of(p_user);
end $function$;

-- all_balances()
CREATE OR REPLACE FUNCTION public.all_balances()
 RETURNS TABLE(user_id uuid, email text, business text, pence bigint, floor_pence bigint, default_pence bigint, last_topup timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.user_id,
         p.email,
         coalesce(p.business_name, p.full_name),
         public.balance_of(p.user_id),
         coalesce(cs.floor_pence,0),
         coalesce(cs.default_pence,0),
         (select max(at) from public.wallet_entries w
           where w.user_id = p.user_id and w.kind = 'topup')
  from (select distinct on (lower(email)) user_id, email, business_name, full_name
          from public.signup_requests
         where status = 'approved' and user_id is not null
         order by lower(email), created_at desc) p
  cross join lateral (select * from public.client_settings c where c.user_id = p.user_id) cs
  where public.is_admin()
  union all
  select p.user_id, p.email, coalesce(p.business_name,p.full_name),
         public.balance_of(p.user_id), 0, 0,
         (select max(at) from public.wallet_entries w where w.user_id = p.user_id and w.kind='topup')
  from (select distinct on (lower(email)) user_id, email, business_name, full_name
          from public.signup_requests
         where status = 'approved' and user_id is not null
         order by lower(email), created_at desc) p
  where public.is_admin()
    and not exists (select 1 from public.client_settings c where c.user_id = p.user_id)
  order by 3;
$function$;

-- balance_of(p_user uuid)
CREATE OR REPLACE FUNCTION public.balance_of(p_user uuid)
 RETURNS bigint
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(sum(pence),0) from public.wallet_entries where user_id = p_user;
$function$;

-- cancel_request(p_id uuid)
CREATE OR REPLACE FUNCTION public.cancel_request(p_id uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update public.requests set status = 'cancelled'
   where id = p_id and user_id = auth.uid() and status = 'pending';
$function$;

-- check_funds_before_order()
CREATE OR REPLACE FUNCTION public.check_funds_before_order()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from public.wallet_entries
                  where user_id = new.user_id and kind = 'topup' and pence > 0) then
    raise exception 'NOT_UNLOCKED'
      using hint = 'This client has not made their first top-up yet.';
  end if;
  return new;
end $function$;

-- close_fba(p_id uuid, p_outcome jsonb, p_lines jsonb, p_note text)
CREATE OR REPLACE FUNCTION public.close_fba(p_id uuid, p_outcome jsonb, p_lines jsonb DEFAULT '[]'::jsonb, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.requests%rowtype; l record;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select * into r from public.requests where id = p_id for update;
  if not found then raise exception 'no such request'; end if;
  if r.status = 'done' then raise exception 'already closed'; end if;

  for l in select (e->>'sku') as sku, (e->>'qty')::integer as qty
           from jsonb_array_elements(coalesce(p_lines,'[]'::jsonb)) e
  loop
    if l.sku is not null and coalesce(l.qty,0) > 0 then
      insert into public.stock (user_id, user_email, sku, qty)
      values (r.user_id, r.user_email, l.sku, -l.qty)
      on conflict (user_id, sku) do update
         set qty = public.stock.qty - l.qty, updated_at = now();
    end if;
  end loop;

  update public.requests
     set status = 'done', outcome = coalesce(p_outcome,'{}'::jsonb), reply_note = p_note,
         responded_at = now(), responded_by = auth.jwt() ->> 'email'
   where id = p_id;
end $function$;

-- close_fba_job(p_id uuid, p_courier text, p_tracking text, p_note text)
CREATE OR REPLACE FUNCTION public.close_fba_job(p_id uuid, p_courier text DEFAULT NULL::text, p_tracking text DEFAULT NULL::text, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.requests%rowtype; b jsonb; it jsonb; taken jsonb := '[]'::jsonb; hit integer;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select * into r from public.requests where id = p_id for update;
  if not found then raise exception 'no such job'; end if;
  if r.status = 'done' then raise exception 'already closed'; end if;

  for b in select * from jsonb_array_elements(coalesce(r.outcome -> 'boxes','[]'::jsonb))
  loop
    for it in select * from jsonb_array_elements(coalesce(b -> 'items','[]'::jsonb))
    loop
      if (it ->> 'code') is not null and coalesce((it ->> 'qty')::integer,0) > 0 then
        update public.stock
           set qty = qty - (it ->> 'qty')::integer, updated_at = now()
         where user_id = r.user_id and sku = upper(trim(it ->> 'code'));
        get diagnostics hit = row_count;
        if hit > 0 then
          taken := taken || jsonb_build_object('sku', upper(trim(it ->> 'code')), 'qty', (it ->> 'qty')::integer);
        end if;
      end if;
    end loop;
  end loop;

  update public.requests
     set status = 'done',
         outcome = coalesce(outcome,'{}'::jsonb)
                   || jsonb_build_object('courier', p_courier, 'tracking', p_tracking,
                                         'stock_taken', taken, 'labels_applied', true),
         reply_note = coalesce(p_note, reply_note),
         responded_at = now(),
         responded_by = auth.jwt() ->> 'email'
   where id = p_id;

  return taken;
end $function$;

-- close_return(p_id uuid, p_outcome jsonb, p_restock integer, p_note text)
CREATE OR REPLACE FUNCTION public.close_return(p_id uuid, p_outcome jsonb, p_restock integer DEFAULT 0, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.requests%rowtype;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select * into r from public.requests where id = p_id for update;
  if not found then raise exception 'no such request'; end if;
  if r.kind <> 'return' then raise exception 'not a return'; end if;
  if r.status = 'done' then raise exception 'already closed'; end if;

  if coalesce(p_restock,0) > 0 and (r.details ->> 'sku') is not null then
    insert into public.stock (user_id, user_email, sku, product_name, qty)
    values (r.user_id, r.user_email, r.details ->> 'sku', r.details ->> 'product_name', p_restock)
    on conflict (user_id, sku) do update
       set qty = public.stock.qty + p_restock, updated_at = now();
  end if;

  update public.requests
     set status = 'done',
         outcome = coalesce(p_outcome,'{}'::jsonb) || jsonb_build_object('restocked', coalesce(p_restock,0)),
         reply_note = p_note,
         responded_at = now(),
         responded_by = auth.jwt() ->> 'email'
   where id = p_id;
end $function$;

-- dispatch_order(p_id uuid, p_pence bigint, p_courier text, p_service text, p_eta text, p_tracking text)
CREATE OR REPLACE FUNCTION public.dispatch_order(p_id uuid, p_pence bigint, p_courier text DEFAULT NULL::text, p_service text DEFAULT NULL::text, p_eta text DEFAULT NULL::text, p_tracking text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare o public.orders%rowtype; v_bal bigint;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select * into o from public.orders where id = p_id for update;
  if not found then raise exception 'no such order'; end if;
  if o.status = 'answered' then raise exception 'already dispatched'; end if;
  if p_pence is null or p_pence < 0 then raise exception 'price must be zero or more'; end if;

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
end $function$;

-- email_for_code(p_code text)
CREATE OR REPLACE FUNCTION public.email_for_code(p_code text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_email text;
begin
  select email into v_email from public.clients
   where upper(trim(code)) = upper(trim(p_code));
  if v_email is null then return null; end if;
  insert into public.activity (actor, action, entity, detail)
  values ('code-login', 'signed in with code', 'clients', jsonb_build_object('email', v_email));
  return v_email;
end $function$;

-- gen_code()
CREATE OR REPLACE FUNCTION public.gen_code()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; c text; i int;
begin
  loop
    c := '';
    for i in 1..8 loop
      c := c || substr(alphabet, 1 + floor(random()*length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.access_codes where code = c);
  end loop;
  insert into public.access_codes (code) values (c);
  return c;
end $function$;

-- is_admin()
CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from public.admins a where a.email = auth.jwt() ->> 'email')
$function$;

-- is_unlocked()
CREATE OR REPLACE FUNCTION public.is_unlocked()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from public.wallet_entries
                  where user_id = auth.uid() and kind = 'topup' and pence > 0);
$function$;

-- link_my_account()
CREATE OR REPLACE FUNCTION public.link_my_account()
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update public.signup_requests
     set user_id = auth.uid()
   where lower(email) = lower(auth.jwt() ->> 'email')
     and user_id is null;
$function$;

-- list_admins()
CREATE OR REPLACE FUNCTION public.list_admins()
 RETURNS TABLE(email text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select a.email from public.admins a where public.is_admin() order by a.email;
$function$;

-- log_activity()
CREATE OR REPLACE FUNCTION public.log_activity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare act text; det jsonb; eid uuid;
begin
  eid := coalesce(new.id, old.id);
  if tg_table_name = 'orders' then
    if tg_op = 'INSERT' then act := 'order filed';
      det := jsonb_build_object('product', new.product_name, 'qty', new.quantity, 'customer', new.user_email);
    elsif new.status = 'answered' and coalesce(old.status,'') <> 'answered' then act := 'order dispatched';
      det := jsonb_build_object('tracking', new.tracking, 'courier', new.courier, 'customer', new.user_email);
    else return new; end if;
  elsif tg_table_name = 'inbounds' then
    if tg_op = 'INSERT' then act := 'delivery expected';
      det := jsonb_build_object('boxes', new.boxes, 'customer', new.user_email);
    elsif new.status = 'received' and coalesce(old.status,'') <> 'received' then act := 'delivery received';
      det := jsonb_build_object('customer', new.user_email, 'note', new.receive_note);
    else return new; end if;
  elsif tg_table_name = 'requests' then
    if tg_op = 'INSERT' then act := new.kind || ' filed';
      det := jsonb_build_object('customer', new.user_email);
    elsif new.status <> coalesce(old.status,'') then act := new.kind || ' ' || new.status;
      det := jsonb_build_object('customer', new.user_email);
    else return new; end if;
  elsif tg_table_name = 'signup_requests' then
    if tg_op = 'UPDATE' and new.status <> coalesce(old.status,'') then act := 'access ' || new.status;
      det := jsonb_build_object('business', new.business_name, 'email', new.email);
    else return coalesce(new, old); end if;
  elsif tg_table_name = 'stock' then
    if tg_op = 'UPDATE' and new.qty <> old.qty then act := 'stock changed';
      det := jsonb_build_object('sku', new.sku, 'from', old.qty, 'to', new.qty, 'customer', new.user_email);
    else return coalesce(new, old); end if;
  else return coalesce(new, old);
  end if;

  insert into public.activity (actor, action, entity, entity_id, detail)
  values (coalesce(auth.jwt() ->> 'email', 'system'), act, tg_table_name, eid, det);
  return coalesce(new, old);
end $function$;

-- month_report(p_month date)
CREATE OR REPLACE FUNCTION public.month_report(p_month date DEFAULT CURRENT_DATE)
 RETURNS TABLE(business text, email text, dispatched bigint, units_out bigint, received bigint, units_in bigint, returns bigint, forwarded bigint, fba_jobs bigint, skus bigint, units_held bigint)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with b as (select date_trunc('month', p_month::timestamptz) as s,
                    date_trunc('month', p_month::timestamptz) + interval '1 month' as e),
  people as (
    select distinct coalesce(sr.business_name, sr.full_name) as business, lower(sr.email) as email, sr.user_id
    from public.signup_requests sr where sr.status = 'approved'
  )
  select p.business, p.email,
    (select count(*) from public.orders o, b where o.user_id=p.user_id and o.status='answered' and o.responded_at>=b.s and o.responded_at<b.e),
    (select coalesce(sum(o.quantity),0) from public.orders o, b where o.user_id=p.user_id and o.status='answered' and o.responded_at>=b.s and o.responded_at<b.e),
    (select count(*) from public.inbounds i, b where i.user_id=p.user_id and i.status='received' and i.received_at>=b.s and i.received_at<b.e),
    (select coalesce(sum(it.qty_received),0) from public.inbound_items it join public.inbounds i on i.id=it.inbound_id, b
      where i.user_id=p.user_id and i.status='received' and i.received_at>=b.s and i.received_at<b.e),
    (select count(*) from public.requests r, b where r.user_id=p.user_id and r.kind='return'  and r.status='done' and r.responded_at>=b.s and r.responded_at<b.e),
    (select count(*) from public.requests r, b where r.user_id=p.user_id and r.kind='forward' and r.status='done' and r.responded_at>=b.s and r.responded_at<b.e),
    (select count(*) from public.requests r, b where r.user_id=p.user_id and r.kind='fba'     and r.status='done' and r.responded_at>=b.s and r.responded_at<b.e),
    (select count(*) from public.stock s2 where s2.user_id=p.user_id),
    (select coalesce(sum(s2.qty),0) from public.stock s2 where s2.user_id=p.user_id)
  from people p
  where public.is_admin() and p.user_id is not null
  order by 1;
$function$;

-- my_account()
CREATE OR REPLACE FUNCTION public.my_account()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'balance',  public.balance_of(auth.uid()),
    'unlocked', public.is_unlocked(),
    'code',     (select code from public.clients where user_id = auth.uid()),
    'unit',     (select unit_number from public.clients where user_id = auth.uid()),
    'company',  (select company from public.clients where user_id = auth.uid()),
    'bank',     (select value from public.app_settings where key = 'bank_details'),
    'welcome',  (select value from public.app_settings where key = 'welcome_template')
  );
$function$;

-- my_balance()
CREATE OR REPLACE FUNCTION public.my_balance()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'pence', public.balance_of(auth.uid()),
    'floor', coalesce((select floor_pence from public.client_settings where user_id = auth.uid()),0)
  );
$function$;

-- my_month(p_month date)
CREATE OR REPLACE FUNCTION public.my_month(p_month date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with b as (select date_trunc('month', p_month::timestamptz) as s,
                    date_trunc('month', p_month::timestamptz) + interval '1 month' as e)
  select jsonb_build_object(
    'month',      to_char((select s from b), 'YYYY-MM'),
    'dispatched', (select count(*) from public.orders o, b
                    where o.user_id = auth.uid() and o.status='answered'
                      and o.responded_at >= b.s and o.responded_at < b.e),
    'units_out',  (select coalesce(sum(o.quantity),0) from public.orders o, b
                    where o.user_id = auth.uid() and o.status='answered'
                      and o.responded_at >= b.s and o.responded_at < b.e),
    'received',   (select count(*) from public.inbounds i, b
                    where i.user_id = auth.uid() and i.status='received'
                      and i.received_at >= b.s and i.received_at < b.e),
    'units_in',   (select coalesce(sum(it.qty_received),0) from public.inbound_items it
                     join public.inbounds i on i.id = it.inbound_id, b
                    where i.user_id = auth.uid() and i.status='received'
                      and i.received_at >= b.s and i.received_at < b.e),
    'returns',    (select count(*) from public.requests r, b
                    where r.user_id = auth.uid() and r.kind='return' and r.status='done'
                      and r.responded_at >= b.s and r.responded_at < b.e),
    'forwarded',  (select count(*) from public.requests r, b
                    where r.user_id = auth.uid() and r.kind='forward' and r.status='done'
                      and r.responded_at >= b.s and r.responded_at < b.e),
    'fba_jobs',   (select count(*) from public.requests r, b
                    where r.user_id = auth.uid() and r.kind='fba' and r.status='done'
                      and r.responded_at >= b.s and r.responded_at < b.e),
    'skus',       (select count(*) from public.stock s2 where s2.user_id = auth.uid()),
    'units_held', (select coalesce(sum(s2.qty),0) from public.stock s2 where s2.user_id = auth.uid())
  );
$function$;

-- next_ref()
CREATE OR REPLACE FUNCTION public.next_ref()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c integer;
begin
  insert into public.ref_counter (day, n) values (current_date, 1)
  on conflict (day) do update set n = public.ref_counter.n + 1
  returning n into c;
  return to_char(current_date, 'DDMMYYYY') || '-' || lpad(c::text, 2, '0');
end $function$;

-- onboarding()
CREATE OR REPLACE FUNCTION public.onboarding()
 RETURNS TABLE(n bigint, user_id uuid, code text, company text, full_name text, email text, phone text, unit_number text, form_sent boolean, paid boolean, balance_pence bigint, complete boolean, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select row_number() over (order by c.created_at),
         c.user_id, c.code, c.company, c.full_name, c.email, c.phone,
         c.unit_number, c.form_sent,
         exists (select 1 from public.wallet_entries w
                  where w.user_id = c.user_id and w.kind='topup' and w.pence > 0),
         public.balance_of(c.user_id),
         (c.form_sent
          and coalesce(nullif(trim(c.unit_number),''),'') <> ''
          and exists (select 1 from public.wallet_entries w
                       where w.user_id = c.user_id and w.kind='topup' and w.pence > 0)),
         c.created_at
    from public.clients c
   where public.is_admin()
   order by c.created_at;
$function$;

-- orders_dispatch_trigger()
CREATE OR REPLACE FUNCTION public.orders_dispatch_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- only on the moment an order first becomes answered, and only when it names a SKU
  if new.status = 'answered' and coalesce(old.status,'') <> 'answered' and new.sku is not null then
    insert into public.stock (user_id, user_email, sku, product_name, qty)
    values (new.user_id, new.user_email, new.sku, new.product_name, -new.quantity)
    on conflict (user_id, sku) do update
       set qty = public.stock.qty - new.quantity,
           updated_at = now();
  end if;
  return new;
end $function$;

-- receive_inbound(p_inbound uuid, p_counts jsonb, p_note text)
CREATE OR REPLACE FUNCTION public.receive_inbound(p_inbound uuid, p_counts jsonb, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r record;
  ib public.inbounds%rowtype;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select * into ib from public.inbounds where id = p_inbound for update;
  if not found then raise exception 'no such delivery'; end if;
  if ib.status = 'received' then raise exception 'already received'; end if;

  for r in select (e->>'item_id')::uuid as item_id, (e->>'qty')::integer as qty
           from jsonb_array_elements(p_counts) e
  loop
    update public.inbound_items
       set qty_received = greatest(0, coalesce(r.qty,0))
     where id = r.item_id and inbound_id = p_inbound;
  end loop;

  insert into public.stock (user_id, user_email, sku, product_name, qty)
  select ib.user_id, ib.user_email, it.sku, it.product_name, coalesce(it.qty_received,0)
    from public.inbound_items it
   where it.inbound_id = p_inbound
  on conflict (user_id, sku) do update
     set qty = public.stock.qty + excluded.qty,
         product_name = coalesce(public.stock.product_name, excluded.product_name),
         updated_at = now();

  update public.inbounds
     set status = 'received',
         received_at = now(),
         received_by = auth.jwt() ->> 'email',
         receive_note = p_note
   where id = p_inbound;
end $function$;

-- record_topup(p_user uuid, p_pence bigint, p_note text)
CREATE OR REPLACE FUNCTION public.record_topup(p_user uuid, p_pence bigint, p_note text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_email text;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if p_pence is null or p_pence = 0 then raise exception 'amount must not be zero'; end if;
  if p_pence < 0 then raise exception 'a top-up must be positive; use an adjustment to take money off'; end if;

  select email into v_email from public.signup_requests
   where user_id = p_user order by created_at desc limit 1;

  insert into public.wallet_entries (user_id, user_email, pence, kind, note, created_by)
  values (p_user, coalesce(v_email,'unknown'), p_pence, 'topup', p_note, auth.jwt() ->> 'email');

  return public.balance_of(p_user);
end $function$;

-- regenerate_code(p_user uuid)
CREATE OR REPLACE FUNCTION public.regenerate_code(p_user uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_new text;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  v_new := public.gen_code();
  update public.access_codes set claimed_by = p_user, claimed_at = now() where code = v_new;
  update public.clients set code = v_new where user_id = p_user;
  insert into public.activity (actor, action, entity, detail)
  values (auth.jwt() ->> 'email', 'access code regenerated', 'clients', jsonb_build_object('user', p_user));
  return v_new;
end $function$;

-- register_client(p_code text, p_data jsonb)
CREATE OR REPLACE FUNCTION public.register_client(p_code text, p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_email text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  v_email := auth.jwt() ->> 'email';

  if not exists (select 1 from public.access_codes where code = p_code and claimed_by is null) then
    raise exception 'that code is not available';
  end if;

  update public.access_codes set claimed_by = auth.uid(), claimed_at = now() where code = p_code;

  insert into public.clients (user_id, code, email, full_name, company, company_address,
                              phone, work_methods, services, details, heard_from)
  values (auth.uid(), p_code, v_email,
          coalesce(p_data ->> 'full_name',''), coalesce(p_data ->> 'company',''),
          p_data ->> 'company_address', p_data ->> 'phone',
          coalesce((select array_agg(value) from jsonb_array_elements_text(coalesce(p_data->'work_methods','[]'::jsonb))),'{}'),
          coalesce((select array_agg(value) from jsonb_array_elements_text(coalesce(p_data->'services','[]'::jsonb))),'{}'),
          p_data ->> 'details',
          coalesce((select array_agg(value) from jsonb_array_elements_text(coalesce(p_data->'heard_from','[]'::jsonb))),'{}'))
  on conflict (user_id) do update
     set full_name = excluded.full_name, company = excluded.company,
         company_address = excluded.company_address, phone = excluded.phone;

  insert into public.activity (actor, action, entity, detail)
  values (v_email, 'client registered', 'clients',
          jsonb_build_object('company', p_data ->> 'company', 'code', p_code));

  return jsonb_build_object('code', p_code);
end $function$;

-- remove_admin(p_email text)
CREATE OR REPLACE FUNCTION public.remove_admin(p_email text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if lower(trim(p_email)) = lower(auth.jwt() ->> 'email') then
    raise exception 'you cannot remove your own account';
  end if;
  if (select count(*) from public.admins) <= 1 then
    raise exception 'there must always be at least one admin';
  end if;
  delete from public.admins where email = lower(trim(p_email));
  insert into public.activity (actor, action, entity, detail)
  values (auth.jwt() ->> 'email', 'admin removed', 'admins', jsonb_build_object('email', lower(trim(p_email))));
end $function$;

-- request_status(p_email text)
CREATE OR REPLACE FUNCTION public.request_status(p_email text)
 RETURNS text
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select status
  from public.signup_requests
  where lower(email) = lower(trim(p_email))
  order by created_at desc
  limit 1
$function$;

-- set_client_field(p_user uuid, p_field text, p_value text)
CREATE OR REPLACE FUNCTION public.set_client_field(p_user uuid, p_field text, p_value text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if p_field = 'unit_number' then
    update public.clients set unit_number = nullif(trim(p_value),'') where user_id = p_user;
  elsif p_field = 'form_sent' then
    update public.clients set form_sent = (lower(p_value) in ('true','t','1','yes')) where user_id = p_user;
  elsif p_field = 'notes' then
    update public.clients set notes = nullif(trim(p_value),'') where user_id = p_user;
  else
    raise exception 'that field cannot be changed here';
  end if;
end $function$;

-- set_fba_boxes(p_id uuid, p_boxes jsonb, p_note text)
CREATE OR REPLACE FUNCTION public.set_fba_boxes(p_id uuid, p_boxes jsonb, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if p_boxes is null or jsonb_array_length(p_boxes) = 0 then raise exception 'no boxes'; end if;

  update public.requests
     set outcome = coalesce(outcome,'{}'::jsonb) || jsonb_build_object('boxes', p_boxes),
         status = 'boxed',
         reply_note = coalesce(p_note, reply_note),
         responded_at = now(),
         responded_by = auth.jwt() ->> 'email'
   where id = p_id and kind = 'fba';
  if not found then raise exception 'no such FBA job'; end if;
end $function$;

-- set_fba_labels(p_id uuid, p_labels jsonb)
CREATE OR REPLACE FUNCTION public.set_fba_labels(p_id uuid, p_labels jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.requests%rowtype;
begin
  select * into r from public.requests where id = p_id for update;
  if not found then raise exception 'no such job'; end if;
  if r.user_id <> auth.uid() then raise exception 'not your job'; end if;
  if r.status not in ('boxed','labelled') then raise exception 'not ready for labels'; end if;

  update public.requests
     set details = coalesce(details,'{}'::jsonb) || jsonb_build_object('box_labels', p_labels),
         status = 'labelled'
   where id = p_id;
end $function$;

-- set_low_at(p_sku text, p_low integer)
CREATE OR REPLACE FUNCTION public.set_low_at(p_sku text, p_low integer)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update public.stock set low_at = greatest(0, coalesce(p_low,0)), updated_at = now()
  where user_id = auth.uid() and sku = p_sku;
$function$;

-- submit_fba(p_lines jsonb, p_note text)
CREATE OR REPLACE FUNCTION public.submit_fba(p_lines jsonb, p_note text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_ref text; v_email text; v_biz text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_lines is null or jsonb_array_length(p_lines) = 0 then raise exception 'no items'; end if;

  v_email := auth.jwt() ->> 'email';
  select business_name into v_biz from public.signup_requests
   where lower(email) = lower(v_email) order by created_at desc limit 1;

  v_ref := public.next_ref();

  insert into public.requests (user_id, user_email, business_name, kind, status, ref, details, note)
  values (auth.uid(), v_email, v_biz, 'fba', 'pending', v_ref,
          jsonb_build_object('lines', p_lines), p_note);

  return v_ref;
end $function$;

-- today_counts()
CREATE OR REPLACE FUNCTION public.today_counts()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    'no_funds',         (select count(*) from (
                            select p.user_id from (select distinct on (lower(email)) user_id, email
                                                     from public.signup_requests
                                                    where status='approved' and user_id is not null
                                                    order by lower(email), created_at desc) p
                             where public.balance_of(p.user_id)
                                   <= coalesce((select floor_pence from public.client_settings c where c.user_id=p.user_id),0)
                          ) z)
  )
  where public.is_admin();
$function$;

-- undo_dispatch(p_id uuid, p_note text)
CREATE OR REPLACE FUNCTION public.undo_dispatch(p_id uuid, p_note text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare o public.orders%rowtype;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select * into o from public.orders where id = p_id for update;
  if not found then raise exception 'no such order'; end if;

  if coalesce(o.charged_pence,0) > 0 then
    insert into public.wallet_entries (user_id, user_email, pence, kind, ref_table, ref_id, note, created_by)
    values (o.user_id, o.user_email, o.charged_pence, 'refund', 'orders', o.id,
            coalesce(p_note,'dispatch undone'), auth.jwt() ->> 'email');
  end if;

  update public.orders set status='pending', charged_pence=null, tracking=null,
         responded_at=null, responded_by=null where id = p_id;

  return public.balance_of(o.user_id);
end $function$;

-- welcome_for(p_user uuid)
CREATE OR REPLACE FUNCTION public.welcome_for(p_user uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select replace(
           replace((select value from public.app_settings where key='welcome_template'),
                   '{UNIT}', coalesce((select unit_number from public.clients where user_id=p_user),'—')),
           '{COMPANY}', coalesce((select company from public.clients where user_id=p_user),''))
   where public.is_admin() or p_user = auth.uid();
$function$;

-- ============================================================ triggers
drop trigger if exists log_inbounds on public.inbounds;
CREATE TRIGGER log_inbounds AFTER INSERT OR UPDATE ON public.inbounds FOR EACH ROW EXECUTE FUNCTION public.log_activity();

drop trigger if exists log_orders on public.orders;
CREATE TRIGGER log_orders AFTER INSERT OR UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.log_activity();

drop trigger if exists orders_check_funds on public.orders;
CREATE TRIGGER orders_check_funds BEFORE INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION public.check_funds_before_order();

drop trigger if exists orders_dispatch on public.orders;
CREATE TRIGGER orders_dispatch AFTER UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.orders_dispatch_trigger();

drop trigger if exists log_requests on public.requests;
CREATE TRIGGER log_requests AFTER INSERT OR UPDATE ON public.requests FOR EACH ROW EXECUTE FUNCTION public.log_activity();

drop trigger if exists log_access on public.signup_requests;
CREATE TRIGGER log_access AFTER UPDATE ON public.signup_requests FOR EACH ROW EXECUTE FUNCTION public.log_activity();

drop trigger if exists log_stock on public.stock;
CREATE TRIGGER log_stock AFTER UPDATE ON public.stock FOR EACH ROW EXECUTE FUNCTION public.log_activity();

-- ============================================================ policies
drop policy if exists "activity: admins read" on public.activity;
create policy "activity: admins read" on public.activity
  for select to authenticated
  using (is_admin());

drop policy if exists "settings admin write" on public.app_settings;
create policy "settings admin write" on public.app_settings
  for all to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "settings readable" on public.app_settings;
create policy "settings readable" on public.app_settings
  for select to authenticated
  using (true);

drop policy if exists "settings: admin write" on public.client_settings;
create policy "settings: admin write" on public.client_settings
  for all to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "settings: own or admin read" on public.client_settings;
create policy "settings: own or admin read" on public.client_settings
  for select to authenticated
  using (((user_id = auth.uid()) OR is_admin()));

drop policy if exists "clients: admin write" on public.clients;
create policy "clients: admin write" on public.clients
  for all to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "clients: own or admin read" on public.clients;
create policy "clients: own or admin read" on public.clients
  for select to authenticated
  using (((user_id = auth.uid()) OR is_admin()));

drop policy if exists "items: admin update" on public.inbound_items;
create policy "items: admin update" on public.inbound_items
  for update to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "items: customer files" on public.inbound_items;
create policy "items: customer files" on public.inbound_items
  for insert to authenticated
  with check ((EXISTS ( SELECT 1
   FROM inbounds i
  WHERE ((i.id = inbound_items.inbound_id) AND (i.user_id = auth.uid()) AND (i.status = 'expected'::text)))));

drop policy if exists "items: own or admin read" on public.inbound_items;
create policy "items: own or admin read" on public.inbound_items
  for select to authenticated
  using ((is_admin() OR (EXISTS ( SELECT 1
   FROM inbounds i
  WHERE ((i.id = inbound_items.inbound_id) AND (i.user_id = auth.uid()))))));

drop policy if exists "inbound: admin update" on public.inbounds;
create policy "inbound: admin update" on public.inbounds
  for update to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "inbound: customer files" on public.inbounds;
create policy "inbound: customer files" on public.inbounds
  for insert to authenticated
  with check (((user_id = auth.uid()) AND (status = 'expected'::text)));

drop policy if exists "inbound: own or admin read" on public.inbounds;
create policy "inbound: own or admin read" on public.inbounds
  for select to authenticated
  using (((user_id = auth.uid()) OR is_admin()));

drop policy if exists "admins answer" on public.orders;
create policy "admins answer" on public.orders
  for update to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "customer files enquiry" on public.orders;
create policy "customer files enquiry" on public.orders
  for insert to authenticated
  with check (((user_id = auth.uid()) AND (status = 'pending'::text)));

drop policy if exists "read own or admin" on public.orders;
create policy "read own or admin" on public.orders
  for select to authenticated
  using (((user_id = auth.uid()) OR is_admin()));

drop policy if exists "requests: admin responds" on public.requests;
create policy "requests: admin responds" on public.requests
  for update to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "requests: customer files" on public.requests;
create policy "requests: customer files" on public.requests
  for insert to authenticated
  with check (((user_id = auth.uid()) AND (status = 'pending'::text)));

drop policy if exists "requests: own or admin read" on public.requests;
create policy "requests: own or admin read" on public.requests
  for select to authenticated
  using (((user_id = auth.uid()) OR is_admin()));

drop policy if exists "admins decide requests" on public.signup_requests;
create policy "admins decide requests" on public.signup_requests
  for update to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "admins read requests" on public.signup_requests;
create policy "admins read requests" on public.signup_requests
  for select to authenticated
  using (is_admin());

drop policy if exists "anyone may request access" on public.signup_requests;
create policy "anyone may request access" on public.signup_requests
  for insert to anon, authenticated
  with check ((status = 'pending'::text));

drop policy if exists "stock: admin write" on public.stock;
create policy "stock: admin write" on public.stock
  for all to authenticated
  using (is_admin())
  with check (is_admin());

drop policy if exists "stock: own or admin read" on public.stock;
create policy "stock: own or admin read" on public.stock
  for select to authenticated
  using (((user_id = auth.uid()) OR is_admin()));

drop policy if exists "wallet: own or admin read" on public.wallet_entries;
create policy "wallet: own or admin read" on public.wallet_entries
  for select to authenticated
  using (((user_id = auth.uid()) OR is_admin()));

drop policy if exists "labels: own folder delete" on storage.objects;
create policy "labels: own folder delete" on storage.objects
  for delete to authenticated
  using (((bucket_id = 'labels'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));

drop policy if exists "labels: own folder replace" on storage.objects;
create policy "labels: own folder replace" on storage.objects
  for update to authenticated
  using (((bucket_id = 'labels'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));

drop policy if exists "labels: own folder upload" on storage.objects;
create policy "labels: own folder upload" on storage.objects
  for insert to authenticated
  with check (((bucket_id = 'labels'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));

drop policy if exists "labels: own or admin read" on storage.objects;
create policy "labels: own or admin read" on storage.objects
  for select to authenticated
  using (((bucket_id = 'labels'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR is_admin())));

-- ============================================================ storage
insert into storage.buckets (id, name, public) values ('labels', 'labels', false) on conflict (id) do nothing;
