-- SADEE XDIMA V4 additive migration. Preserves existing products, orders and keys.
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS app_screenshots text[] NOT NULL DEFAULT '{}';
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS version_history jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS download_count bigint NOT NULL DEFAULT 0;
ALTER TABLE public.promo_codes ADD COLUMN IF NOT EXISTS expires_at timestamptz;
ALTER TABLE public.promo_codes ADD COLUMN IF NOT EXISTS max_uses integer;
ALTER TABLE public.promo_codes ADD COLUMN IF NOT EXISTS starts_at timestamptz;
CREATE TABLE IF NOT EXISTS public.store_activity_log (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor text NOT NULL DEFAULT 'admin', action text NOT NULL, detail text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.store_activity_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.store_activity_log FROM anon, authenticated;
GRANT ALL ON public.store_activity_log TO service_role;
CREATE TABLE IF NOT EXISTS public.store_notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), kind text NOT NULL, title text NOT NULL, body text NOT NULL DEFAULT '', read_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.store_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.store_notifications FROM anon, authenticated;
GRANT ALL ON public.store_notifications TO service_role;

CREATE OR REPLACE FUNCTION public.increment_app_download(p_product_id uuid) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
 UPDATE public.products SET download_count = COALESCE(download_count,0) + 1 WHERE id=p_product_id AND lower(category)='apps' AND active=true;
$$;
REVOKE ALL ON FUNCTION public.increment_app_download(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_app_download(uuid) TO service_role;
