-- SADEE PRO STORE: ORDER LICENSE DURATION + STOCK SETUP
-- Run in Supabase SQL Editor before deploying this update.
-- Preserves existing products, orders, prices, categories and keys.
BEGIN;
ALTER TABLE public.store_orders
  ADD COLUMN IF NOT EXISTS license_duration text;
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS stock integer NOT NULL DEFAULT 999;
UPDATE public.products SET stock = 999 WHERE active = true;
CREATE OR REPLACE FUNCTION public.decrement_product_stock(p_product_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE changed integer;
BEGIN
  UPDATE public.products
  SET stock = stock - 1, updated_at = now()
  WHERE id = p_product_id AND active = true AND stock > 0;
  GET DIAGNOSTICS changed = ROW_COUNT;
  RETURN changed = 1;
END;
$$;
REVOKE ALL ON FUNCTION public.decrement_product_stock(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.decrement_product_stock(uuid) TO service_role;
COMMIT;
SELECT id,name,active,stock FROM public.products ORDER BY created_at DESC;
