# DP Syntropy — Handoff Guide

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
3. **Salesforce sync is real but partially disabled on purpose.** Campaign sync (one Salesforce Campaign per approved brief) is live. Lead/CampaignMember sync was built, end-to-end tested, then **deliberately disabled** (5 nodes set `disabled: true` in Action Approval Handler) on 2026-06-28 pending review — there's no real contact-email data yet (`buying_group` entries have no email field), so it was paused before running against real data rather than risk pushing bad Leads. Don't re-enable without checking in.
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

From `PROJECT_AUDIT.md`'s priority list, as of 2026-06-28 — check that file for full detail before acting on any of these:

1. Swap the GA4 workflows — deactivate "GA4 Engagement Connector" (has a duplicate-insert bug), activate "GA4 → Engagement Feeder" (the correct version) — before real tracked traffic exists.
2. 10 of 16 live n8n workflows are still undocumented in `n8n-workflows/README.md`; decide whether the undocumented pgvector/RAG tables (`documents`, `agent_inputs`, `agent_inputs_bak`) are part of the system or dead weight to drop.
3. Housekeeping: archive 3 duplicate "Gate 1" workflows + "My workflow 2"; resolve or explain 13 stale, all-unresolved `pipeline_errors`; fix the `rep@yourcompany.com` placeholder still in Action Approval Handler; clean up `*_bak` tables once confirmed unneeded.
4. Drop the root-cause default-ACL rule on the `public` schema (see gotcha #2 above) instead of continuing to patch each new view individually.
5. Decide on the disabled Salesforce Lead/CampaignMember sync (gotcha #3 above) — re-enable, rebuild, or drop.

## On Claude/Cowork context specifically

If the new person will also work with Claude on this project: the architecture/decision context above lives in *this* Claude account's memory and won't be visible to their account automatically. This document plus `README.md`/`PROJECT_AUDIT.md` is the portable version — point their Claude at this repo and these three files and it'll have the same grounding.
