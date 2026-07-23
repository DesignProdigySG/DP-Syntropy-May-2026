# Channel-Mix Exploration — Design & Implementation Plan

> **What this is:** the design for the MMM's missing causal ingredient — a small
> randomized "explore" arm on channel assignment. It is the capstone that turns
> the channel model from *correlational* (what `mmm_regression.py` fits today,
> with the caveat baked into its own report footer) into *causal*.
> **Status (2026-07-22):** designed + argued via simulation (`mmm/exploration_sim.py`).
> Phase 2 (assignment hook) built + tested in the Brief Approval Handler **draft**
> (awaiting user publish from the n8n UI); `app_config` keys added live (off).
> Phase 3 **done**: `--explore-only` causal fit in `mmm_regression.py`, the
> `mmm_account_action_mix_explore` view (applied live), and the exploration
> readout on both dashboards. What remains is turning it on (publish + set
> `channel_explore_enabled='true'`) and letting traffic accumulate.

---

## 1. The problem in one paragraph

The MMM answers "which channels move the objective?" by regressing `objective_met`
on the channel-mix counts in `mmm_account_action_mix`. But channels are chosen by
the AI recommender / templates / reps — **never at random**. Account quality
confounds channel choice: a channel that reps lavish on already-promising accounts
looks like a winner even if it does nothing. The regression can't see account
quality, so it credits the channel. `mmm_regression.py` already flags this in its
footer: *"correlational, not causal… for causal answers, randomize a holdout
channel per campaign once volume allows."* This plan builds exactly that.

## 2. The proof it matters (already done)

`mmm/exploration_sim.py` builds two synthetic worlds and fits the **same logistic
model the live MMM uses** on each. Verified result (n=6000, ε=0.30, seed 42):

| channel | true OR | exploit-only (today) | explore-only (this plan) |
|---|---|---|---|
| email | 1.35 | 1.25 ✓ | 1.25 ✓ |
| linkedin_engage | 1.73 | 1.67 ✓ | 1.48 ✓ |
| phone | 2.12 | 1.85 ✓ | 1.77 ✓ |
| **ads** | **1.00** | **2.01, p<0.001 — SPURIOUS "winner"** | **0.98, p=0.69 — correctly null** |
| content_download | 1.42 | 1.34 ✓ | 1.31 ✓ |

The headline: exploit-only data confidently names **ads a top-2 channel** when its
true effect is zero — because reps ran ads on accounts that were already going to
convert. The explore arm clears it. The demo passes across seeds 1/7/13/42/99.
**Sensitivity finding:** at n=6000, ε=0.15 fails (explore arm too small to reach
significance); ε≥0.20 passes — so the exploration budget must be large enough that
the explore-only arm actually reaches MMM readiness. See §6.

## 3. Why it fits the existing architecture (minimal new surface)

The hooks already exist — this is mostly wiring, not new infrastructure:

- **`actions.channel_source`** (and the cadence-steps equivalent) already carries
  `template` / `ai`. Add one value: **`explore`**. No column change.
- **`dashboard_channel_source_performance`** already groups outcomes *by*
  `channel_source` — so explore-vs-exploit comparison is half-built.
- **`app_config`** is the established knob table (e.g. `recommendation_expiry_days`).
  Add the exploration parameters there.
- **Brief Approval Handler** is the single place the channel plan is set — one
  insertion point for the whole feature.
- **`channel_reco_reason`** is a free-text audit column — reuse it to record the
  random draw + ε for every explore action (full auditability).

## 4. The mechanism

After the AI channel plan is produced in the Brief Approval Handler, for each
action/cadence step:

```
draw u ~ Uniform(0,1)
if funnel_stage in channel_explore_stages AND u < channel_explore_epsilon:
    channel      = uniform pick from ALLOWED_CHANNELS[funnel_stage]
    channel_source   = 'explore'
    channel_reco_reason = 'explore: eps=<e> drew <channel> (overrode ai pick <x>)'
else:
    keep the AI/template channel   (channel_source unchanged: 'ai'/'template')
```

`ALLOWED_CHANNELS[stage]` = the same per-stage channel menu the templates already
use, **minus** anything in `app_config.approval_required_channels` (today
`phone,partner`) so exploration never silently triggers a human-approval channel.

## 5. New config (app_config)

| key | example | meaning |
|---|---|---|
| `channel_explore_epsilon` | `0.2` | fraction of actions assigned a random channel |
| `channel_explore_stages` | `aware,engaged` | stages exploration is allowed in (keep it out of late/high-stakes stages) |
| `channel_explore_enabled` | `true` | global kill-switch |

All read at assignment time, so ε can be tuned or killed with a single row update —
no redeploy.

## 6. Guardrails (the honest engineering)

1. **Never explore into approval-required channels** — subtract
   `approval_required_channels` from the sampling menu.
2. **Stage-gate it** — exploration belongs in early stages (`aware`, `engaged`)
   where a suboptimal touch is cheap; keep it out of `qualified`.
3. **Budget floor** — the explore arm only pays off once it has enough labeled
   rows to fit (the sim shows ε=0.15 was too thin at n=6000). Rule of thumb: pick ε
   so that `ε × expected monthly actions` clears the MMM readiness gate
   (≥30 labeled rows, ≥10 minority) per explored stage in a reasonable window.
4. **Kill-switch + full audit** — `channel_explore_enabled=false` stops it
   instantly; every explore decision is logged in `channel_reco_reason`.
5. **Client-scoped** — respect multi-tenancy; a client can be opted out by
   config if they don't want randomized touches.

## 7. The causal payoff in the model

Add an `--explore-only` mode to `mmm_regression.py` that fits on just
`channel_source='explore'` rows — an unconfounded, causal estimate — and keep the
existing all-rows fit alongside it. The dashboard MMM tab can then show both:
"correlational (all data)" vs "causal (explore arm)". Feed the **causal** winners
back into the Channel Recommendation AI's system prompt.

## 8. Dashboard

Extend the existing `dashboard_channel_source_performance` into an **Exploration**
tile: explore-vs-exploit outcome rate, explore-arm size, and how fast exploration
is filling each stage's MMM readiness gate.

## 9. Build order (≈1.5 weeks)

1. **Day 1** — this doc + add the three `app_config` keys.
2. **Days 2–4** — the assignment hook in Brief Approval Handler (+ guardrails,
   `channel_source='explore'`, audit into `channel_reco_reason`). Test on a
   synthetic account exactly like the Level 1 proof.
3. **Days 5–7** — `--explore-only` mode in `mmm_regression.py`; keep both fits.
4. **Days 8–9** — Exploration dashboard tile; present using the
   `exploration_sim.py` result as the "why".

## 10. Honest scope note

ε-greedy is the right tool for this data scale and timeframe. The textbook
version is a **contextual bandit** (e.g. Thompson sampling) that shrinks
exploration as it learns and conditions on account features — the natural next
step, but over-engineering at pre-/low-traffic volume. ε-greedy delivers the same
causal variance the MMM needs without the machinery. Note it as future work; don't
build it now.

---

### Files
- `mmm/exploration_sim.py` — the simulation that proves the argument (run it).
- `mmm/exploration_sim_report.md` — a saved run for the deck.
- `mmm/mmm_regression.py` — the live model this feeds; add `--explore-only` here.
