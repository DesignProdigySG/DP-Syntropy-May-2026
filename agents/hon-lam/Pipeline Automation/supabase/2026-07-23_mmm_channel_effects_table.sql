-- 2026-07-23 — Recreate public.mmm_channel_effects (missed by the re-home)
-- Applied live via Supabase MCP migration `mmm_channel_effects_table`.
--
-- This table stores the fitted per-funnel-stage channel odds ratios that
-- `mmm/mmm_regression.py --db-write` upserts (DELETE-then-INSERT), and that the
-- dashboards' MMM tab reads directly via anon (fetchView('mmm_channel_effects')).
-- It existed on the old Supabase project but was never captured in setup.sql, so
-- the 2026-07-13 re-home to ssbdlttcyogtcowvcbaj didn't recreate it — the MMM tab
-- 404'd with PGRST205. Column set matches the INSERT in mmm_regression.write_db()
-- plus computed_at (read by the dashboard as "As of ...").

CREATE TABLE IF NOT EXISTS public.mmm_channel_effects (
  funnel_stage text        NOT NULL,
  channel      text        NOT NULL,
  odds_ratio   double precision,
  ci_low       double precision,
  ci_high      double precision,
  p_value      double precision,
  significant  boolean,
  method       text,
  labeled_rows integer,
  computed_at  timestamptz NOT NULL DEFAULT now()
);

-- Read directly by the anon dashboards (not via a security-definer view), so it
-- needs an explicit SELECT grant + a permissive RLS read policy. Writes come from
-- mmm_regression.py over the direct postgres connection (owner bypasses RLS).
ALTER TABLE public.mmm_channel_effects ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.mmm_channel_effects FROM anon, authenticated, PUBLIC;
GRANT SELECT ON public.mmm_channel_effects TO anon, authenticated;

DROP POLICY IF EXISTS mmm_channel_effects_read ON public.mmm_channel_effects;
CREATE POLICY mmm_channel_effects_read ON public.mmm_channel_effects
  FOR SELECT TO anon, authenticated USING (true);
