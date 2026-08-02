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

## 0. CRITICAL — there are two separate databases with identical schemas

**Discovered the hard way, mid-session, after a real end-to-end test kept
sending to the wrong address despite the config supposedly being fixed.**

The Supabase project reachable via the Supabase MCP connection in this session
(`ssbdlttcyogtcowvcbaj`, "Intelligent Automation Pipeline") is **not** the
database n8n's real `Postgres account` credential (`eR1uo2QGR2ZzwysA`) connects
to. Confirmed conclusively by having both sides report `inet_server_addr()` in
the same moment: n8n's real connection resolved to a completely different host
(`2406:da1c:4c7:f801:...`) than the Supabase MCP session (`2406:da18:167b:f901:...`).
Both databases have byte-for-byte identical schemas (same tables, same
`app_config` keys, same seeded `clients` row `id=1` "Design Prodigy (house)")
— almost certainly because this repo's own `setup.sql`/`schema.sql` can be run
against any fresh Supabase project to produce a structurally indistinguishable
copy. Every "confirmed live" check made via the Supabase MCP tool earlier in
this session looked completely legitimate and self-consistent while quietly
being the wrong database.

**Consequence:** an earlier "fix" (see the security note below) that appeared
to succeed via direct Supabase queries never touched the real production
database at all. **The only way confirmed to actually reach the real database
in this session was through an n8n workflow node using the real `Postgres
account` credential** (e.g., temporarily repurposing `Get HMAC Secret`'s query,
running the workflow for real, then reverting the query afterward).

**Open follow-up:** figure out what `ssbdlttcyogtcowvcbaj` actually is (a
throwaway clone from an earlier session? a project under this account's own
Supabase login rather than Hon Lam's?) and get proper direct access to the
*real* project so future work doesn't need this workaround.

## 0b. Security note — corrected

Originally reported here as "found a genuinely empty `approval_hmac_secret` in
production and fixed it." **That check and fix were performed against the
wrong database** (see above) — the real production secret was checked
directly afterward (via the real n8n credential) and is a **genuine, non-empty
value**. There was no real vulnerability; withdrawing the original claim.
No action needed here.

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
- [x] **Updated `app_config.rep_notification_email` to `yuanwen@dp.sg` —
      correctly, on the real database this time.** First attempt was made via
      the Supabase MCP connection and *looked* successful, but (per §0 above)
      that was the wrong database and never actually took effect — a real
      end-to-end test kept resolving `chiahonlam.school@gmail.com` despite the
      "successful" update. Redone through an n8n workflow node using the real
      `Postgres account` credential, then re-verified with a second real
      execution: `rep_email` resolved to `yuanwen@dp.sg` for real. Cadence
      Scheduler and Opportunity Offer will pick this up on their next
      scheduled run; Delivery Layer's `Approval Email` is confirmed working
      right now (see below).
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
- [x] **Published the Delivery Layer fix and verified it end-to-end with a real
      execution** (not a simulation) — found and fixed two more real bugs along
      the way:
      1. The draft had silently reverted to a pre-fix state after publishing —
         `Approval Email`'s `resource`/`operation` fields were missing again
         despite being fixed and published earlier. Publishing does not appear
         to rebase future draft edits onto the published state; this project's
         own `PROJECT_AUDIT.md` documents the same class of issue before
         ("corrupted unpublished drafts... restored to active versions"). Fixed
         again, verified clean, re-published.
      2. **Real bug, not ours:** `Insert rows in a table`'s column mapping had
         picked up a literal `client_id: 0` (most likely auto-added by the n8n
         UI when its schema/column list was refreshed in the editor — the
         `gate1_*` schema-cache investigation earlier in this session). That
         hardcoded `0` bypassed the `set_pipeline_run_client()` trigger's
         null-check entirely, violating `pipeline_runs_client_id_fkey` on every
         real ingest until removed. Removed `client_id` from the mapping
         (restoring it to unset, matching the original repo export) so the
         trigger correctly defaults it to `app_config.default_client_id` (`1`,
         "Design Prodigy (house)").
      - `execute_workflow` also has its own quirk worth remembering: this
        workflow has two triggers (a manual one and the real webhook), and the
        tool silently defaulted to the manual trigger regardless of `inputs.type`.
        Worked around by temporarily disabling the manual trigger
        (`setNodeDisabled`), running the real test through the actual webhook,
        then re-enabling it afterward.
      - First "confirmed working end-to-end" pass (real webhook → real AI
        brief → real S3 upload → real `pipeline_runs` row → real signed links
        → real Gmail **send**, `labelIds: ["SENT"]`) actually sent to
        `chiahonlam.school@gmail.com`, not `yuanwen@dp.sg` — because at that
        point `rep_notification_email` had only been updated on the wrong
        database (§0). Re-ran after fixing that for real: **`rep_email`
        resolved to `yuanwen@dp.sg` for real, confirmed directly in the
        execution data.** All test rows created across this whole diagnostic
        chain (`450`–`453`, several account names) were in the *real*
        production `pipeline_runs` table (via the real credential) — deleted
        via the same real-credential route, confirmed via `RETURNING`. Two of
        the intermediate runs did send real test-labeled approval emails to
        Hon Lam's actual `chiahonlam.school@gmail.com` before the fix landed —
        worth a heads-up to him, clearly diagnostic content, not anything a
        real prospect would see.

- [x] **Mailbox decided and credential swapped — `servicedesk@dp.sg`, all 24
      nodes at once.** Turns out the per-node repoint checklist below was never
      actually necessary: like the Postgres credential, **every single Gmail
      node across every workflow shares the exact same credential ID**
      (`vKMX1dZQWsi80BVz`, "Gmail OAuth2 API") — there's no separate credential
      per node to hunt down individually. Yuan Wen edited that one credential's
      OAuth connection directly in n8n to authenticate as `servicedesk@dp.sg`
      instead of `honlamchia@gmail.com`. One edit, every node redirected.
      - Checked for in-flight items this sudden mailbox switch (affects reads
        as well as sends — reply-detection, digest parsing) could strand:
        **zero** pending briefs, recommended actions, executed-awaiting-reply
        actions, or offered opportunities on the (freshly-migrated, low-
        traffic) real database. No cutover risk today.
      - **Verified end-to-end with a real execution**: Delivery Layer's
        `Approval Email` sent successfully (`labelIds: ["SENT"]`) with the new
        credential — confirms the OAuth scope granted during setup is
        sufficient (send at minimum; still worth confirming read/modify/draft
        scopes are also granted, since `Search Replies (Gmail)`, `Digest Reply
        Logger`'s `markAsRead`, and the draft-creating nodes need more than
        bare send).
      - Test row cleaned up after.
- [ ] **Cutover window** still applies in principle — don't revoke Hon Lam's
      access to `honlamchia@gmail.com` until any action sent from it before the
      switch has aged past its `window_days` (typically 14). Moot today since
      there was nothing in flight, but worth remembering if this ever needs
      redoing against a database with real activity.
- [x] Delivery Layer's `Approval Email` config-read fix is published and live
      (confirmed `versionId` == `activeVersionId` during the credential-swap
      verification pass) — the credential swap itself doesn't need a separate
      publish, since credentials aren't part of the draft/active version split.
- [ ] Confirm the granted OAuth scope covers read/modify/drafts, not just send
      (see above) — a real Reply Triage/Digest Reply Logger run would confirm
      this conclusively if one hasn't happened since the swap.

---

## 2. GA4 — property flip done; service account credential still Hon Lam's

Two separate things bundled under "GA4," same pattern as Gmail/Postgres:
which property gets read, and who's actually authenticating to read it.

- [x] **Property flip — done.** `app_config.ga4_property_id` was `542471069`
      (confirmed live-verified by Yuan Wen as **not** a Design Prodigy
      property — worth noting the docs' framing of it as "Hon Lam's own" was
      taken on faith, same caution as everything else in this doc). Updated
      to `399321337`, which Yuan Wen independently confirmed *is* a genuine
      Design Prodigy GA4 property (checked directly in Google Analytics, not
      just inferred from repo docs — the repo alone can't be trusted for this
      after everything else caught stale today). Live config value, took
      effect immediately, no publish gate.
- [ ] **Service account credential — not started, needs external GCP work.**
      The `Query GA4` node's credential is literally named
      `"Hon Lam's Google Service Account for GA4"` (id `y2gRhCm6qQpZSW4d`),
      confirmed directly via `list_credentials` — homed in his personal n8n
      project, no ambiguity. To fix: someone needs access to a **company-owned
      Google Cloud project** to create a new service account there, enable the
      Google Analytics Data API, grant that new service account Viewer access
      on GA4 property `399321337`, generate its JSON key, create a new
      credential in n8n, and repoint `Query GA4` to it. External Google Cloud
      Console work, not scriptable from here — same category as needing
      direct n8n-login access for the Postgres/Gmail credential swaps.

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

## 5. Supabase migration — DONE. n8n itself still on Hon Lam's account.

**The database migration is complete and verified.** Yuan Wen got direct
Supabase dashboard access to the company-owned project (`ssbdlttcyogtcowvcbaj`,
org "Design Prodigy"), pulled the connection string from Project Settings →
Database (used the **connection pooler**, not a direct connection — fine for
this workload, no session-dependent features in play), and edited the
existing `Postgres account` credential (`eR1uo2QGR2ZzwysA`) in n8n directly —
no data copy from Hon Lam's old database was done (assessed as his own
simulated/proof-of-concept test traffic, not real client data — not needed).

**Verified with a real end-to-end execution** through Delivery Layer:
`inet_server_addr()` now resolves to `ssbdlttcyogtcowvcbaj`'s actual host
(`2406:da18:167b:f901:...`, matching what was confirmed earlier as the
company project's address) — n8n is genuinely talking to the new database.
`rep_email` correctly resolved to `yuanwen@dp.sg`, the `client_id` trigger
correctly resolved to `1`, and a real approval email sent successfully.
Test row cleaned up afterward (and this time, directly via Supabase MCP,
since it's now genuinely the same database n8n uses).

One now-orphaned leftover: the earlier `ZZZ-QA Row-Count-Check Co` test row
is stranded on Hon Lam's *old* database, which is no longer reachable from
here now that the credential points elsewhere. Harmless — that old database
is being retired anyway.

**Remaining:** n8n itself (the orchestration layer — where every workflow,
credential, and this Postgres connection actually lives) is still hosted
under Hon Lam's personal n8n account/login. Moving the database was the
piece that could be done without needing n8n itself to move first; migrating
n8n itself is the genuinely biggest remaining piece of "get off personal
accounts," and everything fixed so far still depends on his n8n instance
staying up until that happens.

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
- **Biggest one: there are two databases with identical schemas, and only one
  is real** (see §0). Any Supabase MCP query in this session hits the wrong
  one — checks and writes both *look* completely legitimate while doing
  nothing real. The only confirmed-reliable way to read or write the actual
  production database is through an n8n workflow node using the real
  `Postgres account` credential. Verify which database you're actually
  touching (`inet_server_addr()`) before trusting any "confirmed" result,
  including everything earlier in this document written before this was
  discovered.
