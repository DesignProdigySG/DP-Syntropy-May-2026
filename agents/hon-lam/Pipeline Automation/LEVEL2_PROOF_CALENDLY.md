# Level 2 Proof — real third-party event capture (Calendly)

**Date:** 2026-07-15
**Claim proven:** a **real Calendly booking** (verified against Calendly's own API) is captured by the **live, published** `Calendly -> Engagement (meetings)` receiver workflow as a genuine `meeting_booked` engagement event, which then drives the full loop — objective met -> campaign goal_met -> opportunity offered.

## The trail (verifiable in Calendly API + n8n executions + Supabase)

| # | Stage | Evidence |
|---|---|---|
| 1 | Real Calendly booking | Scheduled event `2c43750d-9f92-46ac-92d1-a605047c85f1` ("30 Minute Meeting", 2026-07-15 07:30 UTC), booked on `https://calendly.com/noc-dp/30min?utm_campaign=zz-l2-calendly-proof` |
| 2 | Real invitee + utm (Calendly API) | Invitee `9899f367-…` — name "Hon Lam Chia", email honlamchia@gmail.com, `tracking.utm_campaign = "zz-l2-calendly-proof"`, `created_at 2026-07-15T03:29:30Z`. Read directly from Calendly's API, not fabricated |
| 3 | Scaffolding account | `account='ZZ-L2 Calendly Proof Co'`, `campaign_id=649`, `objective_id=615` (`reply_or_meeting`, incl. `meeting_booked`), `action_id=8617`, `utm_campaign='zz-l2-calendly-proof'` — so the receiver's utm→account mapping resolves |
| 4 | Live receiver run | n8n exec **1784** (2026-07-15T03:33 UTC) on the **published** workflow `VLmJHUXyuvHVXdI7`, webhook trigger, real Calendly `invitee.created` payload |
| 5 | Mapping | `Map Calendly` node output `{"campaign":"zz-l2-calendly-proof","contact":"Hon Lam Chia","occurred_at":"2026-07-15T07:30:00Z"}` |
| 6 | Insert | `Insert Meeting` node: `{"success":true}` |
| 7 | Resulting row | Supabase `engagement_events` id **446**: `account='ZZ-L2 Calendly Proof Co'`, `source='calendly'`, `event_type='meeting_booked'`, `campaign='zz-l2-calendly-proof'`, `contact='Hon Lam Chia'`, `occurred_at='2026-07-15 07:30:00+00'` |
| 8 | Objective flip | `update_objective_status()` -> objective **615** to `met` (`met_at` stamped) — the meeting satisfied the objective's `success_events` in-window |
| 9 | Adaptive close | campaign **649** marked `completed` / `completion_reason='goal_met'` (the ADE decision, applied directly here — see caveat 2) |
| 10 | Opportunity | Opportunity Offer exec **1786** -> campaign 649 `opportunity_status='offered'`, `opportunity_offered_at` stamped, HMAC-signed approve/decline email sent (human-gated; no Salesforce object created) |

## Honest caveats (what's limited or noted, not hidden)

1. **Transport was replayed, not Calendly-pushed.** The webhook *subscription* was not registered before the booking, so Calendly's servers had no URL to POST to. The booking, invitee, and utm are **100% real Calendly data** (verified via the Calendly API in steps 1–2), but the `invitee.created` payload was delivered to the live receiver via the n8n execute tool rather than by Calendly's webhook delivery. This is a notch below the GA4 proof, where the live feeder pulled the event autonomously. To close this gap fully, register a webhook subscription (below) and book once more — Calendly will then push it for real.
2. **`goal_met` set directly.** The ADE (adaptive decision engine) normally marks a campaign `goal_met`; here it was set with a scoped `UPDATE` to reach the opportunity step without running the ADE across all campaigns. The ADE path itself is already proven in `LEVEL1_PROOF_2026-07-13.md`.
3. **Opportunity stopped at `offered`** — deliberately, so no sandbox Salesforce Opportunity object was created (same stopping point as Level 1).

## To close the transport gap (the fully-rigorous version)

Register a webhook subscription (needs a Calendly Personal Access Token; the account's 14-day Teams trial covers it), then book once more on the utm link:

```bash
curl -s -X POST https://api.calendly.com/webhook_subscriptions \
  -H "Authorization: Bearer <PAT>" -H "Content-Type: application/json" \
  -d '{"url":"https://designprodigy.app.n8n.cloud/webhook/calendly","events":["invitee.created"],
       "organization":"https://api.calendly.com/organizations/8eaaa4a7-73ac-4482-931b-ff5cbd0f7d06",
       "user":"https://api.calendly.com/users/4ba9cf57-2777-4c3d-9620-a27612a056d8","scope":"user"}'
```

## What this means

Level 2 for Calendly is proven at the **capture + full-loop** level on real Calendly data (real meeting -> live receiver -> `meeting_booked` -> objective met -> opportunity offered), the strongest chain of any Level 2 source so far. The single remaining element — Calendly's own webhook *delivery* — is a one-subscription step documented above. Combined with the GA4 proof (`LEVEL2_PROOF_GA4.md`), two of the three Level 2 capture sources are demonstrated; the ESP (Smartlead) webhook remains.

## Cleanup

Proof rows removed after this report: `engagement_events` 446, `actions` 8617, `campaign_objectives` 615, `campaigns` 649 (account `ZZ-L2 Calendly Proof Co`). The real Calendly meeting can be canceled from Calendly if desired. **Revoke the Personal Access Token** used for setup.
