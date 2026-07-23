# Intelligent Automation Pipeline — Project Context & Progress Handoff

> **Purpose:** Paste/attach at the start of a new chat in the "DP Project" folder to transfer full context.
> **Snapshot:** 2026-07-08. Supersedes the 2026-07-05 handoff.
> **Caveat:** Point-in-time summary. Verify live (n8n `get_workflow_details`, Supabase queries) and `PROJECT_AUDIT.md` before asserting anything as current. Local `n8n-workflows/*.json` exports are **stale** — never trust them for current behavior.

---

## 1. What it is
**Intelligent Automation Pipeline** — a B2B lead pipeline in the `dp-repo` folder (OneDrive-synced; **not a git repo**). An internship **prototype/demo** on **personal accounts** — prioritize "does it work end-to-end" over hardening. Still **pre-traffic** (no real accounts have run through it).

**End-to-end flow:** WHEN-layer account briefs POST in → scored → AI-written, human-approved sales brief → approval auto-matches a campaign template + AI channel-recommender plans the sequence → creates a campaign, a **limited funnel-staged objective**, and tracked **actions**/**cadence steps** → a rep executes each touch **manually** (track-only; system drafts + tracks, never auto-sends) → outcomes measured daily (GA4 web, Gmail replies, Salesforce activity, manual quick-log, + LinkedIn/email feeders) → **Adaptive Decision Engine** stops/pauses/escalates → goal-met offers a Salesforce **Opportunity** (human-gated) → rejections/engagement feed back to the WHEN engine.

## 2. Platforms & key IDs (all under Hon Lam's personal accounts)
| Platform | Detail |
|---|---|
| n8n cloud | `designprodigy.app.n8n.cloud`, personal project |
| Supabase/Postgres | project `fqsqoxsosavjhdsvfevk` (org Hon-Lam-Chia, ap-southeast-2) — **source of truth** |
| Salesforce | **sandbox** cred "Salesforce account 2" `HPnx6HXN8COY4aOe`. NEVER the real-org cred `hhgpLMFIO8Wl2Ykr` (real company data) |
| GA4 | live config `ga4_property_id=542471069` (Hon Lam's). **DP property `399321337`** granted to Hon Lam (Viewer) 2026-07-08 — pending: add the **service account** as Viewer, then switch the config |
| AWS S3 | bucket `dp-pipeline-briefs` |
| Credentials | OpenAI `dJxyXpOYQSqrDm62`, Postgres `eR1uo2QGR2ZzwysA`, Google SA `y2gRhCm6qQpZSW4d` |

## 3. Key workflows (n8n) + the one pg_cron job
Core: Delivery Layer `HQdvWtRfLdzDTN3X` · Brief Approval `AoVkLOncTxZqQlwz` · Action Approval `UyplqAAHgTNOvRuC` · Cadence Scheduler `LcZx5U9dVmOwaGQl` · Action Outcome Measurement `RMPUPcf2o0ltJVeG` · Adaptive Decision Engine `tGYW1gMBXQrC3bQ6` · Recommendation Expiry `qYkwb4h5riveVwNJ` · Opportunity Offer `dnGpK2weiPIcikGa` · Opportunity Approval `er7QvTbfSkyc60wx` · SF Activities Read-back `mL0H9QHe73SouLsR` · SF Task Outcome Sync `PZThZtvGakw82RX8` · Digest Approve All `mw2KJ3AOea9rhSDT` · Sign Link `a8q9lmLVIxahPCTk`.
Measurement feeders: GA4 Feeder `20tIbI4ku7j35dma` · Engagement Ingest `fsPZuAbWdQb16kXm` · Calendly `VLmJHUXyuvHVXdI7` · Engagement→WHEN `grv4TN8pUrrW0xPa` · **LinkedIn `pGMO2FUg1tHpbwsR`** (`/webhook/linkedin`) · **Email Events `hAQ1e1DpFkgUBjwc`** (`/webhook/email-events`).
Content generation: **Draft Generator `2vvJUpNgJwGtLjPy`** (`/webhook/generate-draft`) · **Draft Backfill `V9Ywv5lW6eZ7qY5h`** (every 2h).
Error Workflow `rVr68buB9TD3qR5Y` (attached pipeline-wide). Non-n8n: **pg_cron `objective-status-daily`** (07:30 UTC, `update_objective_status()`) in Supabase. ~19 active workflows total.

## 4. What's built (subsystems, all additive/tested/published)
- **Core pipeline** — the flow in §1. 18 `campaign_templates`, each mapped to a funnel stage + limited objective.
- **MMM instrumentation (foundation)** — `funnel_stages`, `campaign_objectives` (auto-created per campaign by Brief Approval), `objective_id`/`funnel_stage` tags, `mmm_account_action_mix` view (the regression matrix), daily objective-status pg_cron. **Not classical MMM** — it's an account-level attribution/uplift *foundation*; the actual regression is future work **gated on real traffic volume** (and, for causal answers, randomized holdouts). See `MMM_STATUS_FOR_LEADERSHIP.md`, `supabase/2026-07-06_mmm_instrumentation.sql`.
- **Error handling** — Error Workflow attached to every active workflow (logs `pipeline_errors` + emails); retries on external nodes; SF-failure logging on all 4 Salesforce workflows; GA4 feeder fixed (was failing nightly).
- **Auto-capture measurement** — GA4/Calendly/Engagement Ingest + LinkedIn + Email feeders. The two new feeders are **dormant until DP points a real LinkedIn tool / ESP at their webhooks** (same shape as the empty `tracking_base_url`).
- **Content generation (creation, not sending)** — Draft Generator (AI writes per-touch LinkedIn/email copy from account+objective+stage context) and Draft Backfill (fills `outreach_draft` on pending cadence_steps AND recommended actions every 2h). Sending stays human/track-only by design.
- **Dashboards** — `pipeline-control-tower.html` (+ `-shared` read-only, `quick-log.html`). Settings tab now edits 6 non-secret config keys, renders `approval_required_channels` as a channel **checklist** (from `action_channels`), and shows a read-only "credentials & where they live" panel. Drafts surface in My Day (**collapsible**), Account 360, and the Cadence tab.
- **Legacy trimmed** — Gate1/Gate2 columns/tables/views + RAG/backup tables dropped (`supabase/2026-07-07_trim_gate1_legacy.sql`).

## 5. Current live data state — PRE-TRAFFIC
`engagement_events`/`outcomes` effectively empty. `app_config`: `tracking_base_url`/`when_engine_url`/`rep_notification_email` **empty** (the switches that turn on measurement + feedback); `ga4_property_id=542471069`; `approval_required_channels=phone,partner`; `recommendation_expiry_days=7`; `approval_hmac_secret` set. One **demo account left in the DB**: `DEMO -- Meridian Logistics` (campaign 37, objective 5 `met`) — safe to delete when done demoing.

## 6. Open items / next actions
1. **Get off personal accounts (re-home)** — #1 blocker. `supabase/setup.sql` (single-file DB bootstrap) + `RE_HOME_RUNBOOK.md` are ready. Do it pre-traffic (zero data migration).
2. **Go-live inputs from DP** (the client-access asks): WHEN brief feed + `when_engine_url` endpoint; a DP website w/ GA4 (`tracking_base_url`); real accounts + contact emails; a designated rep (`rep_notification_email`); a **LinkedIn automation tool** + an **ESP** to point at the feeders; the **GA4 service-account grant** on property `399321337`.
3. **Attach Error Workflow (UI only)** to the 4 newest workflows: LinkedIn feeder, Email feeder, Draft Generator, Draft Backfill.
4. **WHEN Engine integration** — hold the decision-agenda discussion in `WHEN_ENGINE_INTEGRATION.md`, then set `when_engine_url` + implement agreed contract changes.
5. **Housekeeping** — drop the root default-ACL rule; add 4 unindexed FK covering indexes; archive the inactive monolith `rNFL6JkvW5TxnaQv`; drop pgvector (unused); regenerate `supabase/schema.sql`; delete the Meridian demo rows.
6. **MMM step 4** — the actual regression, once real traffic volume exists.

## 7. Gotchas (hard-won — check every time)
- **n8n draft vs. active divergence + field-drop bug** — `update_workflow` silently drops fields (`operation`/`resource`/`=` prefixes/Code-node `mode`/trigger intervals) on *untouched* nodes; bit repeatedly this session. **Always re-fetch, diff draft vs. active, restore drops, re-diff — before every publish.** Several workflows have carried corrupted unpublished drafts.
- **Credential auto-assign** — `create_workflow_from_code`/`update_workflow` pick the wrong credential (esp. Salesforce). Re-verify after every SDK edit; SF must be the sandbox `HPnx6HXN8COY4aOe`.
- **Salesforce = sandbox only**, always.
- **Supabase default-ACL leak** — every new table/view auto-grants CRUD to anon; do `REVOKE ALL … GRANT SELECT` on each new object.
- **pg_cron job** errors show in `cron.job_run_details`, NOT the n8n Error Workflow.
- The `honlamchia@gmail.com` literal remains as **dead/unreachable code** in the Cadence digest (never sent) — not a live leak.
- Not a git repo; git ops fail on the OneDrive mount from the sandbox — run git in a local terminal. Trust the Read tool over bash right after an edit.

## 8. Canonical docs (in `dp-repo`)
`HANDOFF.md` (onboarding + access transfer) · `README.md` (architecture/setup) · `PROJECT_AUDIT.md` (dated changelog — the closest thing to git history) · `n8n-workflows/README.md` (workflow manifest + changelog) · `RE_HOME_RUNBOOK.md` (moving to company accounts) · `WHEN_ENGINE_INTEGRATION.md` · `MMM_STATUS_FOR_LEADERSHIP.md` · `supabase/setup.sql` + dated migration files. For the authoritative narrative, defer to `PROJECT_AUDIT.md` and live queries.
