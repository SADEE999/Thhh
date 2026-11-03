-- SADEE XDIMA REAL STORE V2 - SAFE SECURITY MIGRATION
-- Run AFTER the existing store schema/orders schema has been installed.
-- This script never deletes orders or license keys.

-- 1) Inspect duplicate payment references using the same normalization as the index.
select lower(btrim(regexp_replace(payment_reference, '\\s+', ' ', 'g'))) as normalized_reference,
       count(*) as duplicate_count,
       array_agg(order_code order by created_at) as order_codes
from public.store_orders
where payment_reference is not null and btrim(payment_reference) <> ''
group by lower(btrim(regexp_replace(payment_reference, '\\s+', ' ', 'g')))
having count(*) > 1;

-- 2) Inspect duplicate non-empty license keys.
select lower(btrim(license_key)) as normalized_license_key,
       count(*) as duplicate_count,
       array_agg(order_code order by created_at) as order_codes
from public.store_orders
where license_key is not null and btrim(license_key) <> ''
group by lower(btrim(license_key))
having count(*) > 1;

-- 3) Create unique indexes only when existing rows are clean.
-- If duplicates exist, the migration completes safely and prints a notice.
do $$
begin
  if not exists (
    select 1 from public.store_orders
    where payment_reference is not null and btrim(payment_reference) <> ''
    group by lower(btrim(regexp_replace(payment_reference, '\\s+', ' ', 'g')))
    having count(*) > 1
  ) then
    create unique index if not exists store_orders_payment_reference_normalized_uq
      on public.store_orders (lower(btrim(regexp_replace(payment_reference, '\\s+', ' ', 'g'))))
      where payment_reference is not null and btrim(payment_reference) <> '';
  else
    raise notice 'Duplicate payment references exist. Resolve them manually, then rerun this migration.';
  end if;

  if not exists (
    select 1 from public.store_orders
    where license_key is not null and btrim(license_key) <> ''
    group by lower(btrim(license_key))
    having count(*) > 1
  ) then
    create unique index if not exists store_orders_license_key_normalized_uq
      on public.store_orders (lower(btrim(license_key)))
      where license_key is not null and btrim(license_key) <> '';
  else
    raise notice 'Duplicate license keys exist. Resolve them manually, then rerun this migration.';
  end if;
end $$;

-- 4) Keep the orders table accessible only through trusted server-side functions.
alter table public.store_orders enable row level security;
revoke all on public.store_orders from anon, authenticated;
grant all on public.store_orders to service_role;
