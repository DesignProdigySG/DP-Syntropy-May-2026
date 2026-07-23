-- ============================================================
-- DP Syntropy — demo_teardown.sql — remove the demo dataset
-- ------------------------------------------------------------
-- Deletes everything demo_seed.sql created, restoring the pre-demo state.
-- Safe to run anytime; idempotent (no-op if the demo isn't loaded).
--
--   Run: psql "$DATABASE_URL" -f supabase/demo_teardown.sql
--        (or paste into the Supabase SQL editor)
-- ============================================================

BEGIN;

DELETE FROM engagement_events   WHERE campaign LIKE 'zz-demo-%';
DELETE FROM actions             WHERE account  LIKE 'ZZ-DEMO-%';
DELETE FROM campaign_objectives WHERE campaign_id IN (SELECT id FROM campaigns WHERE account LIKE 'ZZ-DEMO-%');
DELETE FROM campaigns           WHERE account  LIKE 'ZZ-DEMO-%';
DELETE FROM mmm_channel_effects;   -- fit was derived from demo data

-- Also drop the staging table if a previous run left it behind:
DROP TABLE IF EXISTS public.zz_demo_spec;

COMMIT;

-- After this, the MMM tab falls back to the readiness bars (0 labeled),
-- and the dashboards return to whatever real data exists (empty pre-traffic).
