# Go-Live Checklist — from working prototype to client-facing pipeline

*Written 2026-07-09. Current state: end-to-end verified with mock leads (brief → approval → campaign → Salesforce → cadence → AI drafts → digest). Both measurement feeders are tool-ready and probe-tested. The feedback half (measurement → adaptive engine → opportunities) is built and tested but has never seen real data. Everything below is ordered — each phase unblocks the next.*

---

> **Update 2026-07-10 — most of this is now one form.** Per-client setup collapsed to: (1) client fills `dashboards/onboarding.html` (needs the setup code, ask DP) → sets their notification email + records the engagement; (2) DP pastes a Smartlead API key into `app_config.smartlead_api_key` once → the nightly **Tool Campaign Provisioner** auto-creates one Smartlead campaign per email action, correctly named, webhook attached — no manual naming convention. Items below marked ✅ are done.

## Phase 1 — Flip the switches (minutes, $0, do first)

- [x] **1.1 Set `rep_notification_email`** — ✅ DONE 2026-07-10 (set to chiahonlam.school@gmail.com via the onboarding flow test). Approved-action emails are live. Change it anytime via the dashboard Settings tab or the onboarding form.
- [ ] **1.2 Clear the pending brief backlog** — briefs 422 (Daiichi Sankyo), 423 (Fusic), 424 (SMBC), 425 (Komatsu) are waiting. The approve links work now (fixed 2026-07-09) — re-click them from the dashboard/emails.
- [ ] **1.3 Verify GA4 tag on dp.sg** — `tracking_base_url` is set to `www.dp.sg`, and the GA4 feeder (property 542471069) is healthy, but tracked URLs only produce `page_visit` events if the pages actually exist and carry the GA4 tag. Click one tracked URL and confirm the session shows in GA4 Realtime.
- [ ] **1.4 Delete two orphan test Campaigns in sandbox Salesforce** — `701d500000XLPtFAAX`, `701d500000XLSj3AAH` (left over from the 2026-07-09 mock-lead test; harmless but untidy).

## Phase 2 — Real contacts (the actual bottleneck)

- [ ] **2.1 Enrich buying-group contacts** — most buying-group members are role placeholders marked "Needs enrichment" with no email. Nothing real can be sent until this is done. Options: Apollo/Clay (paid), LinkedIn Sales Navigator lookup (manual), or ask WHEN-engine side to export contacts. Store emails back into the brief's `buying_group`.
- [ ] **2.2 Upgrade Salesforce Lead dedup** — once contacts have emails, switch the Lead sync's FirstName+LastName+Company SOQL match to a native email upsert (cleaner, race-free). Optional but cheap once 2.1 is done.

## Phase 3 — Connect the external tools (feeders are ready and waiting)

- [ ] **3.1 Smartlead (email)** — start the 14-day trial (no card), then just paste the API key into `app_config.smartlead_api_key`. The nightly **Tool Campaign Provisioner** (05:35 UTC) creates one correctly-named Smartlead campaign per email action with the engagement webhook pre-attached — no manual setup. ⚠ Watch the first provisioning run: the Smartlead API field shapes are doc-derived and unverified until a real key exists.
- [ ] **3.2 HeyReach (LinkedIn)** — trial, then Integrations → Webhooks: one webhook per event (Connection Request Accepted, Every Message/InMail Reply Received, Viewed Profile, Liked Post) → `https://designprodigy.app.n8n.cloud/webhook/linkedin`. Campaign name = action's `utm_campaign`. **Sanity-check the first real event** against `engagement_events` — HeyReach's payload field names aren't publicly documented; unmapped events return 200 and are silently dropped (no retry).
- [ ] **3.3 Calendly (meetings)** — point the Calendly `invitee.created` webhook at `/webhook/calendly`. `meeting_booked` is the strongest success event in every reply objective.
- [ ] **3.4 $0 fallback (demo week)** — if trials aren't running: reps send from Gmail/LinkedIn manually, clicks flow via dp.sg → GA4, replies via Gmail, LinkedIn accepts/replies via `quick-log.html`. The pipeline works identically, just with manual event capture.

## Phase 4 — Run the daily loop with a real rep (1–2 weeks)

- [ ] **4.1 Rep works from the daily digest** ("Your N touches") + dashboard My Day tab: approve/execute touches, use the AI outreach drafts, log soft signals via quick-log.
- [ ] **4.2 Watch the 06:00–08:30 UTC morning chain do its job**: outcome measurement (06:00) → adaptive engine stop/pause/escalate (06:15) → opportunity offers on goal_met (06:45) → SF task outcome sync (07:00) → objective status (07:30 pg_cron) → heartbeat (08:30). First real engagement events will light all of this up for the first time.
- [ ] **4.3 Verify one full win path**: engagement → objective met → Opportunity offer email → human approve → Opportunity appears in Salesforce. That's the complete story for a client demo.

## Phase 5 — Production hardening (before real client data flows)

- [ ] **5.1 Secure the feeder webhooks** — `/webhook/email-events`, `/webhook/linkedin`, `/webhook/engagement`, `/webhook/calendly` are currently unauthenticated; anyone with the URL could inject fake engagement and trigger the adaptive engine. Add a shared-secret header check (Smartlead/HeyReach support custom headers) or at minimum keep URLs private. Fine for prototype, not for client data.
- [ ] **5.2 Salesforce: sandbox → production org** — everything currently writes to the isolated Developer Edition org ("Salesforce account 2") by design. Moving to the real org is a business decision + credential swap; never repoint at the old "Salesforce account" credential without authorization.
- [ ] **5.3 Transfer platform ownership** — n8n, Supabase, GA4, Gmail, AWS S3 all run under personal accounts. `HANDOFF.md` has the per-platform transfer steps. Do this before anyone else operates the pipeline.
- [ ] **5.4 Root-fix the Supabase default-ACL rule** — new tables/views still auto-grant full CRUD to anon (has bitten 3×). One `ALTER DEFAULT PRIVILEGES` fixes it forever.
- [ ] **5.5 Set `when_engine_url`** when the WHEN engine has a live endpoint — closes the last loop (engagement + approve/reject decisions feed back to re-scoring). Until then that half stays dormant by design.
- [x] **5.6 Multi-tenancy** — ✅ DONE 2026-07-10 (hybrid tagging): `clients` registry, `client_id` inherited through briefs → campaigns → actions → engagement events via DB triggers, per-client rep email routing, `dashboard_client_overview` rollup. Onboarding form creates the client. Remaining when client #2 is real: per-client daily digest grouping, per-client tracking domain/GA4, dashboard client filter dropdown. WHEN engine should send `client_id` with briefs once multiple clients are live (untagged briefs fall to the house client).

---

**Effort summary:** Phase 1 ≈ 15 minutes. Phase 2 is the real unlock and depends on contact data access. Phase 3 ≈ 1 hour once trials exist. Phase 4 is calendar time, not work. Phase 5 ≈ half a day, only needed at the client-data threshold.
