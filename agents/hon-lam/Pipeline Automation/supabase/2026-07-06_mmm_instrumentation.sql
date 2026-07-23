-- ============================================================================
-- MMM INSTRUMENTATION  —  PROPOSED migration (review before applying)
-- ----------------------------------------------------------------------------
-- Goal: turn every campaign into a LIMITED, funnel-staged objective, tag every
--       action with the objective it serves, and expose a regression-ready
--       per-account action-mix matrix. This is the data foundation for
--       Marketing Mix Modeling (MMM) — the "which touches actually drive the
--       objective, so we optimize the mix instead of doing more" question.
--
-- Design principle (per boss 1:1): a regression needs (1) ONE clean dependent
-- variable per campaign = the limited objective, (2) the full mix of actions as
-- independent variables, (3) each action attributed to the objective it served.
--
-- Status: additive only (new tables / columns / view — nothing dropped, no data
-- modified). Safe to apply, but it changes the source-of-truth schema, so review
-- first. Nothing here runs a model; it INSTRUMENTS so a model becomes possible
-- once real traffic exists (currently pre-traffic: engagement_events/outcomes = 0).
--
-- ACL note: the public schema has a standing default-privilege leak that
-- auto-grants CRUD to anon/authenticated on every new object. Every object
-- created below is explicitly REVOKEd then GRANTed SELECT only (section 6).
-- Project: Supabase fqsqoxsosavjhdsvfevk (public schema).   Date: 2026-07-06
-- ============================================================================


-- 1) FUNNEL STAGES  (reference table, fully customizable) ---------------------
create table if not exists funnel_stages (
  key         text primary key,
  label       text not null,
  sort_order  int  not null,
  description text
);

insert into funnel_stages (key, label, sort_order, description) values
  ('cold',        'Cold / Unaware',      10, 'No prior engagement; objective is a first micro-response ("entice the cold")'),
  ('aware',       'Aware / Early',       20, 'Low-intent, early-awareness; nurture with content'),
  ('engaged',     'Engaged',             30, 'Repeated signals; warm but not yet sales-ready'),
  ('qualified',   'Qualified / Intent',  40, 'Clear buying signal; push for reply / meeting'),
  ('opportunity', 'Opportunity',         50, 'Meeting / opportunity created; sales-led'),
  ('customer',    'Customer (expand)',   60, 'Existing customer: renewal / expansion / cross-sell')
on conflict (key) do nothing;


-- 2) MAKE THE TEMPLATE OBJECTIVE MACHINE-READABLE -----------------------------
-- Templates already have goal / kpi_metric / kpi_target(prose). Add the
-- structured fields a regression needs: stage, which events count as success,
-- a numeric target, and a window.
alter table campaign_templates
  add column if not exists funnel_stage             text references funnel_stages(key),
  add column if not exists objective_success_events text[],
  add column if not exists objective_target_value   numeric default 1,
  add column if not exists objective_window_days     int    default 21;

-- Backfill success-event mapping from the existing kpi_metric (starting point —
-- refine the reply_or_meeting bucket once real reply/meeting events are defined).
update campaign_templates set objective_success_events =
  case kpi_metric
    when 'reply_or_meeting' then array['meeting_booked','call_connected','crm_activity']
    when 'profile_visit'    then array['profile_visit']
    when 'registration'     then array['registration']
    when 'content_download' then array['content_download']
    when 'partner_response' then array['partner_response']
    else array[]::text[]
  end
where objective_success_events is null;

-- Complete funnel_stage + numeric target/window mapping for all 18 templates.
-- stage = where the account currently sits; target/window parsed from kpi_target.
update campaign_templates t set
  funnel_stage           = m.stage,
  objective_target_value = m.tgt,
  objective_window_days  = m.win
from (values
  ('cold_outreach',           'cold',      1, 21),
  ('thought_leadership',      'aware',     1, 30),
  ('narrow_coverage_nurture', 'aware',     2, 21),
  ('partner_campaign',        'aware',     1, 14),
  ('warm_reengage',           'engaged',   1, 30),
  ('dormant_account',         'engaged',   1, 21),
  ('reactivation',            'engaged',   1, 21),
  ('conference_followup',     'engaged',   1,  7),
  ('executive_event',         'engaged',   1, 21),
  ('webinar',                 'engaged',   1, 10),
  ('abm',                     'qualified', 2, 21),
  ('competitive_replacement', 'qualified', 1, 14),
  ('product_launch',          'qualified', 1, 14),
  ('urgent_fast_track',       'qualified', 1,  7),
  ('cross_sell',              'customer',  1, 21),
  ('customer_success',        'customer',  1, 14),
  ('expansion',               'customer',  1, 21),
  ('renewal',                 'customer',  1, 30)
) as m(key, stage, tgt, win)
where t.key = m.key;


-- 3) PER-CAMPAIGN LIMITED OBJECTIVE -------------------------------------------
-- One row per (campaign, funnel stage) = the LIMITED objective for that run.
-- Materialize from the template at campaign-creation, but customizable per
-- account. A campaign can hold >1 objective if it spans stages ("schedule
-- actions between objectives").
create table if not exists campaign_objectives (
  id              bigint generated always as identity primary key,
  campaign_id     bigint not null references campaigns(id) on delete cascade,
  funnel_stage    text   not null references funnel_stages(key),
  objective_key   text   not null,               -- customizable, e.g. 'namecard','first_reply','meeting'
  objective_label text,
  success_events  text[] not null default '{}',  -- engagement_events.event_type that satisfy it
  target_value    numeric not null default 1,
  window_days     int     not null default 21,
  status          text    not null default 'open',  -- open | met | missed
  baseline_value  numeric,
  created_at      timestamptz not null default now(),
  met_at          timestamptz
);
create index if not exists ix_campaign_objectives_campaign on campaign_objectives(campaign_id);


-- 4) TAG EVERY ACTION WITH THE OBJECTIVE IT SERVES ----------------------------
-- Required for attribution: the model must know which objective each touch was
-- trying to move. (Wiring: Brief Approval Handler stamps these at creation —
-- see "follow-up wiring" note at the bottom.)
alter table actions
  add column if not exists objective_id bigint references campaign_objectives(id),
  add column if not exists funnel_stage text references funnel_stages(key);
alter table cadence_steps
  add column if not exists objective_id bigint references campaign_objectives(id),
  add column if not exists funnel_stage text references funnel_stages(key);
create index if not exists ix_actions_objective        on actions(objective_id);
create index if not exists ix_cadence_steps_objective  on cadence_steps(objective_id);


-- 5) THE REGRESSION-READY MATRIX (view) ---------------------------------------
-- One row per (campaign, account, objective): the MIX of channels applied as
-- independent variables + the objective outcome as the dependent variable.
-- This is exactly what a logistic regression / MMM reads:
--     objective_met  ~  n_email + n_linkedin_* + n_phone + ... + controls
-- Empty until traffic flows, but structurally ready.
create or replace view mmm_account_action_mix as
with acts as (
  select
    a.campaign_id, a.account, a.objective_id,
    count(*) filter (where a.action_type='email')            as n_email,
    count(*) filter (where a.action_type='linkedin_connect') as n_linkedin_connect,
    count(*) filter (where a.action_type='linkedin_engage')  as n_linkedin_engage,
    count(*) filter (where a.action_type='invite')           as n_invite,
    count(*) filter (where a.action_type='landing_page')     as n_landing_page,
    count(*) filter (where a.action_type='content_download') as n_content_download,
    count(*) filter (where a.action_type='ads')              as n_ads,
    count(*) filter (where a.action_type='webinar')          as n_webinar,
    count(*) filter (where a.action_type='phone')            as n_phone,
    count(*) filter (where a.action_type='partner')          as n_partner,
    count(*)                          as total_touches,
    count(distinct a.action_type)     as distinct_channels,
    min(a.executed_at)                as first_touch_at,
    max(a.executed_at)                as last_touch_at
  from actions a
  where a.status in ('executed','measured')
  group by a.campaign_id, a.account, a.objective_id
)
select
  m.campaign_id,
  m.account,
  m.objective_id,
  o.funnel_stage,
  o.objective_key,
  c.template_key,
  -- independent variables (the mix)
  m.n_email, m.n_linkedin_connect, m.n_linkedin_engage, m.n_invite,
  m.n_landing_page, m.n_content_download, m.n_ads, m.n_webinar,
  m.n_phone, m.n_partner,
  m.total_touches, m.distinct_channels,
  round((extract(epoch from (m.last_touch_at - m.first_touch_at)) / 86400.0)::numeric, 2) as touch_span_days,
  -- engagement-intensity controls (hard = observed, soft = self-reported)
  s.hard_points, s.soft_points,
  -- dependent variable (label)
  coalesce(o.status = 'met', false) as objective_met,
  o.target_value,
  o.window_days
from acts m
join campaigns c            on c.id = m.campaign_id
left join campaign_objectives o on o.id = m.objective_id
left join account_score s   on s.account = m.account;


-- 6) LOCK DOWN ACLs (default-privilege leak workaround) -----------------------
revoke all on funnel_stages        from anon, authenticated;
revoke all on campaign_objectives  from anon, authenticated;
revoke all on mmm_account_action_mix from anon, authenticated;
grant  select on funnel_stages         to anon, authenticated;
grant  select on campaign_objectives   to anon, authenticated;
grant  select on mmm_account_action_mix to anon, authenticated;


-- ============================================================================
-- FOLLOW-UP WIRING (not schema — n8n changes, do after this migration)
-- ----------------------------------------------------------------------------
-- 1. Brief Approval Handler: when it inserts a campaign, also INSERT one
--    campaign_objectives row from the chosen template (funnel_stage,
--    objective_success_events, objective_target_value, objective_window_days),
--    then stamp objective_id + funnel_stage on every action / cadence_step it
--    creates for that campaign.
-- 2. A small daily job (or extend Adaptive Decision Engine): flip
--    campaign_objectives.status to 'met' when a success_events engagement fires
--    within window (set met_at), else 'missed' at window end. This populates the
--    dependent variable the matrix reads.
-- 3. Once N is large enough (needs volume + variance — this is the "nirvana"
--    caveat): pull mmm_account_action_mix into Python and fit a logistic
--    regression (objective_met ~ channel mix + controls). The coefficients tell
--    the Channel Recommendation AI which touches actually move each objective,
--    per funnel stage — replacing today's heuristic leaderboard with evidence.
-- ============================================================================


-- ============================================================================
-- STEP 2 APPLIED 2026-07-07 — objective creation wired + view re-pointed
-- ----------------------------------------------------------------------------
-- (a) Brief Approval Handler (n8n AoVkLOncTxZqQlwz) gained a "Create Campaign
--     Objective" Postgres node hanging off "Insert Campaign" (additive; onError
--     continueRegularOutput; idempotent via NOT EXISTS). It runs, per new
--     campaign, effectively:
--       INSERT INTO campaign_objectives
--         (campaign_id, funnel_stage, objective_key, objective_label,
--          success_events, target_value, window_days)
--       SELECT <new campaign id>, t.funnel_stage, coalesce(t.kpi_metric,t.key),
--              t.name, coalesce(t.objective_success_events,'{}'::text[]),
--              coalesce(t.objective_target_value,1),
--              coalesce(t.objective_window_days,21)
--       FROM campaign_templates t
--       WHERE t.key = <matched template key> AND t.funnel_stage IS NOT NULL
--         AND NOT EXISTS (SELECT 1 FROM campaign_objectives o
--                         WHERE o.campaign_id = <new campaign id>);
--     So every future campaign auto-creates its limited, funnel-staged objective.
--
-- (b) mmm_account_action_mix re-pointed to derive the objective by CAMPAIGN_ID
--     (v1 = one objective per campaign), so per-action objective_id tagging is
--     NOT required yet. The actions/cadence_steps.objective_id columns remain
--     for a future multi-objective-per-campaign model; switch the view's join
--     back to objective_id when that arrives. Applied as migration
--     'mmm_view_campaign_join'. Final join:
--         left join campaign_objectives o on o.campaign_id = m.campaign_id
--
-- ============================================================================
-- STEP 3 APPLIED 2026-07-07 — objective-status daily job (pg_cron)
-- ----------------------------------------------------------------------------
-- The label the matrix reads (objective_met) is populated by a daily pg_cron job
-- (migration 'objective_status_daily_job'). It's the ONE non-n8n scheduled job
-- in the pipeline — pure SQL, so it lives in the DB next to the objectives.
-- Note: errors surface via cron.job_run_details, NOT the n8n Error Workflow.
--
--   create extension if not exists pg_cron;
--   create function public.update_objective_status() ...  -- MET then MISSED
--   cron.schedule('objective-status-daily','30 7 * * *',
--                 $$ select public.update_objective_status(); $$);
--
-- MET rule: an open objective flips to 'met' (met_at=now) if a success event
--   (event_type = ANY success_events) for the campaign's account occurred within
--   [created_at, created_at + window_days], attributed to the campaign via
--   engagement_events.action_id -> actions.campaign_id OR e.campaign = actions.utm_campaign.
-- MISSED rule: open objectives whose window has fully closed with no success.
-- Validated live with disposable met/missed campaigns (flipped correctly), then cleaned up.
-- Inspect runs:  select * from cron.job_run_details where jobid=(select jobid from cron.job where jobname='objective-status-daily') order by start_time desc;
--
-- MMM TRACK REMAINING: step 4 = pull mmm_account_action_mix into Python, fit a
-- logistic regression (objective_met ~ channel mix + controls per stage), feed
-- coefficients back to the Channel Recommendation AI. Gated on real traffic volume.
-- ============================================================================
