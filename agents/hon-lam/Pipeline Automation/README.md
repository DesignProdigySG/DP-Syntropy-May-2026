# DP B2B Lead Pipeline

An intelligence-driven outreach pipeline. WHEN-layer account briefs come in, get
turned into human-approved sales briefs and tracked outreach actions, and every
action is measured against a hypothesis so the system learns what works.

## Architecture

- **n8n** (designprodigy.app.n8n.cloud) — orchestration (ingest, brief generation, approval handlers, daily measurement)
- **Supabase** (Postgres) — system of record: `pipeline_runs`, `actions`, `outcomes`, `pipeline_errors`, `engagement_events`, `app_config` + `dashboard_*` / `console_*` views
- **AWS S3** — generated brief HTML files
- **GA4 + Gmail** — outcome measurement (web visits / email replies)
- **Dashboards** — self-contained HTML (Pipeline Control Tower) reading Supabase live

## End-to-end flow

1. **Lead in** — a WHEN-layer brief is POSTed to `/webhook/delivery-layer` (Format Adapter detects `meta.engine`).
2. **Normalize & score** — validate, compute buying-group coverage (BROAD/PARTIAL/NARROW) and engagement.
3. **Write brief** — AI writes the brief; the engine's "catch", stakes, routing line, and sources are attached. Saved to S3, logged to `pipeline_runs`.
4. **Brief approval (human gate)** — approve → recommend an action; reject → forward to WHEN engine.
5. **Recommend action** — channel chosen by coverage (linkedin_post / linkedin_message / email / content_send / ad_retarget); builds a hypothesis + UTM-tracked link; carries the WHEN engine's ready-made outreach copy.
6. **Action approval (human gate)** — approve → rep gets the message + tracked link, action marked executed; reject → forward to WHEN engine.
7. **Measure (daily)** — for actions past their window: `page_visits` → GA4, `reply_or_meeting` → Gmail → write `outcomes` (met / not-met).
8. **Dashboard** — funnels, win-rate, channel performance, attribution, segmentation, enrichment.

See `n8n-workflows/README.md` for the workflow map and `supabase/schema.sql` for the DB.

## Repo layout

```
dashboards/          Pipeline Control Tower (full + read-only shared copy)
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

- Channel selection is driven by **buying-group coverage** — accounts with unconfirmed contacts (`enrichment_needed`) stay NARROW and default to content/ad. Confirm contacts upstream to unlock LinkedIn/email.
- Tracking only registers when `tracking_base_url` is a real site you own with GA4 installed; until then links use an `example.com` placeholder.
- Rejection forwarding no-ops safely until `when_engine_url` is set.

## Security

- The dashboard HTML embeds a Supabase **publishable (anon) key** — treat dashboard files as **internal only**, do not host on a fully public URL.
- `dashboards/pipeline-control-tower-shared.html` is a read-only team copy (Settings locked).
- Never commit credentials/secrets — n8n credentials and Supabase service keys stay in their platforms.
