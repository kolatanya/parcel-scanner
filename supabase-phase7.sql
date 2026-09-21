-- Ecomflex phase 7: fixes found when the live database was reviewed on 21 September 2026.
-- Safe to re-run. Run once in Supabase -> SQL Editor -> Create a new snippet.
--
-- 1. Self-signup customers could not get into the panel (it only checked the old approval list).
-- 2. "New code" changed the saved code but not the login password, locking the customer out.
-- 3. Reports, stock picker, balances, top-ups and FBA jobs ignored self-signup customers.
-- 4. Undoing a dispatch refunded the money but did not put the stock back.
-- 5. Balances could be read by anyone who knew a customer's ID.
-- Also: a positive adjustment is now recorded as 'adjustment', not 'refund'; returns, forwarding,
-- FBA and inbound deliveries are now blocked in the database before the first top-up, like orders.

-- ------------------------------------------------------------ one list of customers
-- Self-signup customers (clients) plus approved customers from the old approval flow
-- who have no clients row. Admins only.
create or replace function public.customer_directory()
returns table(user_id uuid, email text, full_name text, business_name text, phone text)
language sql stable security definer set search_path = public as $$
  select x.user_id, x.email, x.full_name, x.business_name, x.phone
  from (
    select c.user_id, c.email, c.full_name, c.company as business_name, c.phone
      from public.clients c
    union all
    select s.user_id, s.email, s.full_name, s.business_name, s.phone
      from (select distinct on (lower(email)) *
              from public.signup_requests
             where status = 'approved'
             order by lower(email), created_at desc) s
     where not exists (select 1 from public.clients c where lower(c.email) = lower(s.email))
  ) x
  where public.is_admin()
  order by lower(coalesce(nullif(x.business_name,''), x.full_name));
$$;

-- Internal: a customer's email by user id. Not callable from the browser.
create or replace function public.customer_email(p_user uuid)
returns text
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select email from public.clients where user_id = p_user),
    (select email from public.signup_requests where user_id = p_user order by created_at desc limit 1),
    (select email from auth.users where id = p_user));
$$;
revoke execute on function public.customer_email(uuid) from public, anon, authenticated;

-- ------------------------------------------------------------ 1. panel sign-in
create or replace function public.request_status(p_email text)
returns text
language sql security definer set search_path = public as $$
  select coalesce(
    (select 'approved' from public.clients where lower(email) = lower(trim(p_email)) limit 1),
    (select status from public.signup_requests
      where lower(email) = lower(trim(p_email))
      order by created_at desc limit 1));
$$;

-- ------------------------------------------------------------ 2. new code also becomes the password
create or replace function public.regenerate_code(p_user uuid)
returns text
language plpgsql security definer set search_path = public as $$
declare v_new text;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if not exists (select 1 from public.clients where user_id = p_user) then
    raise exception 'no such customer';
  end if;
  v_new := public.gen_code();
  update public.access_codes set claimed_by = p_user, claimed_at = now() where code = v_new;
  update public.clients set code = v_new where user_id = p_user;
  update auth.users
     set encrypted_password = extensions.crypt(v_new, extensions.gen_salt('bf')),
         updated_at = now()
   where id = p_user;
  if not found then raise exception 'no login found for this customer'; end if;
  insert into public.activity (actor, action, entity, detail)
  values (auth.jwt() ->> 'email', 'access code regenerated', 'clients', jsonb_build_object('user', p_user));
  return v_new;
end $$;

-- ------------------------------------------------------------ 3. everything uses the one list
create or replace function public.record_topup(p_user uuid, p_pence bigint, p_note text default null)
returns bigint
language plpgsql security definer set search_path = public as $$
declare v_email text;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if p_pence is null or p_pence = 0 then raise exception 'amount must not be zero'; end if;
  if p_pence < 0 then raise exception 'a top-up must be positive; use an adjustment to take money off'; end if;
  v_email := public.customer_email(p_user);
  if v_email is null then raise exception 'no such customer'; end if;

  insert into public.wallet_entries (user_id, user_email, pence, kind, note, created_by)
  values (p_user, v_email, p_pence, 'topup', p_note, auth.jwt() ->> 'email');

  return public.balance_of(p_user);
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

  insert into public.wallet_entries (user_id, user_email, pence, kind, note, created_by)
  values (p_user, v_email, p_pence, 'adjustment', p_note, auth.jwt() ->> 'email');

  return public.balance_of(p_user);
end $$;

create or replace function public.submit_fba(p_lines jsonb, p_note text default null)
returns text
language plpgsql security definer set search_path = public as $$
declare v_ref text; v_email text; v_biz text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_lines is null or jsonb_array_length(p_lines) = 0 then raise exception 'no items'; end if;

  v_email := auth.jwt() ->> 'email';
  v_biz := coalesce(
    (select nullif(company,'') from public.clients where user_id = auth.uid()),
    (select business_name from public.signup_requests
      where lower(email) = lower(v_email) order by created_at desc limit 1));

  v_ref := public.next_ref();

  insert into public.requests (user_id, user_email, business_name, kind, status, ref, details, note)
  values (auth.uid(), v_email, v_biz, 'fba', 'pending', v_ref,
          jsonb_build_object('lines', p_lines), p_note);

  return v_ref;
end $$;

create or replace function public.all_balances()
returns table(user_id uuid, email text, business text, pence bigint, floor_pence bigint, default_pence bigint, last_topup timestamptz)
language sql stable security definer set search_path = public as $$
  select d.user_id, d.email, coalesce(nullif(d.business_name,''), d.full_name),
         public.balance_of(d.user_id),
         coalesce(cs.floor_pence,0), coalesce(cs.default_pence,0),
         (select max(w.at) from public.wallet_entries w where w.user_id = d.user_id and w.kind = 'topup')
    from public.customer_directory() d
    left join public.client_settings cs on cs.user_id = d.user_id
   where d.user_id is not null and public.is_admin()
   order by 3;
$$;

create or replace function public.month_report(p_month date default current_date)
returns table(business text, email text, dispatched bigint, units_out bigint, received bigint, units_in bigint, returns bigint, forwarded bigint, fba_jobs bigint, skus bigint, units_held bigint)
language sql security definer set search_path = public as $$
  with b as (select date_trunc('month', p_month::timestamptz) as s,
                    date_trunc('month', p_month::timestamptz) + interval '1 month' as e),
  people as (
    select coalesce(nullif(d.business_name,''), d.full_name) as business, lower(d.email) as email, d.user_id
      from public.customer_directory() d
     where d.user_id is not null
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
  where public.is_admin()
  order by 1;
$$;

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
    'no_funds',         (select count(*) from public.customer_directory() d
                          where d.user_id is not null
                            and public.balance_of(d.user_id)
                                <= coalesce((select floor_pence from public.client_settings c where c.user_id = d.user_id),0))
  )
  where public.is_admin();
$$;

-- ------------------------------------------------------------ 4. undo puts the stock back
create or replace function public.undo_dispatch(p_id uuid, p_note text default null)
returns bigint
language plpgsql security definer set search_path = public as $$
declare o public.orders%rowtype;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select * into o from public.orders where id = p_id for update;
  if not found then raise exception 'no such order'; end if;
  if o.status <> 'answered' then raise exception 'this order has not been dispatched'; end if;

  if coalesce(o.charged_pence,0) > 0 then
    insert into public.wallet_entries (user_id, user_email, pence, kind, ref_table, ref_id, note, created_by)
    values (o.user_id, o.user_email, o.charged_pence, 'refund', 'orders', o.id,
            coalesce(p_note,'dispatch undone'), auth.jwt() ->> 'email');
  end if;

  -- the dispatch trigger took these units off; give them back
  if o.sku is not null then
    insert into public.stock (user_id, user_email, sku, product_name, qty)
    values (o.user_id, o.user_email, o.sku, o.product_name, o.quantity)
    on conflict (user_id, sku) do update
       set qty = public.stock.qty + o.quantity, updated_at = now();
  end if;

  update public.orders set status='pending', charged_pence=null, tracking=null,
         responded_at=null, responded_by=null where id = p_id;

  return public.balance_of(o.user_id);
end $$;

-- ------------------------------------------------------------ 5. internal functions not callable from the browser
revoke execute on function public.balance_of(uuid) from public, anon, authenticated;
revoke execute on function public.next_ref() from public, anon, authenticated;

-- ------------------------------------------------------------ first top-up required for all new work
drop trigger if exists requests_check_funds on public.requests;
create trigger requests_check_funds before insert on public.requests
  for each row execute function public.check_funds_before_order();

drop trigger if exists inbounds_check_funds on public.inbounds;
create trigger inbounds_check_funds before insert on public.inbounds
  for each row execute function public.check_funds_before_order();
