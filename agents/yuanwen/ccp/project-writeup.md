# project-writeup.md — turning a completed build into a 6-point CCP writeup

Reusable routine for producing a structured, evidence-ready writeup of a
completed piece of work. **Bucket-agnostic** — works for any of the five
TSC buckets (DE, DA, GenAI, Gov, ETS), not just Data Engineering. Distinct
from `session-log-intake.md`: that file turns confirmed hours into log
rows; this file produces the narrative evidence that sits behind those
hours. Read `ccp-bucket-classification.md` first regardless — its bucket
table (§2) is what section 1 below pulls from, and what section 4/5's
content ultimately has to map onto for logging.

## Trigger

YW says something like "write up X for CCP," "give me the 6 points," or
asks for a structured summary of a build/project session (this session or
a past one, reconstructed from memory/vault docs the same way Path B of
`session-log-intake.md` works).

## Before writing: identify the bucket(s)

Classify the work against `ccp-bucket-classification.md` §2's table first
— DE, DA, GenAI, Gov, ETS, or a split across several. This isn't a DE
writeup by default; the bucket(s) actually touched determine what
"principles" means in section 1. A GenAI-heavy project's principles look
like prompt design/AI-assisted workflow patterns; a Gov-heavy project's
look like access-control/compliance framing; an ETS project's look like
evaluation criteria and POC methodology. Don't default to DE language just
because it's the most familiar frame — use whichever bucket(s) the
classification actually surfaces, per the same judgment rules (split
freely, surface Gov/ETS deliberately) as the rest of this room.

## The 6 sections (fixed structure, always in this order)

1. **Key [bucket] principles** — the principles actually applied, drawn
   from whichever TSC bucket(s) the work maps to (per the step above) —
   not a generic list, and not defaulted to DE. If the work spans multiple
   buckets, name principles per bucket.
2. **Business problem** — what was broken, manual, or risky before. Ground
   it in the actual prior state, not a hypothetical.
3. **Proposed process + application** — the redesign, with each design
   choice explicitly tied back to a principle from section 1, whichever
   bucket(s) apply.
4. **Expected business impact** — numerical targets. Always flag these as
   estimates, never as measured results, unless a real before/after number
   exists.
5. **Implementation** — what was actually built, concretely — not a
   restatement of section 3's design.
6. **Evaluation** — what was tested/confirmed, what regressions or
   limitations were found, what's still unverified or not yet live.

## Style rules

- 3–5 bullets per section, no more.
- Terse. Sacrifice full grammar for brevity when asked to keep it short —
  this is evidence content, not prose for its own sake.
- One hour estimate per section (see below), one combined total at the
  end.
- If the writeup covers more than one project, split the hour estimate by
  project *within* each section rather than only totaling per section —
  keeps each project's real weight visible.

## Hour estimates — rules

- Same standing rule as the rest of this room: **never** derive hours from
  message timestamps — tested and ruled out directly, see
  `session-log-intake.md`.
- Estimates here are **scope-based** (build complexity, section by
  section), not time-tracked. Always flag as rough/estimate.
- Lean low when unsure — the under-claim rule from
  `ccp-bucket-classification.md` §2 rule 4 applies here too. This writeup
  is a starting point for the log, not the log itself.
- Hours should map cleanly to the bucket(s) identified in the "before
  writing" step, so they carry straight into the intake routine's
  Bucket(s) column without re-classifying from scratch.

## After the writeup

This produces narrative evidence, not logged hours. Once YW confirms/
adjusts the hour estimates, hand them to the normal intake routine in
`session-log-intake.md` — bucket classification, log-table rows, the
usual output format from `ccp-bucket-classification.md` §3.

## See also

`worked-example-project-writeup.md` — the 2026-07-17 instance of this
routine, covering the Equinix Quotations + PO-Invoicing flows (a DE/Gov/
GenAI split), as a concrete reference for format and tone.
