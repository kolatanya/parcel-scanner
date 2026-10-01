-- =====================================================================
-- Ecomflex phase 12 (1 Oct 2026)
--   1. Import the existing customer list: one call per company creates the login
--      (the 8-character code is the password), the access code and the customer row.
--      Companies with no email get a private placeholder login address; they sign in
--      with the code. Safe to run twice: a suite already imported is skipped.
--   2. Staff can edit a customer's details (company, manager, email, phone, address,
--      suite / unit, notes). Changing the email also changes the address they sign in with.
--   3. The welcome message always carries the customer's code.
-- No customer data is in this file. Safe to re-run.
-- =====================================================================

-- where a customer came from: 'signup' (filled in the sign-up form) or 'import' (the old customer list)
alter table public.clients add column if not exists source text not null default 'signup';

-- ------------------------------------------------------------ internal: placeholder login address
create or replace function public.placeholder_login(p_key text)
returns text
language sql immutable as $$
  select 'suite-' || coalesce(nullif(regexp_replace(lower(coalesce(p_key,'')), '[^a-z0-9]', '', 'g'), ''), 'x') || '@no-email.ecomflex.invalid';
$$;
revoke execute on function public.placeholder_login(text) from public, anon, authenticated;

-- ------------------------------------------------------------ internal: make a login for a customer
-- Creates the auth user the same way Supabase does for an email + password sign-up,
-- with the email already confirmed. Returns the new user's id.
create or replace function public.make_login(p_email text, p_password text, p_name text, p_company text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := gen_random_uuid(); v_col text;
begin
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values ('00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated', lower(p_email),
          extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
          jsonb_build_object('provider','email','providers',jsonb_build_array('email')),
          jsonb_build_object('full_name', p_name, 'business_name', p_company),
          now(), now());
  -- the sign-in service cannot read NULL in these columns; Supabase itself stores ''
  for v_col in
    select column_name from information_schema.columns
     where table_schema = 'auth' and table_name = 'users'
       and column_name in ('confirmation_token','recovery_token','email_change_token_new','email_change',
                           'email_change_token_current','phone_change','phone_change_token','reauthentication_token')
  loop
    execute format('update auth.users set %I = coalesce(%I, '''') where id = $1', v_col, v_col) using v_uid;
  end loop;
  insert into auth.identities (provider_id, user_id, identity_data, provider, created_at, updated_at)
  values (v_uid::text, v_uid,
          jsonb_build_object('sub', v_uid::text, 'email', lower(p_email), 'email_verified', true, 'phone_verified', false),
          'email', now(), now());
  return v_uid;
end $$;
revoke execute on function public.make_login(text, text, text, text) from public, anon, authenticated;

-- ------------------------------------------------------------ 1. import one company
-- p: {suite, company, manager, email, phone, address, notes}
-- returns {status: created | linked | exists | suite_taken, user_id, code, login, by}
create or replace function public.import_customer(p jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_suite   text := nullif(trim(p ->> 'suite'), '');
  v_company text := nullif(trim(p ->> 'company'), '');
  v_name    text := nullif(trim(p ->> 'manager'), '');
  v_email   text := lower(nullif(trim(p ->> 'email'), ''));
  v_phone   text := nullif(trim(p ->> 'phone'), '');
  v_addr    text := nullif(trim(p ->> 'address'), '');
  v_notes   text := nullif(trim(p ->> 'notes'), '');
  v_login text; v_uid uuid; v_code text; v_status text := 'created'; v_extra text;
  c public.clients%rowtype;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if v_suite is null or v_company is null then raise exception 'SUITE_AND_COMPANY_NEEDED'; end if;
  if length(v_suite) > 20 or length(v_company) > 200 or length(coalesce(v_name,'')) > 200
     or length(coalesce(v_phone,'')) > 100 or length(coalesce(v_addr,'')) > 1000 or length(coalesce(v_notes,'')) > 2000 then
    raise exception 'TOO_LONG';
  end if;
  if v_email is not null and v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]{2,}$' then
    v_extra := 'Email in the list was not valid: ' || v_email; v_email := null;
  end if;

  -- one import at a time per suite, so a double click cannot make two accounts
  perform pg_advisory_xact_lock(hashtext('import:' || lower(v_suite)));

  -- suite already in the system
  select * into c from public.clients where lower(trim(unit_number)) = lower(v_suite) limit 1;
  if found then
    if lower(trim(c.company)) = lower(v_company) then
      return jsonb_build_object('status','exists','user_id',c.user_id,'code',c.code,'login',c.email);
    end if;
    return jsonb_build_object('status','suite_taken','by',c.company);
  end if;

  -- the address they will sign in with
  v_login := v_email;
  if v_login is not null and exists (select 1 from public.admins where lower(email) = v_login) then
    v_extra := concat_ws(E'\n', v_extra, 'Email ' || v_email || ' is a staff login, so this customer signs in with the code only');
    v_login := null;
  elsif v_login is not null and exists (select 1 from public.clients where lower(email) = v_login) then
    v_extra := concat_ws(E'\n', v_extra, 'Email ' || v_email || ' is also used by suite '
               || coalesce((select unit_number from public.clients where lower(email) = v_login limit 1), '?'));
    v_login := null;
  end if;
  if v_login is null then v_login := public.placeholder_login(v_suite); end if;

  v_code := public.gen_code();
  select id into v_uid from auth.users where lower(email) = v_login limit 1;
  if v_uid is not null then
    -- someone already has a login with this email (e.g. from the old approval flow): keep it, the code becomes its password
    v_status := 'linked';
    update auth.users
       set encrypted_password = extensions.crypt(v_code, extensions.gen_salt('bf')),
           email_confirmed_at = coalesce(email_confirmed_at, now()), updated_at = now()
     where id = v_uid;
  else
    v_uid := public.make_login(v_login, v_code, coalesce(v_name, v_company), v_company);
  end if;
  update public.access_codes set claimed_by = v_uid, claimed_at = now() where code = v_code;

  insert into public.clients (user_id, code, email, full_name, company, company_address, phone,
                              unit_number, form_sent, notes, details, source)
  values (v_uid, v_code, v_login, coalesce(v_name, v_company), v_company, v_addr, v_phone,
          v_suite, true, nullif(concat_ws(E'\n', v_notes, v_extra), ''), 'Imported from the customer list', 'import');

  insert into public.activity (actor, action, entity, detail)
  values (auth.jwt() ->> 'email', 'customer imported', 'clients',
          jsonb_build_object('suite', v_suite, 'company', v_company, 'status', v_status));

  return jsonb_build_object('status', v_status, 'user_id', v_uid, 'code', v_code, 'login', v_login);
end $$;

-- ------------------------------------------------------------ 2. staff edit a customer's details
-- p may hold any of: company, full_name, email, phone, company_address, unit_number, notes
create or replace function public.update_client_details(p_user uuid, p jsonb)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare c public.clients%rowtype; v text; v_email text; v_by text;
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  select * into c from public.clients where user_id = p_user for update;
  if not found then raise exception 'NOT_EDITABLE'; end if;

  if p ? 'company' then
    v := nullif(trim(p ->> 'company'), ''); if v is null then raise exception 'COMPANY_NEEDED'; end if;
    if length(v) > 200 then raise exception 'TOO_LONG'; end if;
    c.company := v;
  end if;
  if p ? 'full_name' then
    v := nullif(trim(p ->> 'full_name'), ''); if length(coalesce(v,'')) > 200 then raise exception 'TOO_LONG'; end if;
    c.full_name := coalesce(v, c.company);
  end if;
  if p ? 'phone' then
    v := nullif(trim(p ->> 'phone'), ''); if length(coalesce(v,'')) > 100 then raise exception 'TOO_LONG'; end if; c.phone := v;
  end if;
  if p ? 'company_address' then
    v := nullif(trim(p ->> 'company_address'), ''); if length(coalesce(v,'')) > 1000 then raise exception 'TOO_LONG'; end if; c.company_address := v;
  end if;
  if p ? 'notes' then
    v := nullif(trim(p ->> 'notes'), ''); if length(coalesce(v,'')) > 2000 then raise exception 'TOO_LONG'; end if; c.notes := v;
  end if;
  if p ? 'unit_number' then
    v := nullif(trim(p ->> 'unit_number'), ''); if length(coalesce(v,'')) > 20 then raise exception 'TOO_LONG'; end if;
    if v is not null then
      select company into v_by from public.clients where user_id <> p_user and lower(trim(unit_number)) = lower(v) limit 1;
      if v_by is not null then raise exception 'UNIT_TAKEN: %', v_by; end if;
    end if;
    c.unit_number := v;
  end if;

  if p ? 'email' then
    v_email := lower(nullif(trim(p ->> 'email'), ''));
    if v_email is null then v_email := public.placeholder_login(coalesce(c.unit_number, p_user::text)); end if;
    if v_email <> lower(c.email) then
      if v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]{2,}$' then raise exception 'EMAIL_INVALID'; end if;
      if exists (select 1 from public.admins where lower(email) = v_email) then raise exception 'EMAIL_IS_STAFF'; end if;
      if exists (select 1 from auth.users where lower(email) = v_email and id <> p_user) then raise exception 'EMAIL_TAKEN'; end if;
      update auth.users set email = v_email, email_confirmed_at = coalesce(email_confirmed_at, now()), updated_at = now()
       where id = p_user;
      update auth.identities set identity_data = identity_data || jsonb_build_object('email', v_email), updated_at = now()
       where user_id = p_user and provider = 'email';
      c.email := v_email;
    end if;
  end if;

  update public.clients
     set company = c.company, full_name = c.full_name, phone = c.phone, company_address = c.company_address,
         notes = c.notes, unit_number = c.unit_number, email = c.email
   where user_id = p_user;

  insert into public.activity (actor, action, entity, detail)
  values (auth.jwt() ->> 'email', 'customer details changed', 'clients',
          jsonb_build_object('user', p_user, 'fields', (select jsonb_agg(k) from jsonb_object_keys(p) k)));
  return public.customer_profile(p_user);
end $$;

-- ------------------------------------------------------------ imported customers count as active
-- Active = has a suite / unit and (imported from the list, or link sent and first top-up made).
create or replace function public.onboarding()
returns table(n bigint, user_id uuid, code text, company text, full_name text, email text, phone text, unit_number text,
              form_sent boolean, paid boolean, balance_pence bigint, complete boolean, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select row_number() over (order by c.created_at),
         c.user_id, c.code, c.company, c.full_name, c.email, c.phone,
         c.unit_number, c.form_sent,
         exists (select 1 from public.wallet_entries w
                  where w.user_id = c.user_id and w.kind = 'topup' and w.pence > 0),
         public.balance_of(c.user_id),
         (coalesce(nullif(trim(c.unit_number),''),'') <> ''
          and (c.source = 'import'
               or (c.form_sent and exists (select 1 from public.wallet_entries w
                                            where w.user_id = c.user_id and w.kind = 'topup' and w.pence > 0)))),
         c.created_at
    from public.clients c
   where public.is_admin()
   order by c.created_at;
$$;

-- ------------------------------------------------------------ profile also says where the customer came from
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
    'source', c.source,
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

-- ------------------------------------------------------------ 3. welcome message always has the code
-- {UNIT}, {COMPANY} and {CODE} are filled in; if the template has no {CODE}, the code is added at the end.
create or replace function public.welcome_for(p_user uuid)
returns text
language sql stable security definer set search_path = public as $$
  select case when x.tpl like '%{CODE}%' then x.msg
              else x.msg || E'\n\nPanel giriş kodunuz: ' || coalesce(x.code, '—') end
    from (select coalesce(t.value, '') as tpl, c.code,
                 replace(replace(replace(coalesce(t.value, ''),
                   '{UNIT}', coalesce(c.unit_number, '—')),
                   '{COMPANY}', coalesce(c.company, '')),
                   '{CODE}', coalesce(c.code, '—')) as msg
            from public.clients c
            left join public.app_settings t on t.key = 'welcome_template'
           where c.user_id = p_user) x
   where public.is_admin() or p_user = auth.uid();
$$;
