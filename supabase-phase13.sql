-- =====================================================================
-- Ecomflex phase 13 (9 Oct 2026)
--   Opening stock from the old per-customer spreadsheets. Staff read a customer's
--   Excel file in the admin console; this function writes the quantities into that
--   customer's stock in one go. Re-running it with the same file changes nothing.
-- No customer data is in this file. Safe to re-run.
-- =====================================================================

-- p_rows: [{sku, name, qty, barcode}]   (qty = units on the shelf now, a whole number >= 0)
-- returns {created, updated, unchanged, units}
create or replace function public.import_stock(p_user uuid, p_rows jsonb, p_source text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r jsonb; v_sku text; v_name text; v_bar text; v_qty integer; v_email text;
  s public.stock%rowtype; n_new int := 0; n_upd int := 0; n_same int := 0; n_units bigint := 0;
  seen text[] := '{}';
begin
  if not public.is_admin() then raise exception 'admins only'; end if;
  if not public.customer_exists(p_user) then raise exception 'no such customer'; end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then raise exception 'NO_ROWS'; end if;
  if jsonb_array_length(p_rows) > 3000 then raise exception 'TOO_MANY_ROWS'; end if;
  v_email := public.customer_email(p_user);

  for r in select * from jsonb_array_elements(p_rows) loop
    v_sku  := upper(regexp_replace(trim(coalesce(r ->> 'sku', '')), '\s+', ' ', 'g'));
    v_name := nullif(trim(coalesce(r ->> 'name', '')), '');
    v_bar  := nullif(regexp_replace(trim(coalesce(r ->> 'barcode', '')), '\.0+$', ''), '');
    if v_sku = '' or length(v_sku) > 64 then raise exception 'BAD_SKU: %', coalesce(r ->> 'sku', ''); end if;
    if (r ->> 'qty') !~ '^\s*\d{1,7}\s*$' then raise exception 'BAD_QTY: %', v_sku; end if;
    v_qty := (r ->> 'qty')::integer;
    if v_sku = any(seen) then raise exception 'DUPLICATE_SKU: %', v_sku; end if;
    seen := seen || v_sku;
    if length(coalesce(v_name, '')) > 200 or length(coalesce(v_bar, '')) > 64 then raise exception 'TOO_LONG: %', v_sku; end if;
    n_units := n_units + v_qty;

    select * into s from public.stock where user_id = p_user and upper(sku) = v_sku for update;
    if not found then
      insert into public.stock (user_id, user_email, sku, product_name, qty, barcode, active)
      values (p_user, v_email, v_sku, v_name, v_qty, v_bar, true);
      n_new := n_new + 1;
    elsif s.qty = v_qty and (s.product_name is not null or v_name is null) and (s.barcode is not null or v_bar is null) then
      n_same := n_same + 1;
    else
      -- the counted quantity wins; a name or barcode already in the app is kept
      update public.stock
         set qty = v_qty,
             product_name = coalesce(nullif(s.product_name, ''), v_name),
             barcode = coalesce(nullif(s.barcode, ''), v_bar),
             updated_at = now()
       where id = s.id;
      n_upd := n_upd + 1;
    end if;
  end loop;

  insert into public.activity (actor, action, entity, detail)
  values (auth.jwt() ->> 'email', 'opening stock imported', 'stock',
          jsonb_build_object('user', p_user, 'source', left(coalesce(p_source, ''), 200),
                             'created', n_new, 'updated', n_upd, 'unchanged', n_same, 'units', n_units));

  return jsonb_build_object('created', n_new, 'updated', n_upd, 'unchanged', n_same, 'units', n_units);
end $$;
