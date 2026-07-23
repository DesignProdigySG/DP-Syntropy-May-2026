# CaP Methodology

## What CaP is

CaP (Context as a Product) is the verification-to-context engine sitting between raw intelligence sources and downstream execution engines (WHEN Layer and delivery engine). It independently pulls, cleans, and verifies raw intelligence so that everything downstream acts on a trustworthy foundation.

## The IPO to IRO shift

Traditional AI systems operate as Input → Process → Output (IPO): data goes in, gets processed, output comes out, and context is a passive funnel that disappears after use.

CaP operates as Input → Reasoning → Output (IRO): context is the active, operational governance layer. It doesn't just pass data through — it reasons about whether the data is trustworthy, whether it conflicts with other data, what it should be used for, and whether it's still valid. Context persists and compounds rather than being consumed once and discarded.

## Defensibility as the primary quality metric

CaP does not optimize for volume of data or speed of output. It optimizes for defensibility — the ability to justify every fact and every conclusion if questioned. Defensibility has four components:

1. **Transparent assumption articulation** — every inferred (Type B) fact states what it's inferred from
2. **Explicit trade-off acknowledgement** — conflicts and gaps are surfaced, not hidden
3. **Clear prioritisation logic** — every fact has a stated intended use; nothing exists without a reason
4. **Accountability ownership** — every dossier has a named Context Director responsible for what's released

## The 80% rule

CaP does not dump data. The rule: only put information into context files if you know exactly why it is there and how it will be used. This is enforced structurally — every fact requires an `intended_use` classification before it can be saved (account_qualification, buying_committee_mapping, conversation_prep, gap_identification, timing_signal). If a piece of information doesn't cleanly map to one of these, it shouldn't be in the system yet.

The name "80% rule" reflects the threshold: facts at 80% confidence or above are treated as reliable enough to use without human re-confirmation. Below 80%, a human (sales rep or Context Director) must confirm, edit, or reject before the fact is trusted.

## Fact lifecycle

Every fact moves through stages:

1. **Collection** — an agent or human ingests a raw signal from a source
2. **Classification** — assigned Type A (verified from named source), B (inferred), C (third-party unverified), or D (known gap)
3. **Confidence scoring** — 0–100, reflecting how certain CaP is in the fact's accuracy
4. **Human gate (if confidence < 80%)** — sales rep or Context Director confirms, edits, or rejects
5. **Deconfliction** — checked against other facts for contradictions, duplicates, or staleness
6. **Director Gate 2** — Context Director reviews defensibility status before release
7. **Output** — compiled into the orientation artifact (.md file) and pushed to the shared repo

A fact that is rejected does not loop back into the queue. Rejection is final and logged in the rejection history.

## Two gates, two owners

**Gate 1 (data quality)** — checklist-based, verifies structural completeness: sources named, valid_until dates set, no duplicates, gaps logged.

**Gate 2 (defensibility)** — calculated live from actual data: percentage of facts still pending confirmation, ratio of open to resolved conflicts, whether stale/duplicate facts have been compacted, and whether an accountable Context Director is assigned. Gate 2 is never hardcoded — it reflects the true current state of the account's data.

Both gates are owned by the Context Director, not by any downstream engine.
