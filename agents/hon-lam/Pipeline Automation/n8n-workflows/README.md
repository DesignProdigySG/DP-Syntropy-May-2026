# n8n workflows

These are the workflows that make up the pipeline. The canonical, re-importable
definition lives in n8n — export each one from the n8n UI and drop the `.json`
here so the repo stays in sync.

## Workflows (n8n cloud: designprodigy.app.n8n.cloud)

| Workflow | ID | Trigger | Role |
|---|---|---|---|
| Intelligent Automation — Delivery Layer | `HQdvWtRfLdzDTN3X` | POST `/webhook/delivery-layer` (+ manual) | Ingest WHEN brief → validate → score coverage → write brief (AI) → S3 → log run → approval email |
| Brief Approval Handler | `AoVkLOncTxZqQlwz` | GET `/webhook/brief-approval` | Approve → recommend action (channel by coverage) + carry outreach draft → action email. Reject → forward to WHEN engine |
| Action Approval Handler | `UyplqAAHgTNOvRuC` | GET `/webhook/action-approval` | Approve → mark executed + send rep the message + tracked link. Reject → mark cancelled + forward to WHEN engine |
| Action Outcome Measurement | `RMPUPcf2o0ltJVeG` | Schedule (daily 06:00) | For due actions, route by metric → GA4 (web) / Gmail (replies) → write outcome → mark measured |
| Intelligent Automation (monolith) | `rNFL6JkvW5TxnaQv` | POST `/webhook/51ccc21c-…` | Original full pipeline (Gate 1 scoring + Salesforce + delivery). Still active. |

## How to export (canonical)

For each workflow in n8n: open it → top-right **⋯** menu → **Download** →
save the `.json` into this folder using the workflow name (e.g. `delivery-layer.json`).

## How to import (restore)

In n8n: **Add workflow** → **⋯** → **Import from File** → pick the `.json`.
After import, reconnect credentials (Postgres, Gmail, AWS S3, OpenAI, Google API)
and re-publish.

## Credentials used (configure in n8n, never commit secrets)

- Postgres (Supabase) — DB reads/writes
- Gmail OAuth2 — approval + reply-measurement
- AWS S3 — brief file storage
- OpenAI — brief writer
- Google API (service account) — GA4 reporting
