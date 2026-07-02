# CaP Global Crawl Spec
*Owned by: Context Director (Tabita) · Applies to: all account crawls*

This is the brief CaP runs against before crawling any account. Every signal pulled must map to one of the five categories below and one intended_use type. If a signal doesn't fit, it doesn't enter the system.

---

## The rule before crawling

Before pulling any data, answer two questions:
1. Which of the five signal categories does this belong to?
2. Which intended_use does it enable downstream?

If you can't answer both clearly, don't pull it.

---

## Signal categories and what CaP pulls

### 1. Company level → `account_qualification`
What it answers: is this account worth pursuing at all?

Pull:
- Latest annual or quarterly revenue and YoY growth rate
- EBITDA or profitability signal (publicly stated)
- Headcount and company size
- Industry classification and HQ location
- Recent strategic announcements (expansion, new market entry, stated priorities)
- Any public financial guidance for the next cycle

Do not pull:
- General company history or founding story
- Product descriptions unrelated to AI or technology decisions
- Market share estimates from unverified aggregators

---

### 2. Technology signals → `account_qualification` or `conversation_prep`
What it answers: how digitally mature is this account, and where are the pain points?

Pull:
- Stated AI or digital transformation initiatives (named, with timeline if possible)
- Cloud or infrastructure mentions in earnings calls, press releases, or job postings
- Technology budget or R&D spend signals (publicly stated)
- Any stated pain points from executive interviews or earnings commentary
- Job postings that reveal technology stack or capability gaps (e.g. hiring for GPU infrastructure = active build)

Classify as `account_qualification` if it signals whether the account is a viable target.
Classify as `conversation_prep` if it gives a rep something to reference in a call.

Do not pull:
- Generic "we are investing in AI" statements with no specifics
- Technology mentions from Tier 3 sources without corroboration

---

### 3. Vendor signals → `conversation_prep`
What it answers: what are they already buying, and where might we fit or displace?

Pull:
- Named technology vendors or partners (publicly announced partnerships, case studies, press releases)
- Contractor or outsourcing relationships relevant to AI or infrastructure
- Any competitor product mentions in public statements or job postings
- Named platforms or tools referenced in earnings calls or executive interviews

Do not pull:
- Vendor relationships inferred without a named source
- Competitor mentions that are speculative or from forums

---

### 4. People signals → `buying_committee_mapping`
What it answers: who do we need to reach, and in what role?

Pull:
- CEO, CFO, COO names and current titles (verified from company website or official newsroom)
- CTO, Head of Technology, or IT decision-maker if publicly identifiable
- Any recent executive changes — joins, departures, promotions, role changes
- Executive public statements on AI, technology, or workforce strategy (attributed, named)
- Persona signals: what does this person care about publicly (conference talks, interviews, LinkedIn activity)

Do not pull:
- Contact details from unverified aggregators (e.g. scraped email lists)
- Inferred org chart positions without a named source
- Profiles that haven't been updated in over 6 months without verification

---

### 5. Trigger signals → `timing_signal`
What it answers: is now the right time to approach, and what is the window?

Pull:
- Upcoming or recent earnings announcements
- Leadership changes (new CTO, new CEO — creates a decision window)
- Layoffs or workforce restructures (signals cost pressure or transformation)
- New product launches or platform announcements
- Strategic partnership announcements
- Conference appearances or speaking engagements by key executives
- Regulatory filings that signal a direction change
- Any public statement with a named timeline ("by end of FY2026", "within 18 months")

Do not pull:
- General industry trend articles not specific to the account
- Trigger signals older than 90 days unless still actively relevant

---

## Intended_use mapping

| Signal category | Primary intended_use |
|---|---|
| Company level | account_qualification |
| Technology signals | account_qualification or conversation_prep |
| Vendor signals | conversation_prep |
| People signals | buying_committee_mapping |
| Trigger signals | timing_signal |

One fact, one intended_use. If a fact seems to fit two, assign it to the one that determines its primary downstream action.

---

## Confidence at intake (by type)

| Fact type | Starting confidence | Review threshold |
|---|---|---|
| A — Verified from named primary source | 95% | Auto-cleared if ≥ floor |
| B — Inferred / synthesised | 70% | Almost always goes to review |
| C — Third-party, unverified | 55% | Always goes to review |
| D — Known gap | Not scored | N/a |

## Review thresholds (by intended_use)

| Intended_use | Threshold to auto-clear |
|---|---|
| buying_committee_mapping | 85% |
| conversation_prep | 85% |
| account_qualification | 75% |
| timing_signal | 75% |
| gap_identification | N/a |

If confidence < threshold for that intended_use → goes to sales rep review before it can be used.

---

## What CaP explicitly does not pull

- Any signal without a named, traceable source
- General background or history not relevant to the sale
- Competitor comparisons unless directly stated by the account itself
- Any signal that cannot be assigned a clear intended_use
- Signals from Tier 3 sources used alone (forums, unverified aggregators, scraped data)
- Anything older than the valid_until window for that fact category without re-verification

---

## Who owns this spec

The Context Director owns this document. Any change to the signal categories, intended_use mapping, or confidence thresholds requires a Context Director decision and a version update to this file. Agents running crawls must check this spec before starting. This is not optional.

---

## Known gaps in the current crawl (as of June 2026)

The following signal types are on the list but not yet reliably sourceable independently:
- Vendor signals (no public partnership data found for Recruit Holdings)
- IT/procurement decision-maker below C-suite level (no public source identified)
- Technology stack specifics beyond what appears in job postings

These are logged as Type D gaps in the fact ledger, not omitted silently.
