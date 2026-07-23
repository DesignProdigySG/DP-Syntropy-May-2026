# Intelligent Automation Pipeline — Handoff Guide

For someone picking up this project who wasn't in the room for any of it. Read this first, then `README.md` (architecture/setup) and `PROJECT_AUDIT.md` (full history of decisions, bugs found/fixed, and what's still open).

## What this project is

A B2B lead pipeline: WHEN-layer account briefs come in → get turned into human-approved sales briefs and tracked outreach actions → every action is measured against a hypothesis. Five platforms, no single login covers all of them:

| Platform | Role | Where |
|---|---|---|
| n8n cloud | Orchestration (ingest, brief generation, approvals, daily measurement) | designprodigy.app.n8n.cloud |
| Supabase (Postgres) | System of record — all tables/views | project `fqsqoxsosavjhdsvfevk`, org "Hon-Lam-Chia" |
| Salesforce | One-way synced execution layer (prototype) | org tied to the n8n "Salesforce account" credential |
| GA4 + Gmail | Outcome measurement (web visits / email replies) | GA4 property + `honlamchia@gmail.com` |
| AWS S3 | Generated brief HTML storage | n8n "AWS (IAM) account" credential |

**Everything currently runs under Hon Lam's personal accounts.** None of the n8n credentials live in a shared/team project yet — `list_credentials` shows all six (AWS, OpenAI, Postgres, Salesforce, Gmail, Google Service Account) under the personal n8n project `Hon Lam Chia <honlamchia@gmail.com>`. Handing this off means either (a) inviting the new person and moving these into a shared n8n project, or (b) the new person works alongside Hon Lam rather than independently. Decide which before starting the steps below.

## Things you need to know before touching anything

These cost real time to rediscover — they're already paid for once:

1. **n8n draft vs. active silently diverge.** Editing a published workflow via the SDK/MCP tools lands in the *draft*; the live webhook keeps running the old *active* version until you explicitly `publish_workflow`. This has caused real bugs three separate times in this project (lost `operation`/`resource` fields, lost `disabled` flags, lost `=` expression prefixes). **Always diff draft vs. active before publishing.**
2. **Supabase's `public` schema has a default-ACL leak.** `ALTER DEFAULT PRIVILEGES ... GRANT ALL ON TABLES TO anon, authenticated` is still active at the schema level. Every *new* table or view automatically gets full CRUD for `anon`/`authenticated` regardless of any `GRANT SELECT` you add afterward. This has bitten the project three times already (25 dashboard views, two `feedback_for_*` views, two `console_*` views). **Any new view needs an explicit `REVOKE ALL ... GRANT SELECT` pass before it's wired into a dashboard.** Removing the root cause (dropping the default-ACL rule) is still on the open list — see Priority list below.
3. **Salesforce sync is live (sandbox only).** Campaign sync (one Salesforce Campaign per approved brief) and Lead/CampaignMember sync are both **active** — the Lead sync was disabled 2026-06-28, then **re-enabled and hardened 2026-06-29** (per-contact loop, dedup, idempotency). All Salesforce nodes point at the **sandbox** credential **"Salesforce account 2"** (`HPnx6HXN8COY4aOe`) — **never** the old "Salesforce account" (`hhgpLMFIO8Wl2Ykr`), which holds a real populated CRM (that org was removed from the sync on 2026-06-26). Caveat: `buying_group` entries still have no email field, so Lead dedup is a manual SOQL name+company match, not a native upsert. `create_workflow_from_code`/`update_workflow` have repeatedly auto-assigned the wrong SF credential (8+ times) — always re-verify the binding is the sandbox one after any SF-node edit.
4. **Both dashboard HTML files embed a Supabase anon key in plaintext** (`dashboards/pipeline-control-tower.html`, `-shared.html`). Treat both as internal-only. The "-shared" copy's read-only lock is cosmetic (disabled `<input>`, not a permissions boundary) — RLS is what actually protects the data now, not the UI.
5. **This is not a git repo.** It's a OneDrive-synced folder with no version control, no commit history, and no remote. If you want change history going forward, set one up (see below) — right now the only history is what's narrated in `PROJECT_AUDIT.md`.

## Transferring access, platform by platform

### 1. Project files (this folder)

Right-click the `dp-repo` folder in OneDrive (or use the OneDrive web app) → **Share** → enter the other person's email, grant Edit or View. They'll see live updates as the folder syncs — no export/zip needed.

Consider also turning this into a real git repo (`git init`, push to a private GitHub/GitLab repo) if you want diffable history and easier multi-person editing going forward. Right now nothing here is version-controlled.

### 2. n8n cloud (designprodigy.app.n8n.cloud)

- **Invite the user:** as the instance owner, go to Settings → Users → Invite, enter their email. n8n emails them a join link. ([n8n Cloud setup docs](https://docs.n8n.io/user-management/cloud-setup/))
- **Give them something to work with:** an invited member with no shared project sees nothing. Either:
  - Move the relevant workflows and credentials into a shared **Team project** and add them to it (Workflow/Credential menu → Move; when moving a workflow, you can choose to share its credentials along with it), or
  - Share individual credentials/workflows with their user directly.
  - Note: moving a credential strips any *existing* sharing on it — re-add anyone else who needed it. ([Credential sharing docs](https://docs.n8n.io/credentials/credential-sharing/), [RBAC projects docs](https://docs.n8n.io/user-management/rbac/projects/))
- Multi-user management is a paid-plan feature on n8n Cloud — confirm the current plan supports it before promising access.

### 3. Supabase

- Org **Hon-Lam-Chia** (`rhlcngpiondbiqlirpbx`), project **Hon-Lam-Chia's Project** (`fqsqoxsosavjhdsvfevk`, ap-southeast-2).
- Org Settings → Team → invite by email, pick a role: Owner / Administrator / Developer / Read-Only. ([Access control docs](https://supabase.com/docs/guides/platform/access-control))
- On Team/Enterprise plans you can scope the invite (or a later role assignment) to just this one project rather than the whole org — useful if Hon Lam has or adds other unrelated projects later.
- Recommendation: **Administrator** if they need to run migrations/manage the schema, **Developer** if they just need to query and build dashboards.

### 4. Salesforce

Two different questions, easy to conflate:
- **Do they need to run the n8n→Salesforce sync?** No new Salesforce login needed — the existing "Salesforce account" OAuth2 credential in n8n already authenticates independently of who triggers the workflow. Sharing the n8n credential (step 2) is sufficient.
- **Do they need to log into Salesforce directly** (to see the synced Campaigns/Leads, debug, or eventually take over the credential)? Then they need an actual Salesforce user: Setup → Users → New User, assign a User License and Profile, save — Salesforce emails them a password-setup link. Confirm a spare license is available first; this is a prototype org and licenses may be limited. ([Salesforce add-user docs](https://help.salesforce.com/s/articleView?id=005225092&language=en_US&type=1))

### 5. GA4

Admin (gear icon) → under the Property column, **Property Access Management** (not Account Access Management, unless they should see every property on the account) → blue **+** → Add users → enter email → pick a role (Viewer for visibility-only, Editor if they'll change config, Analyst for explorations). ([GA4 access management help](https://support.google.com/analytics/answer/9305587?hl=en))

### 6. Gmail (outcome measurement + rep notification emails)

Decide which model fits:
- **They take over sending/reading as `honlamchia@gmail.com`** — grant Gmail delegate access: Gmail Settings → Accounts and Import → "Grant access to your account" → Add another account → their email. Delegates can read/send/delete on that mailbox. ([Gmail delegation help](https://support.google.com/mail/answer/138350?hl=en))
- **They should send as themselves instead** — create a new Gmail OAuth2 credential in n8n under their own Google account, then repoint the relevant nodes (Action/Brief Approval Handlers, GA4/Gmail measurement) at the new credential. More setup, but doesn't mix identities in the rep-facing emails.

## Open items (don't let these get lost in the handoff)

Updated **2026-07-07**. Full detail in `PROJECT_AUDIT.md` (see its "Update — 2026-07-06/07" section).

**Done since the last handoff pass:** GA4 workflow swap; Error Workflow attached pipeline-wide + GA4 feeder fixed; retries added to external nodes; SF error-logging on Action Approval Handler; `pipeline_errors` legacy resolved; Gate1/Gate2 legacy trimmed (6 tables + `match_documents` + 2 views + 8 `pipeline_runs` columns dropped — RAG tables `documents`/`agent_inputs`/`*_bak` are gone); MMM instrumentation applied (funnel objectives + action-mix matrix + daily pg_cron status job); Salesforce Lead sync re-enabled (gotcha #3).

**Still open — biggest to smallest:**
1. **Get off personal accounts.** Everything runs under Hon Lam's personal logins (see above) — the #1 handoff blocker. Move to shared/company-owned n8n, Supabase, Salesforce, Google, S3, OpenAI.
2. **The go-live inputs (external):** `app_config.tracking_base_url` (a DP-owned website w/ GA4) and `when_engine_url` (Jocelyn's WHEN-engine endpoint) are still empty, so tracked links are placeholders and reject-feedback is dropped — this is why `engagement_events`/`outcomes` are empty. Plus a real `rep_notification_email`.
3. **Drop the root-cause default-ACL rule** on the `public` schema (gotcha #2) instead of patching each new view.
4. Small: add the 4 unindexed FK covering indexes; archive the inactive monolith `rNFL6JkvW5TxnaQv` + "My workflow 2"; decide on `pipeline_runs_gate1_archive` (safe to drop) and the now-unused pgvector extension; regenerate `supabase/schema.sql` (currently a base file + dated migrations).

## On Claude/Cowork context specifically

If the new person will also work with Claude on this project: the architecture/decision context above lives in *this* Claude account's memory and won't be visible to their account automatically. This document plus `README.md`/`PROJECT_AUDIT.md` is the portable version — point their Claude at this repo and these three files and it'll have the same grounding.
