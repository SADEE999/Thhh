-- SADEE PRO STORE: STOCK + ORDER STATUS FIX
-- Run this once in Supabase SQL Editor.
-- Active products are set to 999 stock as requested.
-- No products, prices, categories, or license keys are deleted.

BEGIN;

-- Ensure stock exists and is non-negative.
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS stock integer NOT NULL DEFAULT 999;

-- Set all currently active products to the requested stock amount.
UPDATE public.products
SET stock = 999
WHERE active = true;

-- Install the stock decrement RPC used when the admin verifies payment.
-- This prevents overselling if stock is later reduced below 999.
CREATE OR REPLACE FUNCTION public.decrement_product_stock(p_product_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  changed integer;
BEGIN
  UPDATE public.products
  SET stock = stock - 1,
      updated_at = now()
  WHERE id = p_product_id
    AND active = true
    AND stock > 0;

  GET DIAGNOSTICS changed = ROW_COUNT;
  RETURN changed = 1;
END;
$$;

REVOKE ALL ON FUNCTION public.decrement_product_stock(uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.decrement_product_stock(uuid)
TO service_role;

COMMIT;

-- Verify stock values after the update.
SELECT id, name, active, stock
FROM public.products
ORDER BY created_at DESC;
