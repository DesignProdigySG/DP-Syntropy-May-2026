-- 2026-07-09 — Security/perf hardening + measurement alignment
-- Applied live via Supabase MCP migration `security_perf_hardening_2026_07_09`
-- (parts 1–4), plus the data UPDATEs in part 5 (run via execute_sql, not DDL).
-- This file is the repo record of both.

-- ============================================================
-- 1. ROOT-CAUSE FIX for the recurring default-ACL leak.
--    The standing rule granted anon/authenticated full CRUD on every
--    future table (arwdDxtm), rwU on sequences. Caused the same leak
--    4 times (3 views + the 2026-07-06 MMM tables). Now dropped.
--    NOTE: a parallel supabase_admin-owned rule still exists in
--    pg_default_acl, but it only applies to objects created BY
--    supabase_admin (Supabase internals), not by us — left alone.
-- ============================================================
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;

-- ============================================================
-- 2. Fix the 3 tables that leaked via that rule (MMM migration).
--    funnel_stages + campaign_objectives are internal-only
--    (n8n connects as the table owner and bypasses RLS).
--    action_channels IS read directly by the dashboards' anon key
--    (Settings-tab channel checklist) -> explicit read-only policy.
-- ============================================================
ALTER TABLE public.funnel_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaign_objectives ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.funnel_stages FROM anon, authenticated;
REVOKE ALL ON public.campaign_objectives FROM anon, authenticated;

ALTER TABLE public.action_channels ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.action_channels FROM anon, authenticated;
GRANT SELECT ON public.action_channels TO anon, authenticated;
DROP POLICY IF EXISTS action_channels_read ON public.action_channels;
CREATE POLICY action_channels_read ON public.action_channels FOR SELECT TO anon, authenticated USING (true);

-- ============================================================
-- 3. Covering indexes for all 8 FKs the performance advisor
--    flagged as unindexed (4 original + 4 new funnel_stage FKs).
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_actions_campaign_id ON public.actions(campaign_id);
CREATE INDEX IF NOT EXISTS idx_actions_funnel_stage ON public.actions(funnel_stage);
CREATE INDEX IF NOT EXISTS idx_cadence_steps_funnel_stage ON public.cadence_steps(funnel_stage);
CREATE INDEX IF NOT EXISTS idx_campaign_objectives_funnel_stage ON public.campaign_objectives(funnel_stage);
CREATE INDEX IF NOT EXISTS idx_campaign_templates_funnel_stage ON public.campaign_templates(funnel_stage);
CREATE INDEX IF NOT EXISTS idx_campaigns_run_id ON public.campaigns(run_id);
CREATE INDEX IF NOT EXISTS idx_engagement_events_action_id ON public.engagement_events(action_id);
CREATE INDEX IF NOT EXISTS idx_salesforce_leads_campaign_id ON public.salesforce_leads(campaign_id);

-- ============================================================
-- 4. Pin search_path on the pg_cron-invoked function
--    (security-linter WARN: role-mutable search_path).
-- ============================================================
ALTER FUNCTION public.update_objective_status() SET search_path = public;

-- ============================================================
-- 5. DATA: align campaign_templates.objective_success_events with
--    the event types the 2026-07-08 LinkedIn/Email feeders emit,
--    so automated measurement can actually SATISFY objectives.
--    Mapping rationale:
--      - linkedin_reply is reply-class -> counts for every
--        "reply-or-meeting" objective (the 13 meeting_booked templates).
--      - profile_visit templates (narrow_coverage_nurture,
--        warm_reengage) also accept the automated twins
--        linkedin_profile_view + linkedin_accept.
--      - warm_reengage additionally accepts linkedin_post_engage
--        (inbound post engagement = evidence of re-engagement).
--      - thought_leadership (content_download) also accepts
--        email_click (tracked click-through to content).
--      - email_open deliberately NOT a success event anywhere
--        (bot/scanner noise); it still contributes to account_score.
--      - partner_campaign (partner_response) and webinar
--        (registration) unchanged.
-- ============================================================
UPDATE campaign_templates SET objective_success_events = array_append(objective_success_events,'linkedin_reply')
WHERE 'meeting_booked' = ANY(objective_success_events) AND NOT 'linkedin_reply' = ANY(objective_success_events);

UPDATE campaign_templates SET objective_success_events = objective_success_events || ARRAY['linkedin_profile_view','linkedin_accept']
WHERE 'profile_visit' = ANY(objective_success_events) AND NOT 'linkedin_profile_view' = ANY(objective_success_events);

UPDATE campaign_templates SET objective_success_events = array_append(objective_success_events,'linkedin_post_engage')
WHERE key = 'warm_reengage' AND NOT 'linkedin_post_engage' = ANY(objective_success_events);

UPDATE campaign_templates SET objective_success_events = array_append(objective_success_events,'email_click')
WHERE key = 'thought_leadership' AND NOT 'email_click' = ANY(objective_success_events);

-- ============================================================
-- 6. DATA housekeeping (run 2026-07-09, recorded here for the log):
--    DEMO -- Meridian Logistics rows deleted from engagement_events,
--    campaign_objectives, actions, campaigns, pipeline_runs
--    (verified zero residual).
-- ============================================================
