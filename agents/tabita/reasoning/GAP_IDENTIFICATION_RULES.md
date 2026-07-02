# Gap Identification Rules
*Owned by: Context Director (Tabita) · Auto-runs: on Issues tab open + after every new fact added*

---

## Purpose

Gaps are known unknowns — signals CaP expected to find for an account but couldn't. They are logged as Type D facts and surfaced in the Issues tab and the Output dossier so downstream engines know exactly what's missing before acting.

Gaps are not failures. They are CaP being explicit about the limits of what it currently knows.

---

## How gap detection works

After every crawl and every new fact addition, CaP checks each `intended_use` category against a defined set of expected signals. If a signal is missing from the active fact ledger, a Type D gap fact is automatically created with a specific description of what's missing and why it matters.

Gap detection does not duplicate — if a gap for the same signal already exists, it is not created again.

---

## Expected signals per category

### buying_committee_mapping
CaP expects to find named individuals for the following roles. If any are missing, a gap is logged.

| Expected signal | Gap logged when missing |
|---|---|
| CEO or President | No CEO or President identified at this account |
| CFO or Finance Director | No CFO or Finance Director identified at this account |
| CTO, IT Director, or technology decision-maker | No CTO or IT/technology decision-maker identified at this account |
| Procurement or technology budget owner | No procurement or technology budget owner identified at this account |

**Why these matter:** Without a named buying committee, outreach cannot be targeted. A gap here means CaP cannot support activation for this account until the contact is found.

---

### account_qualification
CaP expects to find signals that determine whether the account is worth pursuing. If any are missing, a gap is logged.

| Expected signal | Gap logged when missing |
|---|---|
| Revenue or financial size | No revenue or financial size signal found for this account |
| YoY growth direction | No YoY growth signal found for this account |
| Headcount or company size | No headcount or company size signal found for this account |
| AI, R&D, or technology spend | No AI or technology budget signal found for this account |

**Why these matter:** Without qualification signals, CaP cannot assess whether this account fits the target profile for Singtel's Japan AI/GPUaaS expansion.

---

### conversation_prep
CaP expects to find at least one named executive statement and one known technology signal. If either is missing, a gap is logged.

| Expected signal | Gap logged when missing |
|---|---|
| Named executive public statement on AI or technology | No named executive public statement on AI or technology found for this account |
| Known technology vendor, platform, or infrastructure signal | No known technology vendor or platform identified for this account |

**Why these matter:** Without these, a sales rep cannot open a conversation with something specific and credible. Generic outreach without a signal hook has significantly lower response rates.

---

### timing_signal
CaP expects to find at least one recent trigger event. If any category is missing, a gap is logged.

| Expected signal | Gap logged when missing |
|---|---|
| Workforce restructure or cost-cutting event | No workforce restructure or cost-cutting signal found in the last 90 days |
| Earnings or financial reporting event | No recent earnings or financial reporting event found |
| Strategic announcement, partnership, or product launch | No recent strategic announcement or trigger event found in the last 90 days |

**Why these matter:** Timing signals determine whether now is the right window to approach. Without them, The Read cannot assess urgency or sequence outreach appropriately.

---

## Gap lifecycle

1. **Auto-created** — CaP creates the Type D fact automatically when a signal is missing
2. **Surfaced** — appears in Issues tab (Gaps section) and in the Output dossier (Known gaps section)
3. **Resolved** — when a new fact is added that covers the missing signal, the gap is implicitly resolved on the next gap check run (it will not be re-created)
4. **Never deleted** — gaps are part of the audit trail; even resolved gaps remain in the ledger as a record of what was unknown at a given point in time

---

## What gap detection does NOT do

- It does not guess or infer to fill a gap — if a signal is missing, it stays missing until a real source is found
- It does not create a gap for Type D facts that already exist with the same description
- It does not flag gaps for signals that exist but are below confidence threshold — those go to sales rep review, not the gap log
- It does not apply to accounts with no active facts yet — gap detection only runs when there are facts to check against

---

## Adjusting the gap spec

The expected signals above are the current global defaults for B2B enterprise accounts in the Singtel Japan AI/GPUaaS context. If a new account type requires different expected signals, the gap spec should be updated in the platform code and this document revised to match.

Who owns updates: Context Director.
