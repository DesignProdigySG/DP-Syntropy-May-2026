-- ============================================================================
-- TRIM: remove Gate1/Gate2-era legacy from Supabase  (APPLIED 2026-07-07)
-- Migration name in Supabase: trim_gate1_legacy_cleanup
-- Scope chosen: A + B (dead weight + Gate1/Gate2 columns). C (drop pgvector
-- extension) was NOT done — the vector_*/halfvec_* functions remain.
-- ----------------------------------------------------------------------------
-- Verified before dropping: no view/dashboard/trigger depended on any removed
-- object except dashboard_kpis (which used gate1_result/gate2_result for tallies
-- the dashboard front-end never consumed — it was slimmed, not broken).
--
-- DROPPED
--   Tables:   pipeline_runs_bak, pipeline_errors_bak, agent_inputs, agent_inputs_bak,
--             documents, sc_ai_audit_log
--   Function: match_documents()  (RAG, referenced documents)
--   Views:    dashboard_gate1_breakdown, dashboard_vetoed_companies
--   Columns (pipeline_runs): gate1_score, gate1_threshold, gate1_confidence,
--             gate1_rationale, gate1_vetoed, gate1_veto_reason, gate1_result,
--             gate2_result
--   View slimmed: dashboard_kpis  -> now {total, briefs_generated, approved}
--                 (dropped gate1_pass/gate1_vetoed/gate2_pass/mismatch tallies)
--
-- PRESERVED
--   pipeline_runs_gate1_archive  (id + the 8 Gate1/Gate2 cols, 402 rows) — a
--   safety snapshot; DROP TABLE pipeline_runs_gate1_archive; whenever confirmed
--   unneeded.
--
-- KEPT (not legacy): sync_cadence_step_status() trigger on actions, and all
--   in-use dashboard_*/console_*/feedback_* views.
--
-- Result: base tables 18 -> 13, views 36 -> 34.
-- NOTE: supabase/schema.sql is now stale w.r.t. these drops — re-sync when convenient.
-- ============================================================================
-- (Statements below are a record of what was applied via apply_migration.)

create table if not exists pipeline_runs_gate1_archive as
  select id, gate1_score, gate1_threshold, gate1_confidence, gate1_rationale,
         gate1_vetoed, gate1_veto_reason, gate1_result, gate2_result
  from pipeline_runs;
revoke all on pipeline_runs_gate1_archive from anon, authenticated;

drop view if exists dashboard_gate1_breakdown;
drop view if exists dashboard_vetoed_companies;
drop view if exists dashboard_kpis;

create view dashboard_kpis as
  select count(*)                                as total,
         count(*) filter (where brief_generated) as briefs_generated,
         count(*) filter (where human_approved)  as approved
  from pipeline_runs;
revoke all on dashboard_kpis from anon, authenticated;
grant  select on dashboard_kpis to anon, authenticated;

alter table pipeline_runs
  drop column if exists gate1_score,
  drop column if exists gate1_threshold,
  drop column if exists gate1_confidence,
  drop column if exists gate1_rationale,
  drop column if exists gate1_vetoed,
  drop column if exists gate1_veto_reason,
  drop column if exists gate1_result,
  drop column if exists gate2_result;

drop function if exists match_documents cascade;
drop table if exists documents;
drop table if exists agent_inputs;
drop table if exists agent_inputs_bak;
drop table if exists pipeline_runs_bak;
drop table if exists pipeline_errors_bak;
drop table if exists sc_ai_audit_log;
