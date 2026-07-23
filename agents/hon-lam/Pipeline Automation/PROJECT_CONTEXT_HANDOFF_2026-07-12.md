# Intelligent Automation Pipeline — Project Context & Progress Handoff

> **Purpose:** Paste/attach at the start of a new chat in the "DP Project" folder to transfer full context.
> **Snapshot:** 2026-07-12. Supersedes the 2026-07-08 handoff.
> **Caveat:** Point-in-time summary. Verify live (n8n `get_workflow_details`, Supabase queries) and `PROJECT_AUDIT.md` before asserting anything as current. Local `n8n-workflows/*.json` exports were regenerated 2026-07-12 (current as of that date, will drift again).

---

## 1. What it is
**Intelligent Automation Pipeline** — a B2B lead pipeline in the `dp-repo` folder (OneDrive-synced; **not a git repo**). An internship **prototype/demo** on **personal accounts**. Pre-traffic, but now **hybrid multi-tenant** and much closer to turnkey.

**End-to-end flow:** WHEN-layer account briefs POST in → scored → AI sales brief, human-approved (17s approval incl. AI channel plan) → campaign + funnel-staged limited objective + tracked actions/cadence steps, **client-tagged via DB triggers** → outreach drafts generated in seconds (inline Draft Generator) → rep works a daily digest (can reply "done all"), gets ready-to-send Gmail drafts, AI-triaged replies, pre-meeting prep sheets, stale-touch nudges → outcomes measured daily (GA4/Gmail/Calendly/Salesforce read-back/LinkedIn+email feeders, race-safe dedup) → Adaptive Decision Engine stops/pauses/escalates → objectives auto-flip met/missed (pg_cron) → goal-met offers a sandbox Salesforce Opportunity (human-gated) → Friday Weekly Wins report to the manager. Email channel can go **zero-touch via Smartlead** once an API key is pasted.

## 2. Platforms & key IDs (all personal accounts — re-home is still blocker #1)
| Platform | Detail |
|---|---|
| n8n cloud | `designprodigy.app.n8n.cloud` · ~33 active workflows |
| Supabase | project `fqsqoxsosavjhdsvfevk` — source of truth. 18 tables / 36 views / 6 functions / 5 triggers / 1 pg_cron job |
| Salesforce | sandbox cred "Salesforce account 2" `HPnx6HXN8COY4aOe` ONLY. Never `hhgpLMFIO8Wl2Ykr` (real org) |
| GA4 | config still Hon Lam's property `542471069`; DP property `399321337` pending service-account grant → then swap |
| Credentials | OpenAI `dJxyXpOYQSqrDm62` · Postgres `eR1uo2QGR2ZzwysA` · Gmail `vKMX1dZQWsi80BVz` · Google SA `y2gRhCm6qQpZSW4d` · n8n API "Header Auth account" `Qx7RDnpySVz6G8xw` · AWS `YlVhiOWkge9JZ2m7` |

## 3. app_config live state (2026-07-12)
`tracking_base_url=http://www.dp.sg` (consider https) · `ga4_property_id=542471069` · `rep_notification_email=chiahonlam.school@gmail.com` (LIVE — rep emails now send) · `manager_report_email=chiahonlam.school@gmail.com` · `default_client_id=1` ("Design Prodigy (house)") · `when_engine_url` BLANK (WHEN feedback dormant) · `smartlead_api_key`/`heyreach_api_key` BLANK (zero-touch email + LinkedIn capture dormant) · `onboarding_code`/`approval_hmac_secret` set · `approval_required_channels=phone,partner` · `recommendation_expiry_days=7`.

## 4. Major subsystems (see PROJECT_AUDIT.md for the full dated narrative)
- **Core pipeline** (Delivery Layer → Brief/Action/Opportunity approval handlers, HMAC everywhere, idempotency-guarded). Brief approval was broken by the gate1 trim + a 10-min AI timeout — both **fixed + E2E-verified 2026-07-09** (mock lead: 17s, used_ai:true).
- **Hybrid multi-tenancy (2026-07-10):** `clients` registry + `client_id` on runs/campaigns/actions/events, inherited via 4 BEFORE-INSERT triggers (zero workflow-query changes); per-client rep routing in Action Approval; `dashboard_client_overview`; Client Onboarding webhook + `dashboards/onboarding.html` form (setup-code gated). Digest still global (per-client digests = next step when a 2nd real client exists).
- **Rep-laziness suite (2026-07-11, all 6 shipped):** ready-to-send Gmail drafts on approval · Reply Triage (hourly AI classify + suggested response + draft reply; anti-hallucination HARD RULES) · Digest Reply Logger ("done 1 3 / skip 2 / done all") · Pre-Meeting Prep (45-min-ahead prep sheet) · Stale Touch Nudge (daily) · Weekly Wins Report (Fri 09:00 SGT) · Smartlead auto-enroll (Tool Campaign Provisioner: creates campaign+webhook+sequence+lead+START; dormant until API key; **⚠ double-send policy**: once Smartlead sends, reps must stop sending the Gmail drafts for email actions).
- **Measurement:** GA4/Calendly/Gmail/SF read-back + LinkedIn feeder (HeyReach-ready) + Email feeder (Smartlead-ready, `email_reply` counts toward objectives) — both feeders have **partial unique indexes + ON CONFLICT** (race-proven). Quick-log + generic ingest for manual events.
- **MMM track:** foundation + objective auto-create + daily pg_cron status job + success-events aligned (incl. `email_reply`, `linkedin_reply` etc.) + `objective_status` on the matrix view + **regression scaffold ready** (`mmm/mmm_regression.py`, demo-verified) + MMM-readiness tile on both dashboards. Step 4 waits only on traffic.
- **Content:** Draft Generator (inline via `/webhook/run-draft-backfill` fired by Brief Approval; 2h Draft Backfill = safety net) + LinkedIn Post Generator/Approval (track-only).
- **Monitoring (all live):** Error Workflow attached pipeline-wide · pg_cron Failure Alert (08:15) · **Pipeline Heartbeat ACTIVE** (08:30, n8n API via "Header Auth account"; registry = `heartbeat_expected`, **maintenance rule: INSERT a row for every new workflow**).
- **Security/hardening (2026-07-09):** default-ACL root cause dropped (grants must now be explicit on every new object!) · RLS everywhere · 8 FK indexes · demo data zeroed.

## 5. Repo state (2026-07-12 — this session)
- `supabase/schema.sql` (DDL snapshot) + `supabase/setup.sql` (bootstrap + 18-template/channels/stages/heartbeat/app_config seeds, secrets blanked, clients-row note) **REGENERATED from live catalog introspection**; both parse clean (pglast, 238/243 stmts). Dated migration files document intermediate steps.
- `n8n-workflows/*.json` **re-exported 2026-07-12** — all 33 active + Error Workflow + inactive GA4 connector (34 files), via a disposable exporter workflow using the n8n API (archived after). Old stale exports deleted.
- Docs: `PROJECT_AUDIT.md` (canonical changelog) · `GO_LIVE_CHECKLIST.md` · `RE_HOME_RUNBOOK.md` · `MMM_STATUS_FOR_LEADERSHIP.md` · `WHEN_ENGINE_INTEGRATION.md` · `mmm/README.md` · `dashboards/` (control tower ×2, onboarding, quick-log).

## 6. Open items
1. **Re-home to company accounts** — #1 blocker; setup.sql/runbook now current, do it pre-traffic.
2. **GA4:** add service account to DP property `399321337`, swap `ga4_property_id`.
3. **Keys to light up dormant automation:** `smartlead_api_key` (zero-touch email; verify doc-derived API shapes on first run + mind double-send) · `heyreach_api_key`+webhooks (LinkedIn capture) · `when_engine_url` (feedback loop).
4. **Git:** dp-repo still has no version control.
5. **MMM step 4:** run `mmm/mmm_regression.py` when readiness tile fills; channel-mix EXPLORATION not yet built (without variation the regression can't learn — see brainstorm list 2026-07-12).
6. Housekeeping: archive "My workflow 2" (UI-only) · sandbox SF test campaigns/tasks residue · ZZ-TEST Gmail drafts · per-client digests when 2nd client lands.

## 7. Gotchas (hard-won — check every time)
- **n8n draft/active divergence + field-drop bug**: always re-fetch + diff draft vs active before every publish (`mode`, `operation`, `=` prefixes drop silently; recurred again 2026-07-09).
- **Credential auto-assign lies**: verify `autoAssignedCredentials` after every create/update; Salesforce = sandbox `HPnx6HXN8COY4aOe` only.
- **Grep live workflow SQL before dropping columns** (gate1 trim broke approvals for 2 days).
- **OpenAI langchain nodes**: `responsesApiEnabled:false` + explicit timeout, or risk 600s hangs.
- **Default ACL is GONE**: new tables/views get NO grants automatically — GRANT explicitly (dashboards use anon).
- **Code nodes**: always set `mode` explicitly. **Webhook feeders**: dedup via unique index + ON CONFLICT, not NOT-EXISTS (races).
- **pg_cron errors** → `cron.job_run_details` (covered by pg_cron Failure Alert, not the Error Workflow).
- OneDrive mount can serve stale files to bash right after Edit-tool writes — trust Read.
- Anthropic-side: heartbeat_expected upkeep; `honlamchia@gmail.com` literal in Cadence digest = dead code, not a leak.
