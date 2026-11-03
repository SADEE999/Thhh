-- ============================================================
-- SADEE XDIMA V4 - FULL SUPABASE SETUP / SAFE UPGRADE
-- Run in Supabase SQL Editor as project owner.
-- Idempotent, additive setup: does not delete products, orders,
-- license keys, reviews, settings, or storage objects.
-- ============================================================

begin;

create extension if not exists pgcrypto;

-- 1. CORE TABLES ------------------------------------------------
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  description text not null default '' check (char_length(description) <= 800),
  price numeric(12,2) not null default 0 check (price >= 0),
  category text not null default 'Digital',
  image_url text,
  download_url text,
  version text not null default '',
  compatibility text not null default '',
  features jsonb not null default '[]'::jsonb,
  plans jsonb not null default '[]'::jsonb,
  featured boolean not null default false,
  stock integer not null default 999 check (stock >= 0),
  active boolean not null default true,
  app_screenshots text[] not null default '{}',
  version_history jsonb not null default '[]'::jsonb,
  download_count bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Upgrade older products table without replacing existing data.
alter table public.products add column if not exists description text not null default '';
alter table public.products add column if not exists price numeric(12,2) not null default 0;
alter table public.products add column if not exists category text not null default 'Digital';
alter table public.products add column if not exists image_url text;
alter table public.products add column if not exists download_url text;
alter table public.products add column if not exists version text not null default '';
alter table public.products add column if not exists compatibility text not null default '';
alter table public.products add column if not exists features jsonb not null default '[]'::jsonb;
alter table public.products add column if not exists plans jsonb not null default '[]'::jsonb;
alter table public.products add column if not exists featured boolean not null default false;
alter table public.products add column if not exists stock integer not null default 999;
alter table public.products add column if not exists active boolean not null default true;
alter table public.products add column if not exists app_screenshots text[] not null default '{}';
alter table public.products add column if not exists version_history jsonb not null default '[]'::jsonb;
alter table public.products add column if not exists download_count bigint not null default 0;
alter table public.products add column if not exists updated_at timestamptz not null default now();

create table if not exists public.site_settings (
  key text primary key check (char_length(key) between 1 and 80),
  value text not null default '',
  updated_at timestamptz not null default now()
);

-- Legacy checkout table is retained for compatibility with older installs.
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  quantity integer not null check (quantity between 1 and 20),
  customer_name text not null,
  phone text not null,
  notes text not null default '',
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

-- 2. DIGITAL STORE ORDERS ---------------------------------------
create table if not exists public.store_orders (
  id uuid primary key default gen_random_uuid(),
  order_code text not null unique default ('SD-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
  created_at timestamptz not null default now(),
  customer_name text not null,
  customer_email text not null,
  device text not null default '',
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  plan_name text not null,
  amount numeric(12,2) not null default 0 check (amount >= 0),
  original_amount numeric(12,2) not null default 0 check (original_amount >= 0),
  discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
  promo_code text,
  payment_method text not null default 'eZ Cash',
  payment_reference text not null,
  receipt_path text,
  status text not null default 'pending' check (status in ('pending','verified','rejected')),
  license_key text,
  license_duration text,
  license_expires_at timestamptz,
  verified_at timestamptz,
  constraint store_orders_license_after_verification
    check ((status = 'verified' and license_key is not null and btrim(license_key) <> '')
        or (status <> 'verified' and license_key is null))
);

alter table public.store_orders add column if not exists original_amount numeric(12,2) not null default 0;
alter table public.store_orders add column if not exists discount_amount numeric(12,2) not null default 0;
alter table public.store_orders add column if not exists promo_code text;
alter table public.store_orders add column if not exists receipt_path text;
alter table public.store_orders add column if not exists license_duration text;
alter table public.store_orders add column if not exists license_expires_at timestamptz;
alter table public.store_orders add column if not exists verified_at timestamptz;
update public.store_orders set original_amount = amount where original_amount = 0 and amount > 0;

-- 3. PROMOS, ANNOUNCEMENTS, REVIEWS ------------------------------
create table if not exists public.promo_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  discount_percent integer not null check (discount_percent between 1 and 90),
  active boolean not null default true,
  starts_at timestamptz,
  expires_at timestamptz,
  max_uses integer check (max_uses is null or max_uses > 0),
  uses integer not null default 0 check (uses >= 0),
  created_at timestamptz not null default now()
);
alter table public.promo_codes add column if not exists starts_at timestamptz;
alter table public.promo_codes add column if not exists expires_at timestamptz;
alter table public.promo_codes add column if not exists max_uses integer;
alter table public.promo_codes add column if not exists uses integer not null default 0;

create table if not exists public.store_announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  kind text not null default 'update' check (kind in ('update','maintenance','offer')),
  published boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  customer_name text not null,
  rating integer not null check (rating between 1 and 5),
  review_text text not null default '',
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

-- 4. V4 ADMIN LOGS + NOTIFICATIONS -------------------------------
create table if not exists public.store_activity_log (
  id uuid primary key default gen_random_uuid(),
  actor text not null default 'admin',
  action text not null,
  detail text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.store_notifications (
  id uuid primary key default gen_random_uuid(),
  kind text not null,
  title text not null,
  body text not null default '',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.license_key_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.store_orders(id) on delete cascade,
  previous_key text not null,
  new_key text not null,
  changed_at timestamptz not null default now()
);

-- 5. RLS / ACCESS CONTROL ---------------------------------------
alter table public.admin_users enable row level security;
alter table public.products enable row level security;
alter table public.site_settings enable row level security;
alter table public.orders enable row level security;
alter table public.store_orders enable row level security;
alter table public.promo_codes enable row level security;
alter table public.store_announcements enable row level security;
alter table public.product_reviews enable row level security;
alter table public.store_activity_log enable row level security;
alter table public.store_notifications enable row level security;
alter table public.license_key_history enable row level security;

revoke all on public.store_orders, public.orders, public.promo_codes,
  public.store_activity_log, public.store_notifications, public.license_key_history
  from anon, authenticated;
grant all on public.store_orders, public.orders, public.promo_codes,
  public.store_activity_log, public.store_notifications, public.license_key_history
  to service_role;

grant select on public.products, public.site_settings to anon, authenticated;
revoke insert, update, delete on public.products, public.site_settings from anon, authenticated;
grant select on public.store_announcements, public.product_reviews to anon, authenticated;
revoke insert, update, delete on public.store_announcements, public.product_reviews from anon, authenticated;

drop policy if exists "Public can view active products" on public.products;
create policy "Public can view active products" on public.products
  for select to anon, authenticated using (active = true);
drop policy if exists "Public can read site settings" on public.site_settings;
create policy "Public can read site settings" on public.site_settings
  for select to anon, authenticated using (true);
drop policy if exists "Read published announcements" on public.store_announcements;
create policy "Read published announcements" on public.store_announcements
  for select to anon, authenticated using (published = true);
drop policy if exists "Read approved product reviews" on public.product_reviews;
create policy "Read approved product reviews" on public.product_reviews
  for select to anon, authenticated using (approved = true);

-- 6. UNIQUE PAYMENT REFERENCES / LICENSE KEYS ------------------
-- Existing duplicate rows are not deleted. If duplicates exist, indexes are
-- skipped and a NOTICE is emitted. Review duplicate query results below.
do $$
begin
  if not exists (
    select 1 from public.store_orders
    where payment_reference is not null and btrim(payment_reference) <> ''
    group by lower(regexp_replace(btrim(payment_reference), '\s+', ' ', 'g'))
    having count(*) > 1
  ) then
    execute $index$ create unique index if not exists store_orders_payment_reference_v4_uq on public.store_orders (lower(regexp_replace(btrim(payment_reference), '\s+', ' ', 'g'))) where payment_reference is not null and btrim(payment_reference) <> '' $index$;
  else
    raise notice 'Duplicate payment references found. Unique reference index skipped; inspect duplicate query after this script.';
  end if;
  if not exists (
    select 1 from public.store_orders
    where license_key is not null and btrim(license_key) <> ''
    group by lower(btrim(license_key))
    having count(*) > 1
  ) then
    execute $index$ create unique index if not exists store_orders_license_key_v4_uq on public.store_orders (lower(btrim(license_key))) where license_key is not null and btrim(license_key) <> '' $index$;
  else
    raise notice 'Duplicate license keys found. Unique license index skipped; inspect duplicate query after this script.';
  end if;
end $$;

-- 7. LICENSE KEY CHANGE HISTORY ---------------------------------
create or replace function public.record_license_key_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.license_key is distinct from new.license_key
     and old.license_key is not null and btrim(old.license_key) <> '' then
    insert into public.license_key_history(order_id, previous_key, new_key)
    values (new.id, old.license_key, coalesce(new.license_key, ''));
  end if;
  return new;
end;
$$;
revoke all on function public.record_license_key_change() from public, anon, authenticated;
drop trigger if exists store_orders_license_key_history on public.store_orders;
create trigger store_orders_license_key_history
after update of license_key on public.store_orders
for each row execute function public.record_license_key_change();

-- 8. RPC FUNCTIONS ----------------------------------------------
create or replace function public.increment_app_download(p_product_id uuid)
returns void language sql security definer set search_path = public as $$
  update public.products
     set download_count = coalesce(download_count, 0) + 1
   where id = p_product_id and lower(category) = 'apps' and active = true;
$$;
revoke all on function public.increment_app_download(uuid) from public, anon, authenticated;
grant execute on function public.increment_app_download(uuid) to service_role;

create or replace function public.increment_promo_use(p_code text)
returns void language sql security definer set search_path = public as $$
  update public.promo_codes set uses = uses + 1
   where upper(code) = upper(p_code) and active = true
     and (starts_at is null or starts_at <= now())
     and (expires_at is null or expires_at > now())
     and (max_uses is null or uses < max_uses);
$$;
revoke all on function public.increment_promo_use(text) from public, anon, authenticated;
grant execute on function public.increment_promo_use(text) to service_role;

create or replace function public.decrement_product_stock(p_product_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare changed integer;
begin
  update public.products set stock = stock - 1, updated_at = now()
   where id = p_product_id and active = true and stock > 0;
  get diagnostics changed = row_count;
  return changed = 1;
end;
$$;
revoke all on function public.decrement_product_stock(uuid) from public, anon, authenticated;
grant execute on function public.decrement_product_stock(uuid) to service_role;

-- 9. STORAGE BUCKETS --------------------------------------------
-- Product images are public-read. Payment receipts remain PRIVATE.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 5242880,
        array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif'];

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('order-receipts', 'order-receipts', false, 3145728,
        array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false, file_size_limit = 3145728,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('hero-media', 'hero-media', true, 52428800,
        array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm'])
on conflict (id) do update set public = true;

-- Public can view product images and hero media. Uploads use Netlify service role.
drop policy if exists "Public can read product images" on storage.objects;
create policy "Public can read product images" on storage.objects
  for select to anon, authenticated using (bucket_id = 'product-images');
drop policy if exists "Public can read hero media" on storage.objects;
create policy "Public can read hero media" on storage.objects
  for select to anon, authenticated using (bucket_id = 'hero-media');

commit;

-- 10. POST-RUN CHECKS -------------------------------------------
select 'products' as table_name, count(*) as row_count from public.products
union all select 'store_orders', count(*) from public.store_orders
union all select 'promo_codes', count(*) from public.promo_codes
union all select 'product_reviews', count(*) from public.product_reviews
union all select 'store_activity_log', count(*) from public.store_activity_log
union all select 'store_notifications', count(*) from public.store_notifications;

-- Review duplicates. If any rows appear, resolve them manually before relying
-- on unique payment/license indexes. No existing data is deleted by this script.
select lower(regexp_replace(btrim(payment_reference), '\s+', ' ', 'g')) as normalized_reference,
       count(*) as duplicate_count, array_agg(order_code order by created_at) as order_codes
from public.store_orders
where payment_reference is not null and btrim(payment_reference) <> ''
group by lower(regexp_replace(btrim(payment_reference), '\s+', ' ', 'g'))
having count(*) > 1;

select lower(btrim(license_key)) as normalized_license_key,
       count(*) as duplicate_count, array_agg(order_code order by created_at) as order_codes
from public.store_orders
where license_key is not null and btrim(license_key) <> ''
group by lower(btrim(license_key))
having count(*) > 1;

-- ADMIN SETUP (manual): create the admin's Auth user in Supabase Dashboard,
-- then run this separately with that user's real UUID:
-- insert into public.admin_users(user_id) values ('YOUR-AUTH-USER-UUID');
-- Never put SUPABASE_SERVICE_ROLE_KEY in frontend code or GitHub.
