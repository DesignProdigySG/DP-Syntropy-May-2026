# Connecting the WHEN Engine (RE:AI) → Automation Pipeline

Short hand-off for Jocelyn. Full detail: `WHEN_ENGINE_INTEGRATION.md`.

## 1. The one setting that connects it (engine → pipeline)

In the engine: **Settings → Integrations → Webhook URL**, set it to:

```
https://designprodigy.app.n8n.cloud/webhook/delivery-layer
```

Then **Export brief** POSTs the brief JSON to the pipeline instead of downloading a file. That's the whole inbound hand-off — no code on either side, just this URL.

## 2. What the exported brief must contain (so the pipeline can read it)

POST a JSON body — a single brief object, or an array for batch. Observed shape (schema v1.1):

```json
{
  "meta": { "document_type": "account brief", "schema_version": "1.1", "export_date": "YYYY-MM-DD" },
  "account": { "name": "Meridian Logistics", "industry": "...", "theme": "..." },
  "buying_group": [
    { "name": "Dana Kim", "title": "VP Operations", "focus_area": "fleet efficiency", "status": "CONFIRMED" }
  ],
  "signals": [ /* engine-detected signals */ ]
}
```

Must-haves the pipeline depends on:
- **`account.name`** — used as the join/correlation key.
- **`buying_group[].status = "CONFIRMED"`** — this specific value triggers Salesforce lead creation. It's functional, not cosmetic.
- **urgency / stage / trigger / coverage** — these drive scoring and campaign-template matching (see item 3 below).

## 3. What I need back from you to finish the mapping

1. **Exact JSON paths** in your export for: `when_urgency`, `when_stage`, the structural `trigger`, coverage (`engaged` / `total` counts), and CAP archetype/confidence if present. The pipeline's destination columns already exist — I just need to map them to wherever they live in your payload.
2. **A stable identifier** — a `brief_id` or `account_id` in the payload that we can echo back. Today we correlate by account *name*, which is fragile.
3. **Auth** — the inbound webhook is currently open (no auth). If you want a shared-secret header or bearer token, tell me the scheme and I'll add the check.
4. **The feedback leg (this is what closes the loop):** can your engine expose an **inbound endpoint to receive** our signal-return POSTs — engagement events + human rejections, appended as `human_signals[]`? Your Settings today only has the *outbound* export webhook. Once you give me that receive-URL, we set `when_engine_url` on our side and the loop is closed end-to-end.

## 4. Heads-up on timing

The pipeline currently runs on personal n8n/Supabase accounts (pre-re-home), and the n8n account is **over its monthly execution quota right now** — so a test brief may sit unprocessed until that resets or the plan is bumped. Worth coordinating a time to test the first real hand-off.
