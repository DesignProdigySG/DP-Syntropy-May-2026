-- ============================================================================
-- Settings-tab config support  (APPLIED 2026-07-07)
-- Supabase migrations: action_channels_reference,
--                      app_config_allow_when_engine_url_update
-- ----------------------------------------------------------------------------
-- (a) action_channels — reference table backing the dashboard's channel checklist
--     (single source of truth for the 10 outreach channels + labels/descriptions;
--     is_high_touch mirrors the Adaptive Decision Engine's low/high-touch split).
--     Read-only to the browser: GRANT SELECT to anon/authenticated, nothing more.
-- (b) app_config RLS — widened the anon UPDATE allowlist to include when_engine_url
--     (the last non-secret config key). approval_hmac_secret stays excluded from
--     BOTH the SELECT policy (app_config_read_public) and the UPDATE policy.
--     anon retains column-level UPDATE on `value` only (never `key`).
-- ============================================================================

create table if not exists action_channels (
  key           text primary key,
  label         text not null,
  description   text,
  is_high_touch boolean not null default false,
  sort_order    int not null
);

insert into action_channels (key, label, description, is_high_touch, sort_order) values
  ('email',            'Email',                  'Direct email with a tracked link',                         false,  10),
  ('linkedin_engage',  'LinkedIn Engage',        'Like/comment on the contact''s content to warm them up',   false,  20),
  ('content_download', 'Content Download',       'Share a gated asset (guide, whitepaper) via tracked link', false,  30),
  ('landing_page',     'Landing Page',           'Send a tracked landing-page link',                         false,  40),
  ('ads',              'Ads',                    'Paid retargeting / display against the account',           false,  50),
  ('webinar',          'Webinar',                'Invite to, or follow up on, a webinar',                    false,  60),
  ('invite',           'Event / Meeting Invite', 'Direct invite to an event or meeting',                     true,   70),
  ('linkedin_connect', 'LinkedIn Connect',       'Connection request to a buying-group contact',             true,   80),
  ('phone',            'Phone Call',             'Direct outbound call',                                     true,   90),
  ('partner',          'Partner Intro',          'Warm introduction via an ecosystem partner',               true,  100)
on conflict (key) do nothing;

revoke all on action_channels from anon, authenticated;
grant  select on action_channels to anon, authenticated;

alter policy app_config_anon_update on app_config
  using      (key = any (array['tracking_base_url','ga4_property_id','rep_notification_email','approval_required_channels','recommendation_expiry_days','when_engine_url']))
  with check (key = any (array['tracking_base_url','ga4_property_id','rep_notification_email','approval_required_channels','recommendation_expiry_days','when_engine_url']));
