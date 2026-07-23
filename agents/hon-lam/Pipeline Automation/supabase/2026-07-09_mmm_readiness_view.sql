-- 2026-07-09 — MMM readiness view + objective_status on the matrix
-- Applied live via Supabase MCP migration `mmm_readiness_and_status_column`.
--
-- 1. mmm_account_action_mix: appended `o.status AS objective_status` as the
--    last column (additive; CREATE OR REPLACE VIEW with same leading columns).
--    Needed so MMM training can EXCLUDE open objectives — the existing
--    objective_met uses COALESCE(status='met', false), which makes an OPEN
--    objective indistinguishable from a MISSED one and would poison the label.
--    (Full view definition lives in the migration history; only the new
--    column differs from the 2026-07-06/07 definition.)
--
-- 2. New view `dashboard_mmm_readiness` — per-funnel-stage training-data
--    progress for the dashboards' "MMM readiness" tile:

CREATE VIEW public.dashboard_mmm_readiness AS
WITH chan AS (
  SELECT o.funnel_stage, count(DISTINCT a.action_type) AS channels_used
  FROM campaign_objectives o
  JOIN actions a ON a.campaign_id = o.campaign_id
   AND a.status = ANY (ARRAY['executed','measured'])
  GROUP BY o.funnel_stage
)
SELECT
  fs.key AS funnel_stage,
  fs.label,
  fs.sort_order,
  count(o.status) AS objectives_total,
  count(*) FILTER (WHERE o.status = 'met') AS met,
  count(*) FILTER (WHERE o.status = 'missed') AS missed,
  count(*) FILTER (WHERE o.status = 'open') AS open,
  count(*) FILTER (WHERE o.status IN ('met','missed')) AS labeled_rows,
  COALESCE(max(chan.channels_used), 0) AS channels_used,
  greatest(30, 10 * COALESCE(max(chan.channels_used), 0)) AS target_rows,
  least(100, round(100.0 * count(*) FILTER (WHERE o.status IN ('met','missed'))
        / greatest(30, 10 * COALESCE(max(chan.channels_used), 0)))) AS readiness_pct
FROM funnel_stages fs
LEFT JOIN campaign_objectives o ON o.funnel_stage = fs.key
LEFT JOIN chan ON chan.funnel_stage = fs.key
GROUP BY fs.key, fs.label, fs.sort_order;

-- 3. Grants — explicit now that the default-ACL rule is gone (2026-07-09):
REVOKE ALL ON public.dashboard_mmm_readiness FROM anon, authenticated, PUBLIC;
GRANT SELECT ON public.dashboard_mmm_readiness TO anon, authenticated;

-- target_rows rationale: EPV heuristic — 10 labeled (met/missed) rows per
-- channel predictor actually used at that stage, floor 30. Mirrors the gate
-- in mmm/mmm_regression.py so the dashboard and the model agree on "ready".
