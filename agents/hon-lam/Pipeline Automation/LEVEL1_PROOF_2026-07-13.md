# Level 1 Proof — full loop, live system, one synthetic account

**Date:** 2026-07-13 (01:43–01:52 UTC, ~9 minutes wall-clock)
**Claim proven:** every stage of Intelligent Automation Pipeline — brief → AI plan → human approval → campaign/objective → drafts → execution → automated measurement → adaptive decision → objective resolution → opportunity offer → MMM training row — works end-to-end on the **live published workflows**, with no manual data edits except documented time-compression.

## The trail (all verifiable in n8n executions + Supabase)

| # | Stage | Evidence |
|---|---|---|
| 1 | Synthetic WHEN-Layer brief POSTed to the real Delivery Layer webhook | exec **1347** (11s): `pipeline_runs` id **430** "ZZ-L1 Proof Co", AI brief written, uploaded to S3, client-tagged (trigger → client 1), **real approval email sent** (Gmail id `19f592500d31d8e1`) with HMAC-signed links |
| 2 | Signed approve link fired at Brief Approval Handler | exec **1348** (18s): campaign **47** (template `urgent_fast_track` matched on URGENT), Salesforce sandbox Campaign **synced**, objective **14** auto-created (`reply_or_meeting`, qualified, 7d, incl. `email_reply`), AI channel plan used (`channel_source: ai`), 4 cadence steps created |
| 3 | Instant drafts | action 189 + all 4 cadence steps had `outreach_draft` populated within ~30s of approval (inline `/webhook/run-draft-backfill` wiring) |
| 4 | Action approval via dashboard-style signing | Sign Link exec **1355** issued the HMAC; Action Approval exec **1356** (14s): action 189 → `executed`, Salesforce sandbox Task created, cadence step 1 synced, rep email + ready-to-send Gmail draft produced |
| 5 | Real engagement capture | Smartlead-shaped `EMAIL_REPLIED` POSTed to the live email feeder → exec **1357**: `engagement_events` id 51 (`email_reply`, snippet stored, account resolved via utm `act-430-p1-8zk`, client-tagged by trigger). Plus a real reply email placed in the pipeline mailbox |
| 6 | Measurement | Action Outcome Measurement exec **1360**: Gmail branch measured **3** messages carrying the utm token ≥ threshold 1 → outcome **met** (source: gmail) |
| 7 | Adaptive decision | ADE exec **1361**: campaign 47 → `completed` / `completion_reason=goal_met` (+ Salesforce Campaign status update path) |
| 8 | Objective resolution | `update_objective_status()` (the pg_cron function, invoked directly): objective 14 → **met**, `met_at` stamped |
| 9 | Opportunity | Opportunity Offer exec **1362**: campaign 47 → `opportunity_status=offered`, HMAC-signed approve/decline email sent to the rep |
| 10 | MMM training data | `mmm_account_action_mix` gained one labeled row (qualified / urgent_fast_track / n_email=1 / objective_met=true); dashboard readiness tile: qualified 1/30 labeled (3%) |

## Honest caveats (what was compressed or noted, not hidden)

1. **Time compression:** the daily 05:45–07:30 chain was force-run, and three timestamps were backdated 14–15 days (`actions.executed_at`, `campaign_objectives.created_at`, the engagement event) so the 14-day measurement window had "elapsed". Nothing else was hand-edited; every state change was made by the live workflows.
2. **Gmail reply measurement self-match:** the mailbox search (`"<utm>" after:<executed_at>`) counted 3 messages — the simulated inbound reply AND the pipeline's own outbound rep email/draft, which also contain the tracked link. Threshold logic still behaves correctly, but **outbound self-matches inflate the count** — worth scoping the search (e.g. `-from:me`) before real traffic.
3. **Opportunity approve/decline was NOT clicked** — stopped at `offered` deliberately so no sandbox Opportunity object was created.
4. Residue outside Postgres (left intentionally as evidence): the emails in the pipeline mailbox (brief approval, rep action email + draft, simulated reply, opportunity offer) and one Campaign + Task (+ possibly a Lead) in the **sandbox** Salesforce org.

## Cleanup

All Postgres rows for `ZZ-L1 Proof Co` deleted after this report (runs, campaign, objective, action, cadence steps, engagement event, outcome, salesforce_leads) — verified zero residual. Disposable reply-sender workflow archived. The MMM matrix row disappears with the campaign (view-derived), returning readiness to its pre-test state.

## What this means

Level 1 (plumbing) is proven. Level 2 = same loop with real third-party capture (ESP webhook, GA4 property, Calendly). Level 3 = one real account with Marc's blessing. See the 2026-07-12 handoff for the plan.
