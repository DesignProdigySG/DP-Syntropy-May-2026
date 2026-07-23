-- ============================================================
-- DP Syntropy — demo_seed.sql — reproducible synthetic demo dataset
-- ------------------------------------------------------------
-- Seeds ~300 labeled campaigns (tagged ZZ-DEMO) with planted per-funnel-stage
-- channel effects, so the dashboards, MMM readiness, the matrix, and the MMM
-- channel-effects forest plot ALL populate WITHOUT any real traffic. This is
-- how you demo the whole pipeline on an empty, pre-traffic system.
--
-- Deterministic: campaign attributes are derived from md5(n) hashes, NOT
-- random(), so it regenerates identically on any Postgres — which means the
-- pre-computed MMM fit at the bottom always matches the data.
--
-- Idempotent + safe: clears any prior ZZ-DEMO data first, and sets states so
-- the live workflows ignore it (campaigns 'completed'+opportunity 'offered',
-- actions 'measured', objectives already resolved met/missed).
--
--   Run:      psql "$DATABASE_URL" -f supabase/demo_seed.sql
--             (or paste into the Supabase SQL editor)
--   View:     open the dashboard -> MMM tab (forest plot) + Dashboard tab
--   Teardown: supabase/demo_teardown.sql   (removes everything this created)
--   Re-fit:   python mmm/mmm_regression.py --db --db-write   (recomputes the
--             coefficients from the seeded data — should match the baked ones)
--
-- Planted truth (what the MMM fit should recover):
--   aware      -> content_download helps
--   engaged    -> linkedin_engage helps
--   qualified  -> phone (and email) help
-- ============================================================

BEGIN;

-- 1) Clear any prior demo data (idempotent) --------------------------------
DELETE FROM engagement_events   WHERE campaign LIKE 'zz-demo-%';
DELETE FROM actions             WHERE account  LIKE 'ZZ-DEMO-%';
DELETE FROM campaign_objectives WHERE campaign_id IN (SELECT id FROM campaigns WHERE account LIKE 'ZZ-DEMO-%');
DELETE FROM campaigns           WHERE account  LIKE 'ZZ-DEMO-%';
DELETE FROM mmm_channel_effects;

-- 2) Deterministic spec: 300 campaigns, hash-derived channel mixes ---------
CREATE TEMP TABLE tmp_demo_spec AS
WITH h AS (
  SELECT n,
    (('x'||substr(md5(n::text||'stage'),1,8))::bit(32)::int) & 2147483647 AS hstage,
    (('x'||substr(md5(n::text||'email'),1,8))::bit(32)::int) & 2147483647 AS hemail,
    (('x'||substr(md5(n::text||'lc'),1,8))::bit(32)::int)    & 2147483647 AS hlc,
    (('x'||substr(md5(n::text||'le'),1,8))::bit(32)::int)    & 2147483647 AS hle,
    (('x'||substr(md5(n::text||'inv'),1,8))::bit(32)::int)   & 2147483647 AS hinv,
    (('x'||substr(md5(n::text||'lp'),1,8))::bit(32)::int)    & 2147483647 AS hlp,
    (('x'||substr(md5(n::text||'cd'),1,8))::bit(32)::int)    & 2147483647 AS hcd,
    (('x'||substr(md5(n::text||'ads'),1,8))::bit(32)::int)   & 2147483647 AS hads,
    (('x'||substr(md5(n::text||'web'),1,8))::bit(32)::int)   & 2147483647 AS hweb,
    (('x'||substr(md5(n::text||'ph'),1,8))::bit(32)::int)    & 2147483647 AS hph,
    (('x'||substr(md5(n::text||'pt'),1,8))::bit(32)::int)    & 2147483647 AS hpt,
    (('x'||substr(md5(n::text||'met'),1,8))::bit(32)::int)   & 2147483647 AS hmet
  FROM generate_series(1,300) n
), b AS (
  SELECT n,
    (ARRAY['aware','engaged','qualified'])[1 + (hstage % 3)] AS stage,
    (hemail % 4) AS n_email, (hlc % 4) AS n_linkedin_connect, (hle % 5) AS n_linkedin_engage,
    (hinv % 4) AS n_invite, (hlp % 3) AS n_landing_page, (hcd % 4) AS n_content_download,
    (hads % 3) AS n_ads, (hweb % 3) AS n_webinar, (hph % 5) AS n_phone, (hpt % 3) AS n_partner,
    hmet
  FROM h
)
SELECT *,
  ((hmet % 100000)/100000.0 < (1.0/(1.0+exp(-(-1.2 + CASE stage
     WHEN 'engaged'   THEN 0.9*n_linkedin_engage + 0.2*n_email
     WHEN 'qualified' THEN 1.1*n_phone + 0.35*n_email
     ELSE 0.7*n_content_download + 0.15*n_email END))))) AS met
FROM b;

-- 3) Campaigns / objectives / actions / engagement -------------------------
--    (client_id is left to the BEFORE-INSERT tenancy triggers)
INSERT INTO campaigns(account,status,template_key,created_at,completion_reason,opportunity_status,opportunity_offered_at)
SELECT 'ZZ-DEMO-'||n,'completed',NULL, now()-interval '30 days','demo','offered', now()-interval '20 days'
FROM tmp_demo_spec;

INSERT INTO campaign_objectives(campaign_id,funnel_stage,objective_key,objective_label,success_events,target_value,window_days,status,created_at,met_at)
SELECT c.id, s.stage,'reply_or_meeting','Demo objective',
  ARRAY['meeting_booked','call_connected','crm_activity','linkedin_reply','email_reply']::text[],
  1,21, CASE WHEN s.met THEN 'met' ELSE 'missed' END,
  now()-interval '30 days', CASE WHEN s.met THEN now()-interval '20 days' ELSE NULL END
FROM tmp_demo_spec s JOIN campaigns c ON c.account='ZZ-DEMO-'||s.n;

INSERT INTO actions(account,action_type,status,executed_at,utm_campaign,campaign_id,funnel_stage,window_days,predicted_direction,channel_source)
SELECT c.account, ch.action_type,'measured', now()-interval '25 days','zz-demo-'||s.n, c.id,s.stage,14,'increase','template'
FROM tmp_demo_spec s JOIN campaigns c ON c.account='ZZ-DEMO-'||s.n
CROSS JOIN LATERAL (VALUES
  ('email',s.n_email),('linkedin_connect',s.n_linkedin_connect),('linkedin_engage',s.n_linkedin_engage),
  ('invite',s.n_invite),('landing_page',s.n_landing_page),('content_download',s.n_content_download),
  ('ads',s.n_ads),('webinar',s.n_webinar),('phone',s.n_phone),('partner',s.n_partner)
) ch(action_type,cnt) CROSS JOIN LATERAL generate_series(1,ch.cnt) g;

INSERT INTO engagement_events(account,source,event_type,campaign,value,occurred_at)
SELECT c.account,'demo','email_reply','zz-demo-'||s.n,1, now()-interval '22 days'
FROM tmp_demo_spec s JOIN campaigns c ON c.account='ZZ-DEMO-'||s.n WHERE s.met;

DROP TABLE tmp_demo_spec;

-- 4) Pre-computed MMM fit on THIS deterministic dataset --------------------
--    (fit by mmm/mmm_regression.py; re-run `--db --db-write` to regenerate)
INSERT INTO mmm_channel_effects (funnel_stage,channel,odds_ratio,ci_low,ci_high,p_value,significant,method,labeled_rows) VALUES
  ('aware','n_content_download',1.7331,1.1317,2.6541,0.01145,true,'MLE logistic',102),
  ('aware','n_email',1.2316,0.8112,1.8696,0.32817,false,'MLE logistic',102),
  ('aware','n_invite',1.0784,0.7333,1.5858,0.70145,false,'MLE logistic',102),
  ('aware','total_touches',0.9625,0.8229,1.1259,0.63307,false,'MLE logistic',102),
  ('aware','n_webinar',0.8894,0.5292,1.4949,0.65831,false,'MLE logistic',102),
  ('engaged','n_linkedin_engage',2.1383,1.3216,3.4599,0.00196,true,'MLE logistic',111),
  ('engaged','total_touches',1.1320,0.9435,1.3581,0.18225,false,'MLE logistic',111),
  ('engaged','n_content_download',0.5357,0.3115,0.9213,0.02405,true,'MLE logistic',111),
  ('qualified','n_phone',4.0165,1.9405,8.3135,0.00018,true,'MLE logistic',87),
  ('qualified','total_touches',0.8208,0.6384,1.0554,0.12373,false,'MLE logistic',87);

COMMIT;

-- Sanity check (optional):
--   SELECT funnel_stage, labeled_rows, readiness_pct FROM dashboard_mmm_readiness ORDER BY sort_order;
--   SELECT count(*) FROM campaigns WHERE account LIKE 'ZZ-DEMO-%';   -- expect 300
