# WHEN Engine ↔ Automation Pipeline — Integration Spec

Prepared 2026-07-08 for the WHEN-Engine connection discussion. Documents the **current, live** contract (read from the running n8n workflows + Supabase) and the **open decisions** to settle with the WHEN Engine owner. Prototype/demo status — not production.

Base URL today: `https://designprodigy.app.n8n.cloud` (n8n cloud). Changes when the pipeline is re-homed onto company-owned accounts — see `RE_HOME_RUNBOOK.md`.

> **Update 2026-07-23 — rebuilt engine + activation status.** The WHEN Layer has been rebuilt as **"RE:AI"** — `https://when-layer-engine-rebuild.onrender.com/` — with three role views off `/engine`: **Sense-Making** (default), **AE** (`?view=ae`), and **Marketer** (`?view=marketer`), plus a `/settings` page. The terminology now visible in its UI maps directly onto this spec: the **IRO classifier** runs **Gate 1 Priority → Gate 2 Trigger → Gate 3 Stage (Warm/Cold)**, and the **Stage-Designated Action Brief** carries the 7 elements (trigger, context, opening hypothesis, the stage action "Engage the Warm / Entice the Cold", buying group, **Signal Return = the closed loop this pipeline feeds — Workstream 4**, execution ownership). The rebuild does **not** change the integration contract below, but two things still gate turning the outbound loop on:
>
> 1. **Inbound (engine → pipeline) is now directly wireable.** The engine's **Settings → Integrations → "Webhook URL"** ("Export brief will POST the JSON payload to this URL instead of downloading a file") is exactly the hook for the inbound direction: set it to this pipeline's **`https://designprodigy.app.n8n.cloud/webhook/delivery-layer`** and the engine's *Export brief* pushes real briefs straight into the Delivery Layer. (That inbound webhook is still unauthenticated — §7 #5.)
> 2. **Outbound (pipeline → engine feedback) is still blocked.** The engine's Settings exposes only that one *outbound* export webhook — there is **no inbound feedback-receiving endpoint** for the closed loop / Signal Return. So `when_engine_url` cannot be set yet; the engine owner needs to add a feedback intake first (this refines §7 #1 and #4 — the feedback leg is what actually closes the loop). Once it exists, turning it on is a single `app_config.when_engine_url` update (Settings tab), no redeploy.
> 3. **n8n execution quota.** As of 2026-07-23 the n8n cloud account is over its monthly execution limit, so even inbound briefs won't be *processed* (and outbound feedback won't run) until the quota resets or the plan is upgraded.
>
> Net: the brief *hand-off* (engine → pipeline) can be connected today from the engine's own Settings page; the *feedback* leg (pipeline → engine) waits on the engine exposing an intake endpoint. Everything below documents exactly what each side sends.

---

## 1. The integration surface

Two boundaries, opposite directions:

| Direction | Who initiates | Endpoint | Purpose |
|---|---|---|---|
| **Inbound** — WHEN → pipeline | WHEN Engine | `POST /webhook/delivery-layer` | WHEN pushes account briefs in |
| **Outbound** — pipeline → WHEN | pipeline (n8n) | `POST {when_engine_url}` | pipeline pushes feedback back (engagement + human rejections) |

`when_engine_url` is a row in Supabase `app_config`. **It is currently empty**, so every outbound path is dormant (see §5). The inbound Delivery Layer is **live and ready to receive today**.

---

## 2. Inbound: WHEN → Delivery Layer (brief ingest)

- **Endpoint:** `POST /webhook/delivery-layer` (workflow `Intelligent Automation — Delivery Layer`, `HQdvWtRfLdzDTN3X`)
- **Auth:** none currently (open webhook) — decision item §7
- **Body:** a WHEN account brief (schema v1.1). **Batch-capable** — accepts a single brief object or an array (`Loop Over Items`).
- **Processing:** unwrap body → validate → score coverage → AI writes the sales brief → upload to S3 → log a `pipeline_runs` row (whole doc stored as `raw_payload`) → HMAC-sign approve/reject links → send the human approval email.

### Brief document (schema v1.1) — observed shape

```json
{
  "meta": {
    "engine": "WHEN Layer Intelligence Engine",
    "document_type": "account brief",
    "schema_version": "1.1",
    "export_date": "YYYY-MM-DD"
  },
  "account": { "name": "Meridian Logistics", "industry": "...", "theme": "..." },
  "buying_group": [
    { "name": "Dana Kim", "title": "VP Operations", "focus_area": "fleet efficiency", "status": "CONFIRMED" }
  ],
  "signals": [ /* WHEN-detected signals */ ],
  "human_signals": [ /* appended by the pipeline on the way back — see §3 */ ]
}
```

### Fields the pipeline extracts (into `pipeline_runs`)

`company` (← `account.name`), `industry`, `theme`, `when_urgency`, `when_stage`, `cap_archetype`, `cap_confidence`, coverage (`engaged_count` / `total_count` / `coverage_label`), `trigger_notes`, `is_actionable`, `source`; full doc kept as `raw_payload`.

> **Confirm the exact source paths** for `when_urgency`, `when_stage`, `cap_archetype`, `cap_confidence`, and coverage — the destination columns are known but the brief-side JSON paths should be pinned down.

**Live contract field:** `buying_group[].status == "CONFIRMED"` drives Salesforce Lead creation on approval. `status` is functional, not cosmetic.

---

## 3. Outbound: pipeline → WHEN (feedback)

All three paths behave identically: reconstruct the account's brief from `raw_payload`, **append one entry to `human_signals[]`**, and `POST` the **entire brief** as JSON to `when_engine_url`. Each is guarded by an "Engine URL set?" check (no-op if blank), retries 3×/2s, and `onError: continue`.

### 3a. Engagement signals
Workflow `Engagement → WHEN Signals` (`grv4TN8pUrrW0xPa`), schedule **daily 07:00**. Groups new `engagement_events` per account, appends one signal per event:

```json
{ "type": "engagement", "signal": "email_open", "occurred_at": "2026-07-08T10:00:00Z", "value": 1, "source": "delivery_layer" }
```

`signal` is the `engagement_events.event_type` — now includes the new feeders' types (`email_open`, `email_click`, `linkedin_accept`, `linkedin_reply`, `linkedin_profile_view`, `linkedin_post_engage`) plus `page_visit`, `meeting_booked`, `crm_activity`, etc.

### 3b. Brief rejection
Workflow `Brief Approval Handler` (`AoVkLOncTxZqQlwz`), on human reject of a brief:

```json
{ "type": "human_rejection", "gate": "brief", "reason": "rejected_by_human", "rejected_at": "...", "source": "delivery_layer", "run_id": 123 }
```

### 3c. Action rejection
Workflow `Action Approval Handler` (`UyplqAAHgTNOvRuC`), on human reject of a recommended action:

```json
{ "type": "human_rejection", "gate": "action", "reason": "stale_fact", "routed_to": "source", "rejected_at": "...", "source": "delivery_layer", "action_id": 456 }
```

Routing logic on `reason`: `{stale_fact, wrong_contact, incorrect_information}` → `routed_to: "source"` (data problem — kick back to the source); everything else → `"engine_logic"`. This tells WHEN *why* a human declined.

---

## 4. Field-by-field contract table

| Field | Direction | Type | Meaning / notes |
|---|---|---|---|
| `meta.schema_version` | in | string | `"1.1"` today; version gate |
| `account.name` | in | string | **de-facto join key** → `pipeline_runs.company` (fragile, see §6) |
| `account.industry`, `account.theme` | in | string | stored, shown on dashboard |
| `buying_group[].name` | in | string | split into first/last for SF Lead |
| `buying_group[].title`, `.focus_area` | in | string | carried to SF Lead |
| `buying_group[].status` | in | enum | `CONFIRMED` triggers SF Lead creation |
| `signals[]` | in | array | WHEN-detected signals (opaque to pipeline) |
| `when_urgency`, `when_stage` | in | string | drives template match; confirm JSON path |
| `cap_archetype`, `cap_confidence` | in | string | stored; confirm JSON path |
| coverage (`engaged`/`total`) | in | int | coverage scoring; confirm JSON path |
| `human_signals[].type` | out | enum | `engagement` \| `human_rejection` |
| `human_signals[].signal` | out | string | engagement event type (3a) |
| `human_signals[].value`, `.occurred_at` | out | num/ts | engagement magnitude + time |
| `human_signals[].gate` | out | enum | `brief` \| `action` (rejections) |
| `human_signals[].reason` | out | string | rejection reason |
| `human_signals[].routed_to` | out | enum | `source` \| `engine_logic` (action rejections) |
| `human_signals[].run_id` / `.action_id` | out | int | correlation back to the pipeline row |
| `human_signals[].source` | out | string | always `delivery_layer` |

---

## 5. Current state / blocker

- `when_engine_url` = **empty** → all outbound feedback is dormant; engagement events accumulate `forwarded=false` and will flush once the URL is set.
- Delivery Layer inbound is **live**.
- Also empty: `app_config.tracking_base_url`, `rep_notification_email`.
- Whole stack runs on **personal accounts** (re-home pending).

Setting `when_engine_url` (dashboard Settings tab) is the single switch that turns the feedback loop on.

---

## 6. Known weak spots to raise

- **Full-brief echo, not a delta.** Every feedback POST re-sends the whole brief with one appended signal — heavy, and no natural idempotency key, so re-sends look like fresh docs.
- **Correlation by account *name*.** Engagement path matches `pipeline_runs.company == engagement.account` and re-sends the latest brief. A stable `account_id`/`brief_id` from WHEN, echoed back, would be far more robust.
- **Engagement "Mark Forwarded" is blanket.** It flips *all* unforwarded rows to `forwarded=true` after the POST step even if the HTTP call failed (errors swallowed). If WHEN is down, signals can be silently marked sent. Harden once the contract is real.
- **Inbound webhook unauthenticated.**
- **Degraded-brief fallback:** if `raw_payload` is missing, the pipeline sends a minimal synthetic brief (account name only).

---

## 7. Decisions to settle (discussion agenda)

1. **Feedback endpoint:** what URL/method should `when_engine_url` point to? One endpoint for all feedback, or separate per type?
2. **Payload shape:** full brief echo (current) vs a compact **delta** like `{ brief_id, account_id, new_signals: [...] }`. Recommend delta.
3. **Stable identifier:** can the brief carry `brief_id`/`account_id` we echo back, replacing name-matching?
4. **Loop closure:** after we forward a rejection, how does the re-decision return — does WHEN re-run and POST a fresh brief to `/webhook/delivery-layer`? (This is what actually closes the loop.)
5. **Auth, both ways:** inbound and outbound — shared secret header / HMAC / bearer? Who issues it?
6. **Response contract:** what does WHEN return on a feedback POST (just `200`, or an updated brief)? Idempotency key so retries don't double-count?
7. **Schema & versioning:** lock the brief fields (esp. urgency/stage/CAP/coverage source paths and `buying_group[].status` values) and a `schema_version` change process.
8. **Batching & cadence:** WHEN posts one brief per request or arrays? Is daily-07:00 engagement push frequent enough, or is near-real-time wanted?
9. **Environments:** sandbox vs prod URLs for both endpoints, given the pending move off personal accounts.

---

## 8. Reference — workflows involved

| Workflow | ID | Role in this integration |
|---|---|---|
| Intelligent Automation — Delivery Layer | `HQdvWtRfLdzDTN3X` | inbound brief ingest (`/webhook/delivery-layer`) |
| Engagement → WHEN Signals | `grv4TN8pUrrW0xPa` | outbound engagement feedback (daily 07:00) |
| Brief Approval Handler | `AoVkLOncTxZqQlwz` | outbound brief-rejection feedback |
| Action Approval Handler | `UyplqAAHgTNOvRuC` | outbound action-rejection feedback |

Config lives in Supabase `app_config` (`when_engine_url`). Briefs are stored in `pipeline_runs` (`raw_payload` = full WHEN doc).
