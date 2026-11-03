-- SADEE PRO STORE schema for Supabase SQL Editor.
-- Run this whole file in the SQL Editor after creating a Supabase project.
create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  description text not null default '' check (char_length(description) <= 800),
  price numeric(12,2) not null default 0 check (price >= 0),
  category text not null default 'Digital' check (category in ('Gaming','Accessories','Digital','Apps','Sensitivity','Other')),
  image_url text,
  download_url text,
  version text not null default '',
  compatibility text not null default '',
  features jsonb not null default '[]'::jsonb,
  plans jsonb not null default '[]'::jsonb,
  featured boolean not null default false,
  stock integer not null default 0 check (stock >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);


-- Upgrade an existing installation safely (new product-detail fields).
alter table public.products add column if not exists download_url text;
alter table public.products add column if not exists version text not null default '';
alter table public.products add column if not exists compatibility text not null default '';
alter table public.products add column if not exists features jsonb not null default '[]'::jsonb;
alter table public.products add column if not exists plans jsonb not null default '[]'::jsonb;
alter table public.products add column if not exists featured boolean not null default false;
-- Permit the expanded product categories on older installations.
alter table public.products drop constraint if exists products_category_check;
alter table public.products add constraint products_category_check check (category in ('Gaming','Accessories','Digital','Apps','Sensitivity','Other'));

create table if not exists public.site_settings (
  key text primary key check (char_length(key) between 1 and 80),
  value text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  quantity integer not null check (quantity between 1 and 20),
  customer_name text not null check (char_length(customer_name) between 1 and 80),
  phone text not null check (char_length(phone) between 3 and 30),
  notes text not null default '' check (char_length(notes) <= 500),
  status text not null default 'pending' check (status in ('pending','confirmed','completed','cancelled')),
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.site_settings enable row level security;

-- The admin page may read only its own allowlist row.
drop policy if exists "Admins can read own allowlist row" on public.admin_users;
create policy "Admins can read own allowlist row" on public.admin_users
for select to authenticated using (user_id = (select auth.uid()));

-- Explicit API grants are needed in addition to RLS policies.
grant select on public.products to anon, authenticated;
grant select on public.site_settings to anon, authenticated;
revoke insert, update, delete on public.site_settings from anon, authenticated;
revoke insert, update, delete on public.products from anon, authenticated;
revoke all on public.orders from anon, authenticated;
-- Site settings writes are server-side only; Netlify Functions use service_role.
revoke all on public.orders from anon, authenticated;
-- Product writes are server-side only; Netlify Functions use service_role.
-- Customer orders are server-side only; Netlify Functions use service_role.
grant select on public.admin_users to authenticated;

-- Admin check runs with a controlled definer, avoiding recursive RLS on admin_users.
create or replace function public.is_store_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_users
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_store_admin() from public;
grant execute on function public.is_store_admin() to anon, authenticated;

drop policy if exists "Public can view active products" on public.products;
create policy "Public can view active products" on public.products
for select to anon, authenticated using (true);

drop policy if exists "Admins manage products" on public.products;
drop policy if exists "No-login panel can manage products" on public.products;
-- Mutations are handled by secret-protected Netlify Functions.

drop policy if exists "Visitors can submit pending orders" on public.orders;

drop policy if exists "Admins view orders" on public.orders;
drop policy if exists "No-login panel can view orders" on public.orders;

drop policy if exists "Admins update orders" on public.orders;
drop policy if exists "No-login panel can update orders" on public.orders;

drop policy if exists "Admins delete orders" on public.orders;
drop policy if exists "No-login panel can delete orders" on public.orders;

drop policy if exists "Public can read hero video setting" on public.site_settings;
create policy "Public can read hero video setting" on public.site_settings
for select to anon, authenticated using (true);
drop policy if exists "Admins manage site settings" on public.site_settings;
drop policy if exists "No-login panel can manage site settings" on public.site_settings;
-- Settings mutations are handled by secret-protected Netlify Functions.

-- Add a first product only if you want a demo listing; edit/delete it in the admin panel.
insert into public.products(name,description,price,category,stock,active)
select 'Starter Gaming Pack','Example listing — edit this product and price before publishing.',1500,'Gaming',10,true
where not exists (select 1 from public.products);

-- IMPORTANT: create your admin user in Supabase Dashboard > Authentication > Users.
-- Then copy that user's UUID and run the next statement manually, replacing the UUID:
-- insert into public.admin_users(user_id) values ('PASTE-ADMIN-USER-UUID-HERE');


-- Enforce the current product name and price server-side. Browsers must not be
-- trusted to submit a correct price. This trigger also rejects hidden/out-of-stock items.
create or replace function public.prepare_store_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  item record;
begin
  select p.id, p.name, p.price, p.stock, p.active
    into item
    from public.products as p
   where p.id = new.product_id;

  if not found or item.active is not true then
    raise exception 'This product is not available';
  end if;
  if item.stock < new.quantity then
    raise exception 'Not enough stock for this order';
  end if;

  new.product_name := item.name;
  new.unit_price := item.price;
  new.status := 'pending';
  return new;
end;
$$;

revoke all on function public.prepare_store_order() from public;

drop trigger if exists prepare_store_order_before_insert on public.orders;
create trigger prepare_store_order_before_insert
before insert on public.orders
for each row execute function public.prepare_store_order();


-- PRODUCT IMAGE UPLOADS. Public read/write is enabled for the no-login admin requested by the owner.
-- Public users can read images; upload/delete are performed by protected Netlify Functions.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 5242880, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif'];
drop policy if exists "Public can read product images" on storage.objects;
create policy "Public can read product images" on storage.objects for select to anon, authenticated using (bucket_id = 'product-images');
drop policy if exists "No-login panel can upload product images" on storage.objects;
drop policy if exists "No-login panel can update product images" on storage.objects;
drop policy if exists "No-login panel can delete product images" on storage.objects;
