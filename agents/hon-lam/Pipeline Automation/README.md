# DP Syntropy — B2B Lead Pipeline

An intelligence-driven outreach pipeline. WHEN-layer account briefs come in, get
turned into human-approved sales briefs and tracked outreach actions, and every
action is measured against a hypothesis so the system learns what works.

## Architecture

- **n8n** (designprodigy.app.n8n.cloud) — orchestration (ingest, brief generation, approval handlers, daily measurement)
- **Supabase** (Postgres) — system of record: `pipeline_runs`, `actions`, `outcomes`, `pipeline_errors`, `engagement_events`, `app_config`, `campaigns`/`cadence_steps` + `dashboard_*` / `console_*` views
- **Salesforce** (prototype) — one-way synced execution layer under `campaigns`: Brief Approval Handler pushes a Salesforce Campaign per approved brief; Action Approval Handler then creates a Salesforce Task on that Campaign and syncs confirmed buying-group contacts as Leads/Campaign Members. Supabase stays the source of truth; Salesforce never writes back. Marketo was evaluated and scoped out (no org/credentials/native node).
- **AWS S3** — generated brief HTML files
- **GA4 + Gmail** — outcome measurement (web visits / email replies)
- **Dashboards** — self-contained HTML (Pipeline Control Tower) reading Supabase live

## End-to-end flow

1. **Lead in** — a WHEN-layer brief is POSTed to `/webhook/delivery-layer` (Format Adapter detects `meta.engine`).
2. **Normalize & score** — validate, compute buying-group coverage (BROAD/PARTIAL/NARROW) and engagement.
3. **Write brief** — AI writes the brief; the engine's "catch", stakes, routing line, and sources are attached. Saved to S3, logged to `pipeline_runs`.
4. **Brief approval (human gate)** — approve → recommend an action; reject → forward to WHEN engine.
5. **Recommend action** — a campaign template is auto-matched from the brief's signals (urgency / coverage / stage / keywords) for its default cadence, then an AI channel recommender (gpt-5-mini) re-plans the actual channel sequence using account score, prior actions, channel performance, and buying-group role/confirmation — falling back to the template's unmodified steps if the AI call or its output is invalid. Builds a hypothesis + UTM-tracked link per step; carries the WHEN engine's ready-made outreach copy on the email step.
6. **Action approval (human gate)** — approve → rep gets the message + tracked link, action marked executed; reject → forward to WHEN engine.
7. **Measure (daily)** — for actions past their window: `page_visits` → GA4, `reply_or_meeting` → Gmail, and `linkedin_accept`/`profile_visit`/`registration`/`content_download`/`call_connected`/`partner_response` → logged `engagement_events` (see `quick-log.html`) → write `outcomes` (met / not-met).
8. **Dashboard** — funnels, win-rate, channel performance, attribution, segmentation, enrichment.

See `n8n-workflows/README.md` for the workflow map and `supabase/schema.sql` for the DB.

## Repo layout

```
dashboards/          Pipeline Control Tower (full + read-only shared copy), quick-log.html (manual engagement logging)
n8n-workflows/       Workflow manifest + (export the .json here)
supabase/            schema.sql — tables, views, app_config, RLS/grants
```

## Setup (new environment)

1. **Supabase**: run `supabase/schema.sql` against a fresh project.
2. **n8n**: import the workflows (`n8n-workflows/README.md`), reconnect credentials, publish.
3. **Config** (Supabase `app_config`, or the dashboard Settings tab):
   - `tracking_base_url` — your GA4-tagged website (outreach links point here)
   - `ga4_property_id` — your GA4 numeric property
   - `when_engine_url` — WHEN engine inbound URL for forwarded rejections
4. **Dashboards**: open `dashboards/pipeline-control-tower.html`; update the Supabase URL/key constants if pointing at a new project.

## Configuration notes

- Cadence selection is driven by `campaign_templates` (Supabase, 18 rows / 15 named templates) — on approval, Brief Approval Handler picks the lowest-`priority` template whose `match_urgency_in`/`match_coverage_in`/`match_stage_contains`/`match_keywords` matches the brief's `when_urgency`/`coverage_label`/`when_stage`/`trigger_type` (NULL = wildcard). That template's `steps` are now a **starting point, not the final plan**: a channel recommendation AI (gpt-5-mini, JSON-mode) re-plans the channel sequence using the account's score, prior actions, channel-performance history, and buying-group role/confirmation status, restricted to the same fixed action-type vocabulary. If the AI call errors or returns invalid JSON/out-of-vocabulary output, "Parse AI Channel Plan" falls back to the matched template's unmodified steps — so the system always produces a valid cadence either way. `cadence_steps`/`actions` record which one won via `channel_source` (`ai`|`template`) and `channel_reco_reason` (the AI's stated reason, surfaced on the dashboard's Cadence steps table). `warm_reengage` (priority 99, all match columns NULL) is the catch-all fallback template. Channels include LinkedIn, email, web, ads, webinar, phone, and partner (track-only — the system recommends the action and builds a tracked link/UTM, a rep executes it manually; no new API integrations).
- Tracking only registers when `tracking_base_url` is a real site you own with GA4 installed; until then links use an `example.com` placeholder. `dashboards/quick-log.html` covers the signals GA4 can't see (LinkedIn accepts, profile views, registrations, content downloads, promising replies) — pick an open (executed) action and log it; it posts to `/webhook/engagement` and the daily measurement run picks it up like any other outcome.
- Rejection forwarding no-ops safely until `when_engine_url` is set.
- Salesforce sync is best-effort: if the "Salesforce account" credential is missing/invalid or the API call fails, `campaigns.salesforce_sync_status` is set to `error` (with `salesforce_sync_error`) and the rest of the pipeline is unaffected.

## Security

- The dashboard HTML embeds a Supabase **publishable (anon) key** — treat dashboard files as **internal only**, do not host on a fully public URL.
- `dashboards/pipeline-control-tower-shared.html` is a read-only team copy (Settings locked).
- Never commit credentials/secrets — n8n credentials and Supabase service keys stay in their platforms.
