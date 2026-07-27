# worked-example-project-writeup.md — 2026-07-17, Equinix Quotations + PO-Invoicing

Reference instance of `project-writeup.md`, produced live in a Cowork
session on 2026-07-17, corrected same-day after a second look surfaced an
under-named DE principle (ETL/ELT) and a missed bucket (ETS). Covers two
EQX Finance Ops Automation flows: the Quotations n8n rebuild (built this
session) and the PO-Invoicing flow (built in a prior session, 2026-07-16,
included here for comparison). Both flows span **DE + Gov + ETS**
(pipeline/dedupe work, access-control/approval gates, and tool/paradigm
evaluation) with a **GenAI** slice (agent prompt design) — a genuine
four-bucket instance, not a DE-only one. Kept verbatim as the format/tone
reference — don't edit this to "improve" it, start a new dated
worked-example file instead if the format evolves.

---

**1. Key principles (DE / GenAI / Gov / ETS)** *(both flows, ~1.5h)*
- **DE:** ETL/ELT pipeline design (extract→transform→load via n8n), idempotency/dedup, schema validation, source-of-truth separation
- **GenAI:** prompt design / AI-assisted extraction
- **Gov:** access-control/approval workflows, config SSOT
- **ETS:** tool/paradigm evaluation (Zap vs n8n; is n8n the right paradigm for DE-formal work)

**2. Business problem** *(both flows, ~1h)*
- Quotations: manual Zap, no dedupe, no traceability, race risk
- PO-Invoicing: Coupa emails manually matched/booked, dupe PO risk, no Xero draft automation
- Both: no audit trail for exception/human-review cases

**3. Proposed process + application**
- Quotations (~2h): Source Ref hard-block + Body Hash/Slack soft-gate, claim-early/fill-late write
- PO-Invoicing (~1.5h): PO# hard-block, Quote#/invoice-only soft-flag + Slack gate
- Both: judge→compute→write split (DE), sheets access-control (Gov)
- ETS (~1.5h): Zap-vs-n8n migration evaluation — read 24-step Quotations Zap in Chrome (no API/MCP shortcut exists), discovered a real defect in its AI-extraction step output shape, assessed n8n as the better-fit paradigm for DE-formal dedupe/schema work vs. Zapier's linear step model

**4. Expected business impact (targets, est.)** *(~0.5h)*
- Dupe quotes/invoices: ~0% (from unknown nonzero baseline)
- Turnaround: est. -30–50% (no manual babysitting either flow)
- Audit coverage: 0%→100% source-traceable
- Human review load: <10% of volume (only true ambiguous cases)

**5. Implementation**
- Quotations (~6h): Gmail→Router/Extraction Agent→Compute Code→Salesforce(Opp+Quote)→Docs→Gmail draft→Slack→Sheets, 2 dedupe layers, 3 new columns
- PO-Invoicing (~6h): Gmail→Agent→OK to Write? gate→PO lookup/block→Compute Ledger Row→Append→Xero draft invoice (+ contact-lookup fix, tax-code fix)
- Both kept draft/DRAFT-only, no auto-publish/auto-authorise

**6. Evaluation**
- Quotations (~2.5h): 4 test scenarios pass, 1 regression found+fixed, 2 tooling limits documented
- PO-Invoicing (~1.5h): live-tested by YW, PO#-block + Slack-gate confirmed working
- Both: not fully prod-soaked yet (Quotations still draft; PO-Invoicing live but early)

**Total est.: ~26.5h** (Quotations ~13.5h / PO-Invoicing ~10.5h / shared ~2.5h) — split roughly DE ~13h / Gov ~6h / GenAI ~4h / ETS ~3.5h — rough, sanity-checked against YW's own recall before logging.
