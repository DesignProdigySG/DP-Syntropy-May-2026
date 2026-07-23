# Intelligent Automation Pipeline — Handover Overview

> **What this is:** the single document to read first when taking over Intelligent Automation Pipeline, and the one to present from at the internship-end handover. It consolidates the scattered handoff notes into one story and is current through the Jul 14–15 Level 2 proofs.
> **Snapshot:** 2026-07-22 (internship handover). For the full dated changelog, see `PROJECT_AUDIT.md`. Verify anything critical live (n8n `get_workflow_details`, Supabase queries) before acting on it — this is a point-in-time summary.

---

## 1. The big picture (say this first)

**Intelligent Automation Pipeline is a B2B lead pipeline that runs an account from first brief to measured outcome, with a human approving the important moments.** A lead/account brief comes in, the system scores it and writes an AI sales brief, a human approves it in seconds, and it fans out into a campaign with tracked outreach actions. A rep works those from a daily digest. Real outcomes are measured from the tools the world actually uses — Google Analytics, Calendly, Gmail, Salesforce — and an adaptive engine decides whether to keep going, pause, or escalate. When a goal is met, the system offers a sales opportunity (a human approves that too).

Two honest framings to keep repeating:

- It is a **prototype/demo built for the internship**, running on **personal accounts** — not yet a production system on company infrastructure.
- It is **pre-traffic**. It has been proven on real third-party *captures* and on a synthetic demo dataset, but not yet on live customer volume.

---

## 2. The end-to-end flow (walk this left to right)

1. **Brief in** — a WHEN-layer account brief is POSTed to the Delivery Layer webhook.
2. **Score + AI brief** — the account is scored and an AI sales brief is written (and stored to S3).
3. **Human approval** — an HMAC-signed email lets a human approve the brief in ~17 seconds; approval includes an AI channel plan.
4. **Campaign + objective** — a campaign is created from a matched template, a limited objective is auto-created (e.g. `reply_or_meeting`), and tracked actions + cadence steps are generated, all tagged to the right client by database triggers.
5. **Drafts** — outreach drafts are generated inline within seconds of approval.
6. **Rep works the digest** — a daily digest lists the rep's touches; they can reply "done all", get ready-to-send Gmail drafts, AI-triaged replies, and pre-meeting prep sheets.
7. **Measurement** — outcomes are read back daily from GA4, Calendly, Gmail, and Salesforce, plus LinkedIn/email feeders, with race-safe dedup.
8. **Adaptive decision** — the engine stops / pauses / escalates; objectives auto-flip met/missed on a schedule.
9. **Opportunity** — on a met goal, a sandbox Salesforce opportunity is offered (human-gated).
10. **Reporting** — a Friday "Weekly Wins" report goes to the manager.

---

## 3. Major subsystems (the features that matter to whoever inherits it)

- **Core pipeline + approvals** — Delivery Layer feeding Brief / Action / Opportunity approval handlers, HMAC-signed everywhere, idempotency-guarded.
- **Rep-laziness suite** — ready-to-send Gmail drafts on approval, hourly AI reply triage (with anti-hallucination rules), a digest reply logger ("done 1 3 / skip 2 / done all"), pre-meeting prep sheets, stale-touch nudges, and the weekly wins report.
- **Multi-tenancy** — a `clients` registry with `client_id` inherited via database triggers (no workflow-query changes), per-client rep routing, a client onboarding form, and a per-client dashboard overview.
- **Measurement feeders** — GA4, Calendly, Gmail, and Salesforce read-back, plus LinkedIn (HeyReach-ready) and email (Smartlead-ready) webhook feeders with unique-index dedup.
- **MMM (marketing mix model) track** — objective auto-create, a daily status job, a regression scaffold (`mmm/mmm_regression.py`), and a readiness tile on the dashboards. Waits on real traffic to become live rather than demo-only.
- **Monitoring** — an Error Workflow attached pipeline-wide, a pg_cron failure alert, and an active pipeline heartbeat.

---

## 4. Where everything physically lives (the most important handover section)

| Platform | Detail |
|---|---|
| **n8n cloud** | `designprodigy.app.n8n.cloud` — ~33 active workflows. This is the automation brain. |
| **Supabase** | project `ssbdlttcyogtcowvcbaj` ("Intelligent Automation Pipeline", region ap-southeast-1) — **source of truth**. ~18 tables / 36 views / 6 functions / 5 triggers / 1 pg_cron job. (Superseded the older `fqsqoxsosavjhdsvfevk` ref on 2026-07-13 — older handoff docs still cite the old one.) |
| **Salesforce** | sandbox credential "Salesforce account 2" (`HPnx6HXN8COY4aOe`) **only** — never the real org. |
| **GA4** | property `399321337` (DP) is now the one the feeder reads (swapped during the Level 2 GA4 proof); Hon Lam's old property was `542471069`. |
| **Dashboards** | control-tower dashboards (×2), onboarding form, quick-log — in `dashboards/`. |
| **Repo** | `dp-repo` (OneDrive-synced). `supabase/` holds schema + bootstrap SQL; `n8n-workflows/` holds JSON exports (can drift — trust the live workflows). |

**Everything is on personal accounts.** Re-homing to company accounts is the number-one thing the next owner must do.

---

## 5. Proof of what works (the credibility story)

The system has been proven in layers, each documented in its own file:

- **Level 1 — full loop on the live system** (`LEVEL1_PROOF_2026-07-13.md`): every stage from brief → approval → campaign → measurement → adaptive decision → opportunity offered, run on the live published workflows with one synthetic account. ~9 minutes wall-clock. Only compression was backdating three timestamps so the measurement window had elapsed.
- **Level 2 — real third-party capture:**
  - **GA4** (`LEVEL2_PROOF_GA4.md`): a real browser visit flowed through Google's own servers and was read back autonomously by the live feeder as a `page_visit` event. The strongest form of capture — the system pulled it on its own schedule.
  - **Calendly** (`LEVEL2_PROOF_CALENDLY.md`): a real Calendly booking drove the full loop to opportunity-offered. Honest caveat: the event was *replayed* into the live receiver rather than pushed by Calendly's servers (one webhook-subscription step from fully autonomous).
- **Demo mode** (`DEMO_MODE.md`): `supabase/demo_seed.sql` loads ~300 synthetic labeled campaigns so the dashboards and the MMM forest plot light up for a walkthrough at any time. Always say it's synthetic.

**Remaining to fully close Level 2:** the ESP (Smartlead) webhook source. **Level 3** would be one real account with live traffic and sign-off.

---

## 6. What the next owner must do first

1. **Re-home off personal accounts onto company infrastructure** — the #1 blocker, and it should happen while still pre-traffic. A runbook exists: `RE_HOME_RUNBOOK.md`. The `supabase/setup.sql` bootstrap is current for standing up a fresh instance.
2. **Finish the GA4 grant** — service account is on the DP property; confirm the `ga4_property_id` swap is the intended final state.
3. **Paste the dormant API keys to light up automation** — `smartlead_api_key` (zero-touch email + closes the last Level 2 source), `heyreach_api_key` (LinkedIn capture), `when_engine_url` (the closed-loop feedback back to the rebuilt **RE:AI / WHEN Layer** engine at `when-layer-engine-rebuild.onrender.com` — still needs that engine's feedback *endpoint* before it can be set; see `WHEN_ENGINE_INTEGRATION.md`). All are wired and waiting.
4. **Put `dp-repo` under version control** — it currently has none.
5. **MMM step 4** — run the regression once real traffic gives the readiness tile enough labeled rows. Channel-mix *exploration* (randomizing channels so the model can learn causally) is now **built**: the ε-greedy hook sits in the Brief Approval Handler draft (publish it + set `channel_explore_enabled='true'` to activate), and the causal analysis path (`mmm/mmm_regression.py --explore-only`, the `mmm_account_action_mix_explore` view, and the dashboard readout) is live. See `mmm/CHANNEL_EXPLORATION_DESIGN.md`.

---

## 7. Where the documentation lives

- **`PROJECT_AUDIT.md`** — the canonical, dated changelog. The definitive record; read this for "why is it like this."
- **`RE_HOME_RUNBOOK.md`** — step-by-step for moving off personal accounts.
- **`GO_LIVE_CHECKLIST.md`** — pre-traffic checklist.
- **`LEVEL1_PROOF_*` / `LEVEL2_PROOF_*`** — the proof trails above, each verifiable in n8n executions + Supabase.
- **`DEMO_MODE.md`** — how to light up the dashboards for a walkthrough.
- **`MMM_STATUS_FOR_LEADERSHIP.md`** and **`mmm/README.md`** — the model track.
- **`WHEN_ENGINE_INTEGRATION.md`** — the upstream WHEN-layer integration.

---

## 8. Gotchas worth handing over (hard-won)

- **n8n draft vs. active divergence** — always re-fetch and diff a workflow's draft against its active version before publishing; parameters can drop silently.
- **Credential auto-assign lies** — verify the assigned credential after every workflow create/update. Salesforce must be the sandbox (`HPnx6HXN8COY4aOe`).
- **No default database grants** — new Supabase tables/views get no permissions automatically; grant them explicitly (dashboards read as `anon`).
- **Code nodes** — always set `mode` explicitly, or only the first input item is processed.
- **Webhook feeders** — dedup with a unique index + `ON CONFLICT`, not a NOT-EXISTS check (which races).
- **pg_cron errors** surface in `cron.job_run_details`, not the Error Workflow.
- **OneDrive mount** can serve stale files right after an edit — trust the editor's view over a shell read.
