# Hon Lam's Pipeline — Open Questions to Figure Out

*Written 2026-07-23. Based on a read-through of `agents/hon-lam/Pipeline Automation/`.*

---

## 1. Where does Jocelyn's work overlap with Hon Lam's?

Jocelyn owns the **WHEN engine / RE:AI** (`when-layer-engine-rebuild.onrender.com`) — the upstream intelligence layer that detects accounts worth pursuing and writes account briefs. Hon Lam's pipeline is *downstream* of that: it receives those briefs, runs them through approval, campaigns, and measurement, and sends signals back.

The integration is half-built and has two specific gaps:

**Gap 1 — Inbound (WHEN → pipeline): wireable now, not yet wired.**
The WHEN engine's Settings page has an "Integrations → Webhook URL" field. Setting it to `https://designprodigy.app.n8n.cloud/webhook/delivery-layer` is all it takes for the WHEN engine to push briefs directly into Hon Lam's pipeline. This hasn't been done yet.

**Gap 2 — Outbound feedback (pipeline → WHEN): blocked on Jocelyn's side.**
Hon Lam's pipeline is designed to send engagement events and human rejections back to the WHEN engine so it can re-score accounts. The send-side is fully built; `when_engine_url` in Supabase `app_config` is the one switch that turns it on. But it can't be set yet because the WHEN engine has **no inbound endpoint** to receive those signals. Jocelyn needs to add a feedback intake URL first.

**Specific things to align between them:**

- **Brief JSON field paths** — the pipeline reads `when_urgency`, `when_stage`, `cap_archetype`, `cap_confidence`, and coverage counts from the brief payload, but the exact JSON paths haven't been pinned down against what the WHEN engine actually outputs. Needs a quick mapping session.
- **Stable account identifier** — today correlation is done by account *name*, which is fragile. Jocelyn's engine should ideally send a `brief_id` or `account_id` the pipeline can echo back.
- **`buying_group[].status = "CONFIRMED"`** — this value in the brief payload is what triggers Salesforce lead creation. Jocelyn needs to know it's functional, not cosmetic.
- **Auth** — the inbound webhook is currently unauthenticated. Once real briefs flow, both sides need a shared secret or HMAC scheme.
- **Feedback payload shape** — Hon Lam currently echoes the whole brief back with signals appended (`human_signals[]`). A compact delta `{ brief_id, new_signals: [...] }` would be cleaner. Worth agreeing on before the loop is turned on.

---

## 2. Real cases and real data to test Hon Lam's workflows on

**There are already 4 real briefs sitting in the pipeline, unprocessed:**
- Brief 422 — Daiichi Sankyo
- Brief 423 — Fusic
- Brief 424 — SMBC
- Brief 425 — Komatsu

These are waiting for approval. The approve links work (fixed 2026-07-09) — they can be re-clicked from the dashboard or from the emails. Caveat: **the n8n execution quota is currently over** (as of 2026-07-23), so nothing will process until it resets or the plan is upgraded. This needs to be checked before attempting any live test.

**The real bottleneck for end-to-end testing is contact enrichment.**
Most buying-group members in existing briefs are role placeholders ("Group CEO", "VP Operations") with no email address. Nothing real can be sent until actual names and emails are filled in. Options:
- Apollo or Clay (paid but fast)
- LinkedIn Sales Navigator lookup (manual)
- Ask Jocelyn/WHEN engine side — the engine may have enriched contacts already

**For measurement testing specifically:**
- GA4: click a tracked link from an approved action and confirm the visit shows in GA4 Realtime (property `399321337`). This is the Level 2 proof that already worked once — just needs repeating with a real brief.
- Calendly: point the `invitee.created` webhook at `/webhook/calendly` and book a test meeting. This was proven via replay; doing it with real Calendly push closes the last gap.
- Email: Smartlead API key is the unlock. 14-day free trial, paste the key into `app_config.smartlead_api_key`, and the pipeline auto-creates campaigns. First real ESP event would close the last Level 2 source.
- LinkedIn: HeyReach free trial + one webhook per event type → `/webhook/linkedin`. First real event should be sanity-checked against `engagement_events` because HeyReach's payload field names aren't publicly documented.

**Demo mode exists if you just need the dashboards to look alive:**
`supabase/demo_seed.sql` loads ~300 synthetic labeled campaigns. Always flag it as synthetic when showing anyone.

---

## 3. Other things worth figuring out

**n8n execution quota is over right now.**
Everything is wired and ready but the automation brain is effectively paused. Check whether the quota resets soon or needs a plan upgrade before scheduling any live test.

**The whole stack runs on personal accounts — this is the #1 blocker before real clients.**
n8n, Supabase, GA4, Gmail, and AWS S3 are all under Hon Lam's personal accounts. `RE_HOME_RUNBOOK.md` has the per-platform transfer steps. This should happen before any client data flows through, not after.

**The Pipeline Heartbeat workflow is built but unpublished.**
It monitors whether the 24 scheduled workflows are still active and alerts on silent deactivation — exactly the failure mode that broke the system silently in June. It's ready to go; just needs the n8n API key configured in Settings, then publish + attach Error Workflow. Worth doing before handing off to anyone else.

**The "shared" dashboard's read-only lock is cosmetic.**
`pipeline-control-tower-shared.html` disables the Settings inputs in HTML, but it embeds the same Supabase anon key and the `saveSettings()` function is still in the file. Anyone with dev tools can still rewrite `app_config`. Fine for internal use, not fine if the link goes to a client. Worth knowing before sharing the URL more widely.

**MMM track is built but waiting on real traffic.**
The foundation (per-campaign objectives, daily status job, training dataset view) is live. The regression scaffold (`mmm/mmm_regression.py`) exists. Nothing meaningful will come out of it until there's real traffic volume. Keep an eye on the readiness tile on the dashboard — it will show when there's enough data to run it.

**Three API keys are wired and just need to be pasted in:**
- `smartlead_api_key` — email automation + closes the last Level 2 measurement source
- `heyreach_api_key` — LinkedIn capture
- `when_engine_url` — closes the feedback loop back to Jocelyn's engine (blocked on her side first)

All three can be set from the dashboard Settings tab, no redeploy needed.
