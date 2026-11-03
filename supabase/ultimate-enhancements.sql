-- SADEE PRO STORE additional features migration. Safe additive changes only.
BEGIN;
ALTER TABLE public.store_orders ADD COLUMN IF NOT EXISTS receipt_path text;
ALTER TABLE public.store_orders ALTER COLUMN order_code SET DEFAULT ('SD-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)));
-- Empty references are ignored by uniqueness; non-empty references cannot be reused.
DROP INDEX IF EXISTS public.store_orders_payment_reference_unique;
CREATE UNIQUE INDEX IF NOT EXISTS store_orders_payment_reference_unique ON public.store_orders (lower(btrim(payment_reference))) WHERE payment_reference IS NOT NULL AND btrim(payment_reference) <> '';
DROP INDEX IF EXISTS public.store_orders_license_key_ci_unique;
CREATE UNIQUE INDEX IF NOT EXISTS store_orders_license_key_ci_unique ON public.store_orders (lower(btrim(license_key))) WHERE license_key IS NOT NULL AND btrim(license_key) <> '';
CREATE TABLE IF NOT EXISTS public.license_key_history (id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_id uuid NOT NULL REFERENCES public.store_orders(id) ON DELETE CASCADE,previous_key text NOT NULL,new_key text NOT NULL,changed_at timestamptz NOT NULL DEFAULT now());
CREATE OR REPLACE FUNCTION public.record_license_key_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF OLD.license_key IS DISTINCT FROM NEW.license_key AND OLD.license_key IS NOT NULL AND btrim(OLD.license_key) <> '' THEN
    INSERT INTO public.license_key_history(order_id,previous_key,new_key,changed_at)
    VALUES(NEW.id,OLD.license_key,COALESCE(NEW.license_key,''),now());
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS store_orders_license_key_history ON public.store_orders;
CREATE TRIGGER store_orders_license_key_history
AFTER UPDATE OF license_key ON public.store_orders
FOR EACH ROW EXECUTE FUNCTION public.record_license_key_change();
ALTER TABLE public.license_key_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.license_key_history FROM anon,authenticated;
GRANT ALL ON public.license_key_history TO service_role;
COMMIT;
-- Storage setup: create two buckets in Supabase Storage UI: hero-media (PUBLIC) and order-receipts (PRIVATE).
-- Do not make order-receipts public. Uploads are performed by Netlify Functions with service role.
