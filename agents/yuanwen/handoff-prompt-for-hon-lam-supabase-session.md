# Handoff Prompt — For a Claude Session with Access to Hon Lam's Supabase

*Paste this at the start of a new session where the Supabase MCP is connected to project `ssbdlttcyogtcowvcbaj` ("Intelligent Automation Pipeline").*

---

## Context

We are working on a project called **DP Syntropy** at Design Prodigy (a B2B marketing/sales consultancy). Two people have built two separate systems that need to be understood and eventually integrated into one unified product:

**Jocelyn's system — WHEN Engine / RE:AI** (`when-layer-engine-rebuild.onrender.com`)
A marketing intelligence tool. The marketer view shows account tiles (target company logos), per-account event feeds, buying group members, and content generation with angle adjustment. It goes as far as drafting and approving outreach — but stops short of actually sending anything (e.g. the "draft email" button doesn't open a real draft in the rep's inbox). Built on Render with a Render Postgres database. We do not yet have access to Jocelyn's codebase or schema.

**Hon Lam's system — Intelligent Automation Pipeline**
A B2B lead pipeline that picks up where Jocelyn's leaves off: receives account briefs, runs human approval, creates tracked outreach campaigns, generates Gmail drafts, handles measurement, and runs an adaptive decision engine. Built on:
- **n8n** (`designprodigy.app.n8n.cloud`) — ~33 automation workflows
- **Supabase** (`ssbdlttcyogtcowvcbaj`, region ap-southeast-1) — source of truth
- **Salesforce** (sandbox), **GA4**, **Gmail**, **AWS S3**

The repo for this project is `DesignProdigySG/DP-Syntropy-May-2026`. Hon Lam's docs and workflow exports are in `agents/hon-lam/Pipeline Automation/`. The key docs to read for full context are:
- `README.md` — architecture and end-to-end flow
- `HANDOVER_OVERVIEW.md` — current state as of 2026-07-22
- `PROJECT_CONTEXT_HANDOFF_2026-07-12.md` — most detailed technical handoff
- `n8n-workflows/README.md` — all 33 workflows documented
- `supabase/schema.sql` — full DB schema

---

## Strategic direction (decided in a prior session)

The goal is **one unified product**, not two separate systems. The agreed framing:

- **Jocelyn's app becomes the front-end** — the thing reps and marketers use day-to-day
- **Hon Lam's automation becomes the back-end engine** — measurement, adaptive decisions, monitoring running underneath
- **The seam is Supabase** — Jocelyn's app writes to it when a brief is activated; Hon Lam's n8n workflows read and write to it for everything else

**What to keep from Hon Lam's system:**
- Measurement (GA4, Calendly, Gmail, LinkedIn, email feeders) — Jocelyn has nothing like this
- Adaptive Decision Engine — stop/pause/escalate logic based on lead responses
- Monitoring (pipeline heartbeat, error handling)
- The Supabase database as the tracking/measurement layer
- Reply Triage, Pre-Meeting Prep, Weekly Wins Report — useful features to surface in the unified UI

**What gives way to Jocelyn's:**
- Approval gates — Jocelyn's UI already handles this
- Rep-facing digest emails, draft generation — Jocelyn's UI does this more elegantly
- Content generation — Jocelyn's already doing this

**Hon Lam's n8n workflows likely do NOT need to be rewritten** — they're pure backend automation with no UI. The HTML dashboards (`dashboards/`) would be replaced by proper pages in the unified app.

---

## What we need from this session

You have access to Hon Lam's Supabase project `ssbdlttcyogtcowvcbaj`. Please help us understand the live database so we can plan the integration properly.

**Specific questions:**

1. **What tables exist and what's actually in them?** List all tables with row counts. We want to know what's live data vs. empty vs. demo/synthetic data.

2. **What does the schema look like for the key tables?** Specifically: `pipeline_runs`, `campaigns`, `cadence_steps`, `actions`, `outcomes`, `engagement_events`, `clients`, `campaign_objectives`, `mmm_account_action_mix`. Column names, types, and any foreign keys.

3. **What views exist?** There should be ~36. List them and briefly describe what each one does — these are what the dashboards currently read from, and understanding them tells us what reporting is already built.

4. **What's the current live state?** How many real (non-demo/non-test) pipeline runs, campaigns, and clients exist? The demo seed (`demo_seed.sql`) loads ~300 synthetic campaigns — can you tell what's real vs. synthetic?

5. **What does `app_config` contain?** This holds key configuration like `when_engine_url`, `smartlead_api_key`, `heyreach_api_key`, `tracking_base_url` etc. We want to know current values (mask any secrets).

6. **Integration readiness:** Given the schema, what would it actually take for Jocelyn's app to write a brief/activation event into this database? What's the minimum a new record needs to have to flow through the pipeline correctly?

---

## Known context to save you time

- Hon Lam's **n8n execution quota is currently over** (as of 2026-07-23) — so workflows aren't processing even if the DB looks healthy
- There are 4 real briefs waiting for approval: IDs 422–425 (Daiichi Sankyo, Fusic, SMBC, Komatsu)
- The whole stack is on **personal accounts** — re-homing to company infrastructure is the #1 blocker before real clients
- `ssbdlttcyogtcowvcbaj` is the **current** project; an older project `fqsqoxsosavjhdsvfevk` was superseded on 2026-07-13 and may still be referenced in older docs
- Salesforce integration is **sandbox only** — credential `HPnx6HXN8COY4aOe` — never the real org
