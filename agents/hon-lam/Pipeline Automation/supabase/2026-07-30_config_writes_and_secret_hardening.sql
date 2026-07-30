-- ============================================================================
-- Settings-tab writes + secret hardening  (2026-07-30)
-- ----------------------------------------------------------------------------
-- Symptom that triggered this: the dashboard Settings tab's Save button failed
-- with 401 / 42501 "permission denied for table app_config", hint "GRANT UPDATE
-- ON public.app_config TO anon".
--
-- Root cause: 2026-07-09_hardening_and_measurement_alignment.sql's REVOKE pass
-- removed anon's column-level UPDATE grant on app_config.value. The RLS policy
-- app_config_anon_update survived, but an RLS policy is a filter applied ON TOP
-- OF a grant, not a substitute for one -- with no UPDATE grant, Postgres denies
-- the write before RLS is ever evaluated. The policy has been inert since
-- 2026-07-09, which is why rep_notification_email's updated_at still read
-- 2026-07-13 (written by a workflow, not by the dashboard).
--
-- Second bug found at the same time: the policy's allow-list never included
-- manager_report_email, so that field could not have saved even with the grant.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- (1) Restore the grant the 2026-07-09 pass removed.
--     `value` ONLY -- never `key`, so a row can never be renamed out of the
--     policy's allow-list. `updated_at` is set by the trigger in (5), so the
--     client never needs to write it.
-- ----------------------------------------------------------------------------
GRANT UPDATE (value) ON public.app_config TO anon;


-- ----------------------------------------------------------------------------
-- (2) Widen the UPDATE allow-list to every NON-SECRET key the Settings tab
--     writes. Adds manager_report_email (missing since the policy was created)
--     and ops_alert_email (new 2026-07-30, drives the Error Workflow / Pipeline
--     Heartbeat / pg_cron Failure Alert / Tool Campaign Provisioner /
--     Delivery Layer failure-alert recipients).
--     smartlead_api_key, heyreach_api_key, onboarding_code and
--     approval_hmac_secret are deliberately NOT writable from the browser --
--     they are set server-side.
-- ----------------------------------------------------------------------------
ALTER POLICY app_config_anon_update ON public.app_config
  USING (key = ANY (ARRAY[
    'tracking_base_url',
    'ga4_property_id',
    'when_engine_url',
    'rep_notification_email',
    'manager_report_email',
    'ops_alert_email',
    'approval_required_channels',
    'recommendation_expiry_days'
  ]))
  WITH CHECK (key = ANY (ARRAY[
    'tracking_base_url',
    'ga4_property_id',
    'when_engine_url',
    'rep_notification_email',
    'manager_report_email',
    'ops_alert_email',
    'approval_required_channels',
    'recommendation_expiry_days'
  ]));


-- ----------------------------------------------------------------------------
-- (3) Stop the browser reading secret VALUES. Previously app_config_read_public
--     excluded only approval_hmac_secret, so smartlead_api_key,
--     heyreach_api_key and onboarding_code were readable by anyone holding the
--     publishable key -- which is embedded in pipeline-control-tower-shared.html.
--     Both API keys happen to be empty strings today, so nothing was exposed
--     yet; this closes it before one is set.
-- ----------------------------------------------------------------------------
ALTER POLICY app_config_read_public ON public.app_config
  USING (key <> ALL (ARRAY[
    'approval_hmac_secret',
    'smartlead_api_key',
    'heyreach_api_key',
    'onboarding_code'
  ]));


-- ----------------------------------------------------------------------------
-- (4) The Settings tab still needs to render "configured" / "not set" badges
--     for those keys. Expose the BOOLEAN only, never the value.
--     Left as a default (non-security_invoker) view on purpose: it must run
--     with the owner's privileges to see past the RLS policy in (3). Safe here
--     because the projection cannot leak the value -- only its emptiness.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.app_config_secret_status AS
SELECT key,
       (coalesce(value, '') <> '') AS is_set
FROM public.app_config
WHERE key = ANY (ARRAY[
  'approval_hmac_secret',
  'smartlead_api_key',
  'heyreach_api_key',
  'onboarding_code'
]);

REVOKE ALL ON public.app_config_secret_status FROM anon, authenticated;
GRANT SELECT ON public.app_config_secret_status TO anon, authenticated;


-- ----------------------------------------------------------------------------
-- (5) Make updated_at meaningful. It only had a column DEFAULT, which fires on
--     INSERT, so config edits never bumped it and there was no audit trail.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.app_config_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $fn$
BEGIN
  NEW.updated_at = pg_catalog.now();
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS app_config_set_updated_at ON public.app_config;
CREATE TRIGGER app_config_set_updated_at
  BEFORE UPDATE ON public.app_config
  FOR EACH ROW
  EXECUTE FUNCTION public.app_config_touch_updated_at();


-- ----------------------------------------------------------------------------
-- (6) Re-apply the default-privileges fix. 2026-07-09 recorded this as done,
--     but pg_default_acl on 2026-07-30 still showed
--     anon=arwdDxtm / authenticated=arwdDxtm on future TABLES in schema public
--     for BOTH the postgres and supabase_admin owner rules -- so any new table
--     or view still came up fully anon-writable. The 2026-07-09 file only
--     covered the postgres rule; the supabase_admin rule was never touched,
--     and tables created through the Supabase dashboard are owned by it.
--
--     Consequence to remember: new views now need an explicit
--     `GRANT SELECT ON <view> TO anon, authenticated;` -- nothing is granted
--     implicitly any more. That is the intended trade.
-- ----------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES    FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;

-- ----------------------------------------------------------------------------
-- (7) The supabase_admin default-ACL rule: IMPOSSIBLE TO CHANGE. DO NOT RETRY.
-- ----------------------------------------------------------------------------
-- The supabase_admin-owned default ACLs in schema public still carry the
-- permissive Supabase stock grants (anon=arwdDxtm, authenticated=arwdDxtm on
-- TABLES; rwU on SEQUENCES; X on FUNCTIONS). They CANNOT be revoked:
--
--   ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin ...
--     -> ERROR: 42501 permission denied to change default privileges
--
-- Attempted 2026-07-30 both via the n8n Postgres connection AND from the
-- Supabase Dashboard SQL editor -- same error from both. Reason:
--   select current_user, pg_has_role(current_user,'supabase_admin','MEMBER'), rolsuper
--     -> postgres, false, false
-- On hosted Supabase the `postgres` role is not a superuser and is not a member
-- of supabase_admin, so no role you can authenticate as may alter that rule.
-- There is no SQL fix. Do not spend time on it again.
--
-- WHY IT IS CURRENTLY HARMLESS (verified 2026-07-30):
--   * A default ACL only fires for objects created BY its owning role.
--   * All 56 relations in public (18 tables, 38 views) are owned by `postgres`
--     -- zero owned by supabase_admin. So this rule has never applied to
--     anything, which is why the historical anon leaks all traced to the
--     `postgres` rule (now fixed in step 6).
--   * anon and authenticated hold ZERO non-SELECT privileges anywhere in
--     public right now:
--       select table_name, grantee, privilege_type
--       from information_schema.role_table_grants
--       where table_schema='public' and grantee in ('anon','authenticated')
--         and privilege_type <> 'SELECT';
--     -> 0 rows.
--
-- THE INVARIANT TO PRESERVE: create objects in public as `postgres` (the
-- Supabase SQL editor, the Table Editor, and the n8n Postgres credential all
-- connect as postgres, so this holds by default). It would only break if a
-- migration were run while acting as supabase_admin. Since the guarantee is by
-- convention rather than structural, re-run the 0-rows query above after any
-- schema change -- or automate it (see below).
--
-- Since prevention is impossible, step 8 below adds detection instead.


-- ----------------------------------------------------------------------------
-- (8) Compensating control for step 7: a daily assertion that RAISEs the moment
--     anon/authenticated gain a non-SELECT privilege in schema public.
--
--     Wiring, entirely out of parts that already exist: a RAISE marks the
--     pg_cron run status='failed'; the `pg_cron Failure Alert` n8n workflow
--     (daily 08:15 UTC) already sweeps cron.job_run_details for failures in the
--     last 24h, logs each to pipeline_errors (phase 'pg-cron', idempotent) and
--     emails app_config.ops_alert_email. So no new alerting plumbing is needed.
--
--     The remediation text is deliberately inside the exception MESSAGE, not in
--     a USING HINT -- pg_cron records the hint in a field the alert email does
--     not print, so anything load-bearing has to live in the message.
--
--     Scheduled 07:45 UTC: after objective-status-daily (07:30) and comfortably
--     before the 08:15 sweep, so a leak is reported the same morning.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assert_no_anon_writes()
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $fn$
DECLARE
  n int;
  offenders text;
BEGIN
  SELECT count(*), string_agg(t.entry, ', ' ORDER BY t.entry)
    INTO n, offenders
  FROM (
    SELECT DISTINCT g.grantee::text || ' has ' || g.privilege_type::text || ' on ' || g.table_name::text AS entry
    FROM information_schema.role_table_grants g
    WHERE g.table_schema = 'public'
      AND g.grantee::text IN ('anon', 'authenticated')
      AND g.privilege_type::text <> 'SELECT'
  ) t;

  IF n > 0 THEN
    RAISE EXCEPTION 'GRANT LEAK: anon/authenticated hold % non-SELECT privilege(s) in schema public: %. Fix: REVOKE those privileges explicitly (a new object was probably created as supabase_admin, whose default ACL cannot be revoked on hosted Supabase). See supabase/2026-07-30_config_writes_and_secret_hardening.sql step 7.', n, offenders;
  END IF;
END;
$fn$;

SELECT cron.unschedule('anon-write-grants-assert')
  WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'anon-write-grants-assert');

SELECT cron.schedule('anon-write-grants-assert', '45 7 * * *', 'select public.assert_no_anon_writes();');

-- Verified end-to-end 2026-07-30, not just written: a scratch table was created
-- with `grant update ... to anon`, a one-off pg_cron job was scheduled two
-- minutes out, and cron.job_run_details recorded status='failed' with
--   ERROR:  GRANT LEAK: anon/authenticated hold 1 non-SELECT privilege(s) in
--   schema public: anon has UPDATE on _grant_assert_e2e. Fix: REVOKE those
--   privileges explicitly (...). See supabase/2026-07-30_...sql step 7.
-- The scratch table, the temporary job and that failed-run row were all removed
-- afterwards (the row was pruned so the 08:15 sweep would not send a false
-- alert). Assertion passes against the current clean state.
--
-- To run it by hand at any time:  select public.assert_no_anon_writes();
-- Silence = clean. It raises only when there is something to fix.
