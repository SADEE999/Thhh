-- SADEE PRO STORE ULTIMATE UPDATE — SAFE ADDITIVE MIGRATION
-- Run once in Supabase SQL Editor. Does not delete products or orders.
BEGIN;
ALTER TABLE public.store_orders ADD COLUMN IF NOT EXISTS license_duration text;
ALTER TABLE public.store_orders ADD COLUMN IF NOT EXISTS license_expires_at timestamptz;
-- Requested catalog availability setting: set active products to 999. This is a display/availability quantity, not a count of pre-generated license keys.
UPDATE public.products SET stock = 999 WHERE active = true;
-- Keep payment references unique (case-insensitive). Existing duplicates must be reviewed manually.
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.store_orders GROUP BY lower(payment_reference) HAVING count(*)>1) THEN
   RAISE EXCEPTION 'Duplicate payment references exist. Review them before creating the unique index.';
 END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS store_orders_payment_reference_unique ON public.store_orders (lower(payment_reference));
-- A license key can belong to only one order, ignoring letter case.
DO $$ BEGIN
 IF EXISTS (SELECT 1 FROM public.store_orders WHERE license_key IS NOT NULL GROUP BY lower(license_key) HAVING count(*)>1) THEN
   RAISE EXCEPTION 'Duplicate license keys exist. Review them before creating the unique index.';
 END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS store_orders_license_key_ci_unique ON public.store_orders (lower(license_key)) WHERE license_key IS NOT NULL;
-- Private audit trail for admin key changes. Service-role only.
CREATE TABLE IF NOT EXISTS public.license_key_history (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 order_id uuid NOT NULL REFERENCES public.store_orders(id) ON DELETE CASCADE,
 previous_key text NOT NULL,
 new_key text NOT NULL,
 changed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.license_key_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.license_key_history FROM anon, authenticated;
GRANT ALL ON public.license_key_history TO service_role;
COMMIT;
SELECT 'SADEE PRO STORE migration complete' AS result;
