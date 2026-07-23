# Level 2 Proof — real third-party event capture (GA4)

**Date:** 2026-07-13 (visit) → 2026-07-14 05:00–05:00:11 SGT (feeder capture, exec 1522)
**Claim proven:** a real browser session — not a hand-crafted POST — flows through GA4's own collection servers, is processed by Google, and is read back by the **live, published** "GA4 → Engagement Feeder" workflow via the GA4 Data API, landing as a genuine `engagement_events` row with zero manual data edits.

## The trail (all verifiable in n8n executions + Supabase + GA4)

| # | Stage | Evidence |
|---|---|---|
| 1 | Real browser visit | `http://www.dp.sg/?utm_source=dp-proof&utm_medium=referral&utm_campaign=zz-l2-ga4-proof`, visited 2026-07-13 (Asia/Singapore) on a page carrying the GA4 tag |
| 2 | Property swap | `app_config.ga4_property_id` changed from **542471069 → 399321337** so the feeder reads the property carrying the tagged page |
| 3 | Access grant | The feeder's service account was granted **Viewer** on GA4 property 399321337 |
| 4 | Scaffolding account | `account='ZZ-L2 GA4 Proof Co'`, `campaign_id=48`, `action_id=190`, `utm_campaign='zz-l2-ga4-proof'` seeded so the feeder's utm→account mapping resolves |
| 5 | Feeder run | exec **1522** (2026-07-14T05:00:06–05:00:11 SGT, Daily 5am schedule trigger, live published workflow 20tIbI4ku7j35dma) |
| 6 | GA4 Data API response | `Query GA4` node returned 11 rows for the 3-day window incl. `{"dimensionValues":[{"value":"zz-l2-ga4-proof"},{"value":"20260713"}],"metricValues":[{"value":"1"}]}` — GA4 itself reporting the campaign and session count, not injected by us |
| 7 | Mapping | `Map GA4` node output `{"campaign":"zz-l2-ga4-proof","date":"2026-07-13","sessions":1}` |
| 8 | Insert | `Insert Visits` node: `{"success":true}` |
| 9 | Resulting row | Supabase `engagement_events` id **244**: `account='ZZ-L2 GA4 Proof Co'`, `source='ga4'`, `event_type='page_visit'`, `campaign='zz-l2-ga4-proof'`, `value='1'`, `occurred_at='2026-07-13 00:00:00+00'` |

## Honest caveats (what's limited or noted, not hidden)

1. **~1-day GA4 processing latency, not same-session:** the visit happened 2026-07-13; GA4 didn't surface it until the feeder's 2026-07-14 05:00 SGT run queried the `3daysAgo..yesterday` window. This is expected GA4 Data API behavior, not a pipeline shortcut — nothing was force-inserted or backdated.
2. **`page_visit` is a leading signal, not a conversion.** This proof deliberately stops at the capture layer: a `page_visit` engagement event landing correctly. It does **not** drive `campaign_objectives` → `opportunity_offer`; no objective/outcome/opportunity logic was exercised here (that's already covered by Level 1 with `email_reply`).
3. **The `Map GA4` node lets `(organic)` / `(referral)` / `(not set)` / `(ai-assistant)` rows through too** — visible in the same exec 1522 output (9, 6, 4, 4, 1, 1 sessions across those buckets). These don't map to any known account and are harmless (no matching campaign → no insert for them), but worth noting the feeder doesn't filter GA4's default/direct traffic out before matching.

## What this means

Level 2 (real third-party capture via GA4) is proven for the `page_visit` event type — same category of proof will be needed for the ESP webhook and Calendly sources to fully close out Level 2. Level 3 = one real account with Marc's blessing.

## Cleanup

Not performed. Scaffolding left in place per instructions: `ZZ-L2 GA4 Proof Co` account, campaign 48, action 190, `engagement_events` id 244, and the `app_config.ga4_property_id` swap to 399321337. Awaiting user approval before removal/revert.
