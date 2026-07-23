# Source QA Standards
*Owned by: Context Director (Tabita) · Read alongside: CRAWL_SPEC.md, CAP_METHODOLOGY.md*

---

## Purpose

Every fact in CaP must trace back to a source with a known credibility tier. This document defines how sources are classified, how confidence is scored at intake, how confidence decays over time, and what disqualifies a source from being used.

---

## Source credibility tiers

### Tier 1 — Primary
Company-published material, regulatory filings, government data, direct statements from named executives at official events. Tier 1 sources can support Type A facts directly. No cross-referencing required, though valid_until dates still apply.

Examples: official earnings releases, company newsroom announcements, SEC/regulatory filings, verified executive statements at named conferences (JP Morgan, Davos, etc.), official company leadership pages.

### Tier 2 — Reputable secondary
Established press, recognised analyst firms, industry research bodies. Tier 2 sources support Type B or Type C facts. If a Tier 2 source is used to elevate a fact to Type A, it must be cross-referenced against at least one other independent source first.

Examples: Reuters, Bloomberg, Fortune, Nikkei, recognised analyst reports, established industry trade press.

### Tier 3 — Third-party, use with caution
Forums, unverified aggregators, AI-generated summaries without primary citation, crowd-sourced profile sites. Tier 3 sources can only support Type C facts and must be explicitly flagged as unverified. Never used alone.

Examples: Crunchbase AI-generated bios, unverified org chart sites, social media posts from non-verified accounts, Reddit, general blog posts.

### What disqualifies a source entirely
- No identifiable author, publisher, or institution
- Content that cannot be dated or appears auto-generated without disclosure
- Sites with a history of fabricated executive data
- Any source from Tier 3 used as the sole basis for a Type A or B fact

---

## Confidence model

### Step 1 — Type sets confidence at intake

Confidence is assigned automatically when a fact is classified. No human sets this number at intake — it comes from the fact type.

| Fact type | Starting confidence | What this means |
|---|---|---|
| A — Verified from named primary source | 95% | Directly verifiable, traceable, Tier 1 source |
| B — Inferred / synthesised | 70% | Derived from signals, not directly stated |
| C — Third-party, unverified | 55% | Single source, not cross-verified |
| D — Known gap | Not scored | A gap is not a fact — it's an absence |

### Step 2 — Intended_use sets the review threshold

The intended_use of a fact determines the minimum confidence it needs to auto-clear without human review. High-stakes uses (wrong contact = wasted call) have a higher threshold.

| Intended_use | Threshold to auto-clear | Why |
|---|---|---|
| buying_committee_mapping | 85% | Wrong contact has highest cost in a sales context |
| conversation_prep | 85% | Facts used live in a call must be reliable |
| account_qualification | 75% | Revenue and firmographic signals have lower stakes |
| timing_signal | 75% | Timing is directional, not exact |
| gap_identification | N/a | Gaps are not scored |

**The rule:** if confidence < threshold for that intended_use → goes to sales rep review.

Example: a Type B fact (70%) tagged buying_committee_mapping (threshold 85%) → 70 < 85 → always goes to review. A Type A fact (95%) tagged account_qualification (threshold 75%) → 95 ≥ 75 → auto-cleared.

### Who owns moving the threshold

The Context Director owns the thresholds. They are configurable in the platform and should only be changed when there is a clear reason — not adjusted case by case per account.

---

## Confidence decay model

Confidence is not fixed after intake. It degrades as a fact ages toward its valid_until date, reflecting the reality that even a well-sourced fact becomes less reliable over time without re-verification.

### How decay works

Decay begins 30 days before the valid_until date and runs linearly to a floor of 60% at expiry.

| Time remaining | Effective confidence |
|---|---|
| More than 30 days before expiry | Full confidence (no decay yet) |
| 30 days before expiry | Decay begins — score starts sliding toward 60% |
| At expiry (valid_until = today) | Confidence floors at 60% |
| Past expiry | Fact is frozen — confidence stays at 60%, excluded from output until re-verified |

### What decay looks like in the platform

Each fact card shows a freshness indicator: a small bar that drains as the fact approaches expiry, shifting from green (full confidence) to amber (decaying) to grey (frozen). The actual confidence percentage shown already reflects the decay — no separate calculation needed from the user.

### Decay does not change the fact type

A Type A fact decaying from 95% to 78% is still Type A — the source hasn't changed, just the time-adjusted confidence in its current accuracy. If re-verified and renewed, it resets to 95%.

### Re-verification resets confidence

When a stale fact is re-verified (confirmed still accurate via the Issues tab), its valid_until date is extended and confidence resets to the original type-based starting score. If the fact is found to be no longer accurate, it is removed from active use and a new fact is collected in its place.

---

## Fact freshness (valid_until)

Every fact must carry a valid_until date set at intake, appropriate to its signal category.

| Signal category / fact type | Default valid_until | Renewal trigger |
|---|---|---|
| People signals — executive titles | 90 days | Any personnel announcement |
| Company level — revenue / financials | Until next earnings | Quarterly or annual release |
| Company level — strategic direction | 12 months | New strategy announcement |
| Vendor signals — partnerships | 6 months | Any press release or event |
| Technology signals — tech stack | 6 months | Product launch or job postings |
| Company level — headcount / org structure | 6 months | Layoffs, restructure, hiring surge |
| Trigger signals | 90 days | The trigger itself is time-bound |

Facts without a valid_until date are treated as unscored and go to review automatically.

---

## Compaction rule

When two facts assert the same claim from different sources:
- Retain the higher-tier, higher-confidence, or more recent fact
- Archive (not delete) the lower-quality fact
- If they contradict each other, log a conflict record — do not silently discard either

Compaction is never automatic. It requires Context Director review and explicit resolution via the Issues tab.

A fact past its valid_until date is frozen — it cannot be used in output until re-verified. Frozen facts are not deleted; they remain in the ledger as a record of what was known.
