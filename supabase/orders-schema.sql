-- Run this in Supabase SQL Editor. Orders and license keys are server-only.
create extension if not exists pgcrypto;
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
 amount numeric(12,2) not null check(amount>=0),
 original_amount numeric(12,2) not null default 0 check(original_amount>=0),
 discount_amount numeric(12,2) not null default 0 check(discount_amount>=0),
 promo_code text,
 payment_method text not null default 'eZ Cash',
 payment_reference text not null,
 status text not null default 'pending' check(status in ('pending','verified','rejected')),
 license_key text unique,
 verified_at timestamptz,
 constraint license_after_verification check ((status='verified' and license_key is not null) or (status<>'verified' and license_key is null))
);
alter table public.store_orders add column if not exists original_amount numeric(12,2) not null default 0;
alter table public.store_orders add column if not exists discount_amount numeric(12,2) not null default 0;
alter table public.store_orders add column if not exists promo_code text;
update public.store_orders set original_amount=amount where original_amount=0 and amount>0;
alter table public.store_orders enable row level security;
revoke all on public.store_orders from anon, authenticated;
grant all on public.store_orders to service_role;
-- Do not create public/anon policies for this table. Netlify Functions use server-side service-role key.

-- Prevent reusing one payment reference for multiple orders.
create unique index if not exists store_orders_payment_reference_unique
on public.store_orders (lower(payment_reference));

-- Optional store features: promotions, public announcements and moderated reviews.
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
create table if not exists public.store_announcements (
 id uuid primary key default gen_random_uuid(),
 title text not null check (char_length(title) between 1 and 120),
 body text not null check (char_length(body) <= 1200),
 kind text not null default 'update' check (kind in ('update','maintenance','offer')),
 published boolean not null default false,
 created_at timestamptz not null default now()
);
create table if not exists public.product_reviews (
 id uuid primary key default gen_random_uuid(),
 product_id uuid not null references public.products(id) on delete cascade,
 customer_name text not null check (char_length(customer_name) between 1 and 60),
 rating integer not null check (rating between 1 and 5),
 review_text text not null default '' check (char_length(review_text) <= 500),
 approved boolean not null default false,
 created_at timestamptz not null default now()
);
alter table public.promo_codes enable row level security;
alter table public.store_announcements enable row level security;
alter table public.product_reviews enable row level security;
revoke all on public.promo_codes, public.store_announcements, public.product_reviews from anon, authenticated;
grant all on public.promo_codes, public.store_announcements, public.product_reviews to service_role;
-- Public reads are intentionally limited to published announcements and approved reviews.
grant select on public.store_announcements, public.product_reviews to anon, authenticated;
drop policy if exists "Read published announcements" on public.store_announcements;
create policy "Read published announcements" on public.store_announcements for select to anon, authenticated using (published = true);
drop policy if exists "Read approved product reviews" on public.product_reviews;
create policy "Read approved product reviews" on public.product_reviews for select to anon, authenticated using (approved = true);

create or replace function public.increment_promo_use(p_code text) returns void language sql security definer set search_path=public as $$ update public.promo_codes set uses=uses+1 where code=p_code and active=true; $$;
revoke all on function public.increment_promo_use(text) from public, anon, authenticated;
grant execute on function public.increment_promo_use(text) to service_role;

create or replace function public.decrement_product_stock(p_product_id uuid) returns boolean language plpgsql security definer set search_path=public as $$ declare changed integer; begin update public.products set stock=stock-1 where id=p_product_id and stock>0; get diagnostics changed=row_count; return changed=1; end; $$;
revoke all on function public.decrement_product_stock(uuid) from public, anon, authenticated;
grant execute on function public.decrement_product_stock(uuid) to service_role;
