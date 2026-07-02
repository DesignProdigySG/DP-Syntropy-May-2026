# Deconfliction Rules

## Purpose

CaP runs independently of WHEN Layer and other downstream engines. It does not wait for another system to flag contradictions in its own data — deconfliction is something CaP does to itself, on demand, against the facts it has collected.

## When deconfliction runs

On demand, triggered by a "Run deconfliction" action per account. It is not automatic on every fact insert (to avoid excessive write load), but should be run any time a meaningful batch of new facts is added, or before an account moves through Director Gate.

## The five rules

### Rule 1 — Numeric contradiction detection
Facts sharing the same `intended_use` category are scanned for shared metric keywords (revenue, EBITDA, CEO, CFO, COO, headcount, employees, R&D, guidance). If two facts reference the same keyword but assert numeric values differing by more than 5%, a conflict is logged.

Severity: differences over 20% are marked critical; 5–20% are marked moderate.

### Rule 2 — Dual Type A source flagging
If two facts are both classified Type A (verified) but come from different sources and reference the same keyword, this is flagged at low severity for cross-checking — even if the values don't numerically contradict. Two "verified" facts from different sources making the same claim should still be confirmed as genuinely consistent, not just superficially similar.

### Rule 3 — Trusted fact auto-assignment
When a conflict is detected, the fact with the higher confidence score is automatically marked as the "trusted fact" in the conflict record. This doesn't resolve the conflict — it gives the Context Director a starting point for review.

### Rule 4 — Near-duplicate detection
Facts within the same `intended_use` category are compared for content word-overlap. If similarity exceeds 70%, they're flagged as likely duplicates — candidates for compaction rather than genuine contradiction.

### Rule 5 — Stale fact detection
Any fact past its `valid_until` date is automatically flagged, regardless of whether it conflicts with anything else. Severity scales with how long it's been stale: over 90 days is critical, 30–90 days is moderate, under 30 days is low.

## Compaction

When deconfliction surfaces duplicates or stale facts, the resolution is compaction: retain the higher-tier, higher-confidence, or more recent fact and archive (not delete) the other. Compaction is never automatic — it requires Context Director review and explicit resolution via the Issues tab.

## What deconfliction does NOT do

- It does not resolve conflicts automatically. Every conflict requires a human "Mark resolved" action.
- It does not touch WHEN Layer's domain — timing, posture, and approach decisions are never evaluated by this engine.
- It does not delete facts. Stale or duplicate facts are flagged, never silently removed.
