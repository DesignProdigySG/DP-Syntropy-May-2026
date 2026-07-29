# Getting Hon Lam's pipeline off his personal accounts

Six n8n credentials — Postgres, OpenAI, AWS S3, Salesforce, Gmail, Google Service
Account — all live under Hon Lam's personal accounts today (`HANDOFF.md` confirms
this explicitly: all six sit in the personal n8n project `Hon Lam Chia
<honlamchia@gmail.com>`). OpenAI is already ours. This doc tracks the plan to
move the rest, one at a time, starting with email — the one with the most
nodes touching it and the only one with a real operational risk if rushed
(in-flight reply tracking).

Priority order agreed: **email first**, then whatever's next in the list below.

---

## 1. Email (Gmail) — in progress

**The problem:** every Gmail node in every workflow (24 nodes across ~15
workflows) authenticates as the same personal account, `honlamchia@gmail.com`
(credential id `vKMX1dZQWsi80BVz`). Three places also hardcode a recipient
address directly in the node, bypassing `app_config.rep_notification_email`
entirely.

**Destination decided:** a real company mailbox. Plan is to configure one
directly if possible; falling back to `servicedesk@dp.sg` if not — either way,
company-owned, not another personal account.

### Done
- [x] Confirmed the credential is genuinely shared across all 24 Gmail nodes
      (verified by grepping every exported workflow JSON for the credential id).
- [x] Confirmed live `app_config.rep_notification_email` = `chiahonlam.school@gmail.com`
      (queried Supabase directly — this is a *different* address from the Gmail
      *sending* credential, easy to conflate the two).
- [x] Found and fixed the first of three hardcoded-recipient holdouts:
      **Delivery Layer** (`HQdvWtRfLdzDTN3X`) → `Approval Email` node had
      `sendTo: "honlamchia@gmail.com"` as a literal string, never reading config
      at all.
      - `Get HMAC Secret` node's query extended to also select
        `rep_notification_email` (same pattern Opportunity Offer already used).
      - `Approval Email`'s `sendTo` now reads that value, falling back to the
        exact current hardcoded address if config is blank — **behavior is
        unchanged until `rep_notification_email` is deliberately updated.**
      - Landed in **draft only, unpublished** (`versionId` differs from
        `activeVersionId` — confirmed the live workflow is untouched).
      - One mistake made and caught in the process: a whole-object parameter
        replace briefly dropped the node's required `resource`/`operation`
        fields; re-added and re-verified clean. Two unrelated pre-existing
        validation warnings on other nodes (`OpenAI Chat Model3`,
        `Send a message4`) were not touched and are not new.
- [x] Checked **Opportunity Offer** (`dnGpK2weiPIcikGa`) — turned out to
      *already* read `rep_email` from config correctly (the doc claiming it was
      hardcoded, `RE_HOME_RUNBOOK.md`, is itself stale). No fix needed here.
- [x] Checked **Cadence Scheduler** — already reads `rep_notification_email`
      with a safe fallback. No fix needed.

### Left to do
- [ ] **Decide and provision the actual new mailbox** (direct config vs.
      `servicedesk@dp.sg` fallback) — this is the one blocking prerequisite,
      an account/domain decision, not an n8n change.
- [ ] Create the new Gmail OAuth2 credential in n8n once the mailbox exists.
      Grant full scope up front (send, compose/drafts, read, modify) — several
      nodes need more than bare "send" (`Search Replies (Gmail)` does `getAll`,
      `Digest Reply Logger` does `markAsRead`, `Reply Triage`/`Action Approval
      Handler` create drafts).
- [ ] Update `app_config.rep_notification_email` to the new address (this is
      what actually flips behavior on the fix already landed above).
- [ ] Re-point all 24 Gmail nodes to the new credential, one at a time,
      verifying the assigned credential after each change (this project has a
      documented history — see `PROJECT_AUDIT.md` — of n8n silently
      mis-wiring credentials during automated edits; don't batch this blind).
      Full node list gathered earlier this session:
      - Delivery Layer: `Approval Email`, `Send a message4`
      - Brief Approval Handler: `Send Brief to Rep`, `Action Approval Email`
      - Action Approval Handler: `Send Action to Rep`, `Create Ready-to-Send Draft`
      - Cadence Scheduler: `Send Daily Digest`
      - Opportunity Offer: `Send Opportunity Offer Email`
      - LinkedIn Post Generator: `Send Approval Email`
      - LinkedIn Post Approval Handler: `Send Publish Email`
      - Reply Triage: `Notify Rep`, `Create Draft Reply`
      - Digest Reply Logger: `Find Digest Replies`, `Mark Reply Read`, `Send Confirmation`
      - Pre-Meeting Prep: `Send Prep Sheet`
      - Stale Touch Nudge: `Send Nudge`
      - Weekly Wins Report: `Send Report`
      - Client Onboarding: `Confirmation Email`
      - Tool Campaign Provisioner: `Provisioning Summary`
      - Pipeline Heartbeat: `Alert Heartbeat Problems`
      - pg_cron Failure Alert: `Alert Cron Failures`
      - Error Workflow: `Send a message`
      - Action Outcome Measurement: `Search Replies (Gmail)`
- [ ] **Cutover window:** don't revoke Hon Lam's access to `honlamchia@gmail.com`
      until every action sent from it before the switch has aged past its
      `window_days` (typically 14) — otherwise in-flight replies go unmeasured.
- [ ] Publish the Delivery Layer draft (and any other edited drafts) once the
      new address is live in config — currently sitting unpublished on purpose.
- [ ] End-to-end test with a synthetic brief through ①→⑤ confirming the
      approval email, the digest, and the Gmail draft all land in the new
      mailbox, not the old one.

---

## 2. GA4 property — not started, cheapest win available

Live check (Supabase, queried directly): `app_config.ga4_property_id` =
`542471069`, which `PROJECT_CONTEXT_HANDOFF_2026-07-08.md` explicitly labels as
**Hon Lam's own personal GA4 property**. A DP-owned property (`399321337`)
already has the service account granted Viewer access as of 2026-07-08 — the
swap to it was simply never made. This is a single config value change once
someone confirms `399321337` is the intended final property. Lowest effort of
everything on this list.

## 3. AWS S3 — not started

Bucket `dp-pipeline-briefs-801945369051-ap-southeast-1-an` stores one HTML file
per generated brief (linked from the approval email as `brief_s3_url`) — not a
deployment/hosting platform, just a document drop. Needs: new company AWS
account + bucket, new credential, repoint one node (Delivery Layer's
`Upload a file`). Low node-count, low risk.

## 4. Salesforce sandbox — not started

Lower urgency since nothing there is customer-facing (disposable Developer Edition
org). Bigger lift than S3 since more nodes/workflows touch it (Task/Lead/Campaign
sync across Brief Approval Handler, Action Approval Handler, Opportunity Approval
Handler, Salesforce Activities Read-back, Salesforce Task Outcome Sync).

## 5. n8n / Supabase ownership itself — not started

The meta-question of who owns the orchestration layer and the database. Biggest,
slowest, do last — everything above assumes n8n/Supabase stay put for now.

---

## Known landmines to remember when working on any of the above

- **`update_workflow`'s whole-object `replace: true` can silently drop required
  fields** (e.g. a Gmail node's `resource`/`operation`) — always re-check
  `validationWarnings` in the response, don't assume success from a 200.
- **n8n's credential auto-assignment has a documented history of picking the
  wrong credential** (e.g. Salesforce sandbox vs. production) during automated
  workflow edits — verify the actual assigned credential after every change,
  never trust the intended one.
- **Drafts vs. active versions are genuinely separate** — editing a workflow via
  the API only touches the draft (`versionId`) until explicitly published; the
  live `activeVersionId` is untouched until then. Confirmed working as expected
  during the Delivery Layer edit above.
- **This repo's own docs have already been caught stale more than once**
  (`WHEN_ENGINE_INTEGRATION.md`'s brief schema, `RE_HOME_RUNBOOK.md`'s claim
  about Opportunity Offer being hardcoded) — always verify against the live
  workflow/database, not just the markdown, before acting on a claim in these
  docs.
