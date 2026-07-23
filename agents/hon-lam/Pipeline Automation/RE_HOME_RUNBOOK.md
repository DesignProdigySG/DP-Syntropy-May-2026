# Intelligent Automation Pipeline — Re-home Runbook (moving off personal accounts)

Goal: stand the pipeline up on **company-owned** accounts so nothing depends on Hon Lam's personal logins. Follow this list top to bottom.

## When to do this
Do it **once the pipeline is functionally proven (now) and BEFORE real traffic flows** — not after everything is "perfect." Two reasons:
- The database is **pre-traffic (empty tables)**, so re-homing needs **zero data migration** right now. This is the cheapest it will ever be.
- You do not want real prospect data, CRM writes, or outreach emails ever flowing through personal accounts (privacy/compliance). Re-home as part of provisioning the go-live inputs (website, WHEN endpoint, real accounts), just before the first real account runs.

## Security ground rule (read first)
**Never share passwords or "auto-login" as someone else.** Every platform below has a proper invite/role/OAuth mechanism where the new owner authenticates **as themselves**. For machine-to-machine connections (n8n → Supabase/Salesforce/Google), the owner creates **their own** OAuth credentials/keys inside n8n by going through the OAuth flow — their identity, their tokens. Nobody handles anybody else's password.

---

## Step 1 — Provision the company-owned accounts
Create fresh, company-owned:
- **Supabase** project (new org).
- **n8n** workspace/project (cloud or self-hosted).
- **Salesforce** org — a **Developer Edition sandbox** (keep the sandbox-only rule; never a real-data org).
- **Google** account → its **Gmail** + a **GA4** property + a **service account** (for GA4 reporting).
- **AWS** account → an **S3** bucket for brief HTML.
- **OpenAI** API key (company billing).

## Step 2 — Supabase (the database)
1. In the new project's SQL editor (or via `psql`/Supabase CLI), run **`supabase/setup.sql`** — one file, reproduces the entire current schema, views, functions, seed templates, RLS, and generates a **fresh** HMAC secret. (Pre-traffic, so there is no data to migrate.)
2. If the `create extension pg_cron` line errors, enable **pg_cron** via Dashboard → Database → Extensions, then re-run section 2c of the file.
3. Note the new project's **URL**, **anon (publishable) key**, and **ref** — you need them for the dashboards and n8n.
4. Reminder: the `public` schema still carries the default-ACL leak — every *new* view needs an explicit `REVOKE ALL … GRANT SELECT`. (`setup.sql` reproduces this; consider dropping the root rule during re-home.)

## Step 3 — n8n (the workflows)
1. **Import** each workflow (`n8n-workflows/` — export fresh from the old instance first; the repo `.json` files are stale). All active workflows + the Error Workflow — includes the 2026-07-08 additions: `LinkedIn → Engagement` `/webhook/linkedin`, `Email Events → Engagement` `/webhook/email-events`, and the LinkedIn post approval loop (`LinkedIn Post Generator` `/webhook/generate-linkedin-post` + `LinkedIn Post Approval Handler` `/webhook/linkedin-post-approval`). Also run the dated Supabase migrations, incl. `2026-07-08_linkedin_posts.sql` (`linkedin_posts` table) if `setup.sql` hasn't been regenerated to include it.
2. **Recreate credentials** in the new n8n (the owner authenticates each): **Postgres** (→ new Supabase), **OpenAI**, **AWS S3**, **Salesforce** (the new **sandbox**), **Gmail** (OAuth), **Google service account** (GA4).
3. **Repoint every node's credential** to the new ones, and re-check after each `update_workflow` — the SDK has repeatedly auto-assigned the wrong credential (esp. Salesforce). Never let a SF node point at a real-data org.
4. **Publish** each workflow, and **diff draft vs. active before publishing** (the field-drop trap).
5. **Attach the Error Workflow** to every active workflow (Settings → Error Workflow) — UI-only, doesn't survive import automatically.
6. Note the new n8n **webhook base URL** (replaces `designprodigy.app.n8n.cloud`).

## Step 4 — Dashboards
Edit both `dashboards/pipeline-control-tower.html` and `-shared.html` (and `quick-log.html`): update the **Supabase URL + anon key** constants and any **n8n webhook base URL** to the new instances.

## Step 5 — Config (dashboard Settings tab)
Set on the new deployment: `tracking_base_url` (DP website), `ga4_property_id` (new property), `when_engine_url` (WHEN endpoint), `rep_notification_email` (a company rep). `approval_required_channels`, `recommendation_expiry_days`, and the fresh `approval_hmac_secret` are seeded by `setup.sql`.

## Step 6 — Smoke test
Run the synthetic end-to-end check (the "Meridian Logistics" dry-run pattern) to confirm the loop turns on the new stack: a brief → auto-created objective → actions → engagement → objective `met` → a row in `mmm_account_action_mix`. Then delete the demo rows.

---

## Find-and-replace map (every hardcoded reference)

| Reference | What it is | Where it lives | Change to |
|---|---|---|---|
| `designprodigy.app.n8n.cloud` | old n8n base URL | dashboards (3 HTML files) + n8n webhook nodes + docs | new n8n instance URL |
| `fqsqoxsosavjhdsvfevk` (+ `…​.supabase.co`) | old Supabase project ref/URL | dashboards + docs | new Supabase project ref/URL |
| Supabase **anon key** | embedded publishable key | dashboards (`SUPABASE_KEY` constant) | new project's anon key |
| `honlamchia@gmail.com` | personal email fallback/sender | **n8n**: Opportunity Offer `sendTo`, Cadence Scheduler digest fallback (+ docs) | company sender; set `app_config.rep_notification_email` and de-hardcode the two nodes |
| `dp-pipeline-briefs` | S3 bucket for brief HTML | **n8n** Delivery Layer S3 node + AWS credential | new company S3 bucket |
| `542471069` | GA4 property ID | `app_config.ga4_property_id` (data) + docs | set the new GA4 property via Settings |
| SF credential `HPnx6HXN8COY4aOe` / real-org `hhgpLMFIO8Wl2Ykr` | n8n Salesforce credential IDs | n8n only | new sandbox SF credential; never wire the real-data org |

## Gotchas to carry across (hard-won — see `HANDOFF.md`/`PROJECT_AUDIT.md`)
- **n8n draft vs. active** silently diverge — always publish and diff before relying on a change.
- **Credential auto-assign** picks the wrong credential (esp. Salesforce) — re-verify after every SDK edit.
- **Salesforce = sandbox only**, always.
- **Supabase default-ACL leak** — `REVOKE ALL … GRANT SELECT` on every new view.
- One scheduled job (`objective-status-daily`) runs in **pg_cron**, not n8n — its errors show in `cron.job_run_details`.
