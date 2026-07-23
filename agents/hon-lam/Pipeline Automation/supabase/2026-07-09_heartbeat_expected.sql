-- 2026-07-09 — Pipeline Heartbeat registry
-- Applied live via Supabase MCP migration `heartbeat_expected_table`.
-- Read daily by the n8n "Pipeline Heartbeat" workflow (blpfVN7IwgfJJxn2):
-- it asks the n8n API which workflows are active + when they last ran, and
-- alerts on anything here that is deactivated or (for kind='schedule')
-- silent past max_silence_hours. Catches silent auto-deactivation — the
-- failure mode the Error Workflow can't see (2026-07-01 Sign Link incident).
--
-- Maintenance: when a new workflow is added to the pipeline, INSERT a row
-- here; when one is retired, set enabled=false (or delete the row).

CREATE TABLE public.heartbeat_expected (
  workflow_id text PRIMARY KEY,
  name text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('schedule','webhook')),
  max_silence_hours integer,           -- null for webhook kind
  enabled boolean NOT NULL DEFAULT true,
  note text
);
ALTER TABLE public.heartbeat_expected ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.heartbeat_expected FROM anon, authenticated, PUBLIC;

-- Seeded 2026-07-09 with 11 schedule workflows (26h window; Draft Backfill 6h)
-- and 13 webhook workflows (active-status check only). See the live table for
-- the authoritative list.
