-- 2026-07-22 — Explore-only MMM matrix (Phase 3 of channel-mix exploration)
-- Applied live via Supabase MCP migration `mmm_account_action_mix_explore`.
--
-- Companion to mmm_account_action_mix: identical grain (one row per
-- campaign/account/objective) and columns, but the channel-mix counts include
-- ONLY randomized exploration touches (actions.channel_source = 'explore').
-- Because those channels were assigned at random, a logistic fit on this view
-- is an UNCONFOUNDED (causal) estimate of channel effect — the thing the
-- all-rows fit can't give (reps/AI choose channels non-randomly). Read by
-- `python mmm/mmm_regression.py --explore-only --db`.
--
-- Mirrors the live definition of mmm_account_action_mix exactly (incl. the
-- objective_status column added 2026-07-09); the ONLY difference is the added
-- `AND a.channel_source = 'explore'` filter in the acts CTE.

CREATE OR REPLACE VIEW public.mmm_account_action_mix_explore AS
 WITH acts AS (
   SELECT a.campaign_id,
          a.account,
          count(*) FILTER (WHERE a.action_type = 'email'::text)            AS n_email,
          count(*) FILTER (WHERE a.action_type = 'linkedin_connect'::text) AS n_linkedin_connect,
          count(*) FILTER (WHERE a.action_type = 'linkedin_engage'::text)  AS n_linkedin_engage,
          count(*) FILTER (WHERE a.action_type = 'invite'::text)           AS n_invite,
          count(*) FILTER (WHERE a.action_type = 'landing_page'::text)     AS n_landing_page,
          count(*) FILTER (WHERE a.action_type = 'content_download'::text) AS n_content_download,
          count(*) FILTER (WHERE a.action_type = 'ads'::text)              AS n_ads,
          count(*) FILTER (WHERE a.action_type = 'webinar'::text)          AS n_webinar,
          count(*) FILTER (WHERE a.action_type = 'phone'::text)            AS n_phone,
          count(*) FILTER (WHERE a.action_type = 'partner'::text)          AS n_partner,
          count(*)                        AS total_touches,
          count(DISTINCT a.action_type)   AS distinct_channels,
          min(a.executed_at)              AS first_touch_at,
          max(a.executed_at)              AS last_touch_at
     FROM actions a
    WHERE a.status = ANY (ARRAY['executed'::text, 'measured'::text])
      AND a.channel_source = 'explore'::text
    GROUP BY a.campaign_id, a.account
 )
 SELECT m.campaign_id,
        m.account,
        o.id AS objective_id,
        o.funnel_stage,
        o.objective_key,
        c.template_key,
        m.n_email, m.n_linkedin_connect, m.n_linkedin_engage, m.n_invite,
        m.n_landing_page, m.n_content_download, m.n_ads, m.n_webinar,
        m.n_phone, m.n_partner,
        m.total_touches, m.distinct_channels,
        round(EXTRACT(epoch FROM m.last_touch_at - m.first_touch_at) / 86400.0, 2) AS touch_span_days,
        s.hard_points, s.soft_points,
        COALESCE(o.status = 'met'::text, false) AS objective_met,
        o.target_value, o.window_days,
        o.status AS objective_status
   FROM acts m
   JOIN campaigns c              ON c.id = m.campaign_id
   LEFT JOIN campaign_objectives o ON o.campaign_id = m.campaign_id
   LEFT JOIN account_score s     ON s.account = m.account;

-- Explicit grants (default-ACL leak workaround; default privileges are OFF).
REVOKE ALL ON public.mmm_account_action_mix_explore FROM anon, authenticated, PUBLIC;
GRANT SELECT ON public.mmm_account_action_mix_explore TO anon, authenticated;
