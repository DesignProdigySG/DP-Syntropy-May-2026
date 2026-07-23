# Intelligent Automation Pipeline — Project Context & Progress Handoff

> **Purpose:** Paste or attach this file at the start of a new chat in the "DP Project" folder to transfer full context.
> **Snapshot date:** 2026-07-05. Compiled from accumulated cross-chat memory.
> **Caveat:** This is a point-in-time summary. Claims about workflow/DB behavior may have drifted — verify against the live system (n8n `get_workflow_details`, Supabase queries) and the repo's own `PROJECT_AUDIT.md` before asserting anything as current fact. The local `n8n-workflows/*.json` exports are **stale (dated 2026-06-24)** — never trust them for current behavior.

---

## 1. What the project is

**Intelligent Automation Pipeline** is a B2B lead pipeline living in the `dp-repo` folder (OneDrive-synced; **not a git repo** — no version history beyond what's narrated in `PROJECT_AUDIT.md`). It's an internship **prototype/demo**, not production — prioritize "does it work end-to-end" over hardening/deep security.

**End-to-end flow:**
1. Upstream **WHEN-layer** account briefs POST in (trigger/event detection engine, built by teammate Jocelyn).
2. Briefs get scored → turned into AI-written, human-approved sales briefs.
3. Approval triggers an auto-matched multi-step outreach **cadence**: a campaign template picks candidate steps, then an **AI channel recommender** re-plans the actual channel sequence per account.
4. Each step is a tracked **action** a rep executes manually.
5. Outcomes measured daily against a hypothesis (GA4 for web, Gmail for replies, manual `quick-log.html` for "vibes" signals like LinkedIn accepts).
6. A feedback loop routes rejections back to the WHEN engine / source teammates.

**Scope pivot (25 June):** the project removed its in-house decision layer (Criteria Setter / Disqualifier / Judge LLM nodes) and outsourced the WHO/WHEN decision to Jocelyn's external WHEN Layer engine. Intelligent Automation Pipeline's own scope narrowed to **"validate → activate → collect → report"** plus the feedback loop. **Reframed priority (29 June):** the 10-phase roadmap is secondary — the real goal is automating **Salesforce lead creation/maintenance + feedback**.

---

## 2. Platforms & key IDs

All under Hon Lam's **personal accounts** (not yet shared/team):

| Platform | Detail |
|---|---|
| **n8n cloud** | `designprodigy.app.n8n.cloud`, personal project under `Hon Lam Chia <honlamchia@gmail.com>` |
| **Supabase/Postgres** | org "Hon-Lam-Chia" (`rhlcngpiondbiqlirpbx`), project `fqsqoxsosavjhdsvfevk` (ap-southeast-2) — **source of truth** |
| **Salesforce** | one-way synced execution layer (Supabase → SF, SF never writes back except via read-back workflow). Credential **"Salesforce account 2"** (`HPnx6HXN8COY4aOe`) = dedicated Developer Edition **sandbox** org |
| **GA4 + Gmail** | `honlamchia@gmail.com`, for outcome measurement |
| **AWS S3** | `dp-pipeline-briefs` bucket, brief HTML storage |

**Canonical docs in `dp-repo` root (read in this order):**
1. `HANDOFF.md` — onboarding + access-transfer steps per platform
2. `README.md` — architecture/setup/end-to-end flow
3. `PROJECT_AUDIT.md` — full narrative changelog of every decision/bug/fix with dates (the closest thing to git history)
4. `n8n-workflows/README.md` — workflow manifest with IDs + dated wiring changelog
5. `GAP_AUDIT_2026-07-02.md` — most recent full-system gap audit

---

## 3. Key n8n workflow IDs

| Workflow | ID | Role |
|---|---|---|
| Brief Approval Handler | `AoVkLOncTxZqQlwz` | Approve brief → template match → channel reco AI → create campaign/actions/cadence |
| Action Approval Handler | `UyplqAAHgTNOvRuC` | Approve/reject action → SF Task/Lead sync, rep email, outcome record-keeping |
| Cadence Scheduler | `LcZx5U9dVmOwaGQl` | Daily; builds the rep-facing **daily digest** email |
| Adaptive Decision Engine | `tGYW1gMBXQrC3bQ6` | Daily 06:15; stop/pause/escalate rules on measured outcomes |
| Opportunity Offer | `dnGpK2weiPIcikGa` | Daily 06:45; offers SF Opportunity on goal_met |
| Opportunity Approval Handler | `er7QvTbfSkyc60wx` | Human-gated SF Opportunity creation |
| Salesforce Activities Read-back | `mL0H9QHe73SouLsR` | Daily; reads SF Tasks/Events back into engagement_events |
| Salesforce Task Outcome Sync | `PZThZtvGakw82RX8` | Daily 07:00; marks SF Tasks Completed w/ measured results |
| Digest Approve All | `mw2KJ3AOea9rhSDT` | GET /webhook/digest-approval; approve-all from digest |
| Recommendation Expiry | `qYkwb4h5riveVwNJ` | Daily 05:45; auto-rejects stale recommendations |
| Sign Link | `a8q9lmLVIxahPCTk` | POST /webhook/sign-link; server-side HMAC signing (batched) |
| Engagement Ingest | `fsPZuAbWdQb16kXm` | Webhook; POST (quick-log) + GET (digest one-click) engagement capture |
| GA4 → Engagement Feeder | `20tIbI4ku7j35dma` | GA4 pull — **failing nightly, see open issues** |
| Intelligent Automation — Delivery Layer | `HQdvWtRfLdzDTN3X` | Sends brief approve/reject emails (HMAC-signed) |
| Intelligent Automation (monolith) | `rNFL6JkvW5TxnaQv` | **Inactive, 0 executions** — legacy Gate1/Gate2 prototype, safe to archive |
| Error Workflow | `rVr68buB9TD3qR5Y` | Exists but **not attached** to scheduled workflows |

---

## 4. The 10-phase roadmap (status as of build)

Source: a 94-page consultant progress-review PDF (session upload only, not in repo).

1. **Multi-channel outreach** — DONE (linkedin_connect/engage, email, invite, landing_page, content_download, ads, webinar, phone, partner — all tracked; no SMS/WhatsApp/Slack/direct-mail)
2. **Cadences** — DONE (`campaigns` + `cadence_steps` + Cadence Scheduler)
3. **Unified engagement score** — DONE (`account_score` view, capped 100)
4. **Adaptive Decision Engine (Next Best Action)** — DONE (2026-06-29)
5. **Channel Recommendation AI** — DONE (2026-06-29)
6. **Campaign Intelligence** — PARTIAL (rollups exist; no channel→meeting→deal funnel)
7. **Multi-touch attribution** — PARTIAL (only last-touch)
8. **Playbook library** — DONE under the name `campaign_templates` (15 named templates)
9. **Content library** — NOT STARTED (only unstarted phase)
10. **AI Learning** — PARTIAL (channel leaderboard feeds the reco prompt; no real retraining)

**Net: 5 done, 4 partial, 1 not started.**

---

## 5. Chronology (how it was built)

**Weeks 4–7 (1–26 June): foundations.**
- *Wk4:* original 3-phase architecture (always-on agents → 2-gate WHO/WHEN check → sub-150-word Claude brief in S3). Gate 1 prototype + enhancements (signal decay, negative-signal detection, buying-group coverage/BGM score).
- *Wk5:* first end-to-end pipeline. n8n↔Supabase, S3, Salesforce API. Gate1→Gate2(mocked)→6-element brief→S3→Postgres. Webhook trigger, input validation, error monitor, human approve/reject email interface.
- *Wk6:* Format Adapter normalizes 3 upstream schemas. Dashboard v1 (Chart.js over Supabase views).
- *Wk7:* outcome-measurement framework (actions/outcomes tables, hypothesis format, GA4). **Major pivot (25 June):** removed in-house decision layer, outsourced to Jocelyn's WHEN engine. Multi-action "Action Engine", engagement/account-score foundation, feedback job back to WHEN.
- *26 June:* discovered the originally-connected Salesforce org was a **real populated CRM** (822 opps, ~$7.3M closed-won) — removed that sync entirely. First seed of the sandbox-only rule.

**Collaborators (external teammates, not LLM agents):** Jocelyn (WHEN layer), Tabita (Ecosystem/buying-group), Yuan Wen (Company Research), Timotheus/Junshi (persona profiling). Marc = boss/mentor.

**29 June:**
- **Phase 5 Channel Reco AI** shipped (gpt-5-mini langchain agent, JSON-mode).
- **Phase 4 Adaptive Decision Engine** shipped (stop/pause/escalate/reviewed rules).
- **Lead/CampaignMember sync** re-enabled + hardened (per-contact loop fix, field-ref fix, dedup hardened, idempotency gap closed).
- **Salesforce credential swap** — all SF nodes repointed to sandbox "Salesforce account 2".
- **Rejection taxonomy** expanded 3→6 reasons, renamed tabita/engine → source/engine_logic end-to-end.

**30 June:**
- **Salesforce Opportunity creation** (human-gated off goal_met stop rule).
- **Salesforce Activities read-back** (`salesforce_leads` mapping table + daily read-back; also covers idea #8 SMS/WhatsApp capture for free).
- **Account 360 + AI Decisions** dashboard tabs (additive-only).
- **Coworker pressure-test:** 3 real gaps found + fixed same day (template-selection audit trail via `template_match_trace`; hard/soft signal split in `account_score` fed to reco AI; SF Campaign status now updated on campaign end).
- **Functional-readiness audit:** fixed broken brief-approval HMAC signature; diagnosed empty `app_config` (tracking_base_url + when_engine_url blank).

**1 July:** HMAC secret rotation (moved signing server-side via Sign Link + `app_config.approval_hmac_secret`).

**2 July:**
- **Full gap audit** (`GAP_AUDIT_2026-07-02.md`).
- **Daily digest** rework: Cadence Scheduler now sends ONE "Your N touches for today" HTML email + Digest Approve All. Campaign-level approval (auto-approve all but `approval_required_channels`). Recommendation expiry. "My Day" dashboard tab. Logging loop (one-click outcome/quick-log links in digest & My Day).
- **SF Task outcome sync** (rec F): `actions.salesforce_task_id` now populated; daily workflow marks Tasks Completed with results.
- Sign Link fixed (batched) after it crashed under load; secret re-rotated in-database; dashboards secretless again.

---

## 6. Current live state (data)

**Pre-traffic.** As of the 2026-07-02 audit:
- `engagement_events`, `outcomes`, `salesforce_leads` — all **0 rows**.
- All 56 `cadence_steps` have `adaptive_action = null`.
- All 15 `campaigns` are active / not_offered.
- 46 recommended actions pending (30 older than 3 days, oldest 25 June).
- All `tracked_urls = https://example.com` (placeholder).
- Approved-action rep emails have **never reached a human** (rep email was placeholder, now gated blank).

The feedback/measurement half of the system has therefore never run on real data.

---

## 7. Open issues / known gaps (verify before relying on any of these)

1. **GA4 → Engagement Feeder fails every night** (since ≥28 June): Google API credential detached ("Credentials not found"). The `=`-prefix bug was fixed+published, **but the googleApi credential must be re-attached MANUALLY in the n8n UI** — MCP tools refuse to set googleApi on httpRequest nodes. May still be undone.
2. **No error workflow attached** to any scheduled workflow despite one existing (`rVr68buB9TD3qR5Y`) — failures are silent.
3. **Brief Approval Handler has no idempotency gate** — unlike Action/Opportunity handlers, a replayed/invalid brief-approval link still proceeds to create a campaign + real SF Campaign. Not yet fixed. Fix before it handles real traffic or before extending auto-approval to its step-1 actions.
4. **`rep_notification_email` is blank** → approved-action emails are SKIPPED (by design until set). The digest always sends to `honlamchia@gmail.com` fallback.
5. **`app_config.tracking_base_url` and `when_engine_url` empty** → tracked links are placeholders; reject-feedback to WHEN engine is silently dropped. Root cause of the empty engagement/outcomes tables.
6. **`Select Campaign Template` `$4` bug** — was fixed 2026-06-29 (array-literal instead of comma-joined `|| ''`), but note: it gates the ENTIRE downstream chain (campaign, channel plan, actions, cadence steps). Older seed briefs (id ≤357) with null when_urgency/when_stage would trip the old bug.
7. **`Intelligent Automation` monolith** — dead `Perform a query` SF node (disconnected, invalid `resource:"search"`). Legacy, inactive.
8. **Default-ACL leak on Supabase `public`** — `ALTER DEFAULT PRIVILEGES` auto-grants full CRUD to `anon`/`authenticated` on every NEW table/view/sequence. Bitten the project 3×; not fixed at root. Every new view needs an explicit `REVOKE ALL ... GRANT SELECT` pass.
9. **Dashboards embed a Supabase anon key in plaintext** — internal-only; RLS is the real boundary. The "-shared" read-only lock is cosmetic.
10. **No real contact emails** in buying-group data → SF Lead dedup is a manual SOQL search, not a native upsert.
11. Minor: 4 unindexed FKs; 13 unresolved `pipeline_errors` rows (mostly seed, ≥1 real).

---

## 8. Recurring gotchas (hard-won; check every time)

**n8n platform:**
- **Draft vs. active:** editing a published workflow via SDK/MCP lands in the **draft**; the live webhook keeps running the old **active** version until `publish_workflow` is called. Has caused silent regressions repeatedly — always diff draft vs. active before publishing.
- **Credential auto-assign trap (confirmed 7×):** `create_workflow_from_code` silently assigns a wrong-type-matching credential over the named one — repeatedly picked the **real-org** Salesforce credential over the sandbox one. Always re-verify `autoAssignedCredentials` and repoint via `setNodeCredential` to `HPnx6HXN8COY4aOe`. **Never** point a SF node at old "Salesforce account" (`hhgpLMFIO8Wl2Ykr`) — it holds real company data.
- **Code node `mode`:** an unset `mode` silently processes only the FIRST input item. Always set explicitly; test with 2+ items.
- **`setNodeParameter` (JSON-Pointer) on array index** silently no-ops and reports success — creates stray `parameters.parameters.*` keys. Use `updateNodeParameters(replace:true)` instead.
- **langchain chat model default text-mode:** if a downstream Code node does `JSON.parse`, set `options.textFormat.textOptions.type:'json_object'` or you'll occasionally get malformed JSON.
- **Postgres node without `=` prefix** DOES evaluate expressions (validator warning is a false positive for that node).
- **`execute_workflow` has real side effects** — it reprocessed 4 real companies once. Prefer `test_workflow` with pin data; but note `test_workflow` pins credentialed nodes and can break `pairedItem` refs (giving wrong IF-branch results — not a real bug).

**Supabase:** the default-ACL grant leak (see open issue #8) — always `REVOKE ALL ... GRANT SELECT` on new objects.

**Environment:**
- **git ops blocked on OneDrive mount:** `git init/add/commit` fail with "Operation not permitted" via sandbox bash on dp-repo — run git in the user's own local terminal.
- **bash/OneDrive mount staleness:** bash's view of OneDrive-synced files can lag behind Edit-tool writes, and the mount can go permanently stale mid-session. Trust the Read tool over bash right after an edit. For `node --check` validation, write NEW files to the outputs mount (local disk) rather than editing existing ones.

**Salesforce:** SANDBOX ONLY — never write to any org with real company data. This org has no Campaign Influence, so `Opportunity.CampaignId` isn't API-accessible (`INVALID_FIELD`); source campaign is recorded in the Opportunity `description` instead.

---

## 9. Working preferences

- Lam is an **intern**; Intelligent Automation Pipeline is a **prototype demo**, not production. Prioritize "does it work" over hardening / deep security rationale.
- Salesforce: **sandbox org only**, always.
- Lam writes his own replies/messages in his own words — investigate and report, don't auto-draft replies unless asked.
- Responses: concise and direct.

---

*End of handoff. For the authoritative narrative, always defer to `PROJECT_AUDIT.md` and live system queries.*
