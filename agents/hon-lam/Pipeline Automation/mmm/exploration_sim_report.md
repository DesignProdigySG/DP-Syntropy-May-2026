# Channel-exploration simulation — 2026-07-22

Accounts: **6000**  ·  epsilon: **0.3**  ·  explore rows: **1742**  ·  seed: 42

Same logistic model as the live MMM, fit two ways: on the confounded exploit-only data (**what we have today**) and on the randomized explore-only arm (**what the capstone adds**).

| channel | true OR | exploit-only (today) | explore-only (capstone) |
|---|---|---|---|
| email | 1.35 | OR 1.25 (p=0.000) — recovered (truth 1.35, err 7%) | OR 1.25 (p=0.000) — recovered (truth 1.35, err 7%) |
| linkediengage | 1.73 | OR 1.67 (p=0.000) — recovered (truth 1.73, err 3%) | OR 1.48 (p=0.000) — recovered (truth 1.73, err 15%) |
| phone | 2.12 | OR 1.85 (p=0.000) — recovered (truth 2.12, err 13%) | OR 1.77 (p=0.000) — recovered (truth 2.12, err 16%) |
| ads | 1.00 | OR 2.01 (p=0.000) — SPURIOUS 'winner' | OR 0.98 (p=0.693) — correctly not significant |
| content_download | 1.42 | OR 1.34 (p=0.000) — recovered (truth 1.42, err 6%) | OR 1.31 (p=0.000) — recovered (truth 1.42, err 8%) |

## Read

- **Exploit-only data is misleading**: at least one channel is mis-estimated — a true-zero channel can surface as a significant "winner" (because reps lavished it on good accounts), or a real driver gets distorted. Acting on this points reps at the wrong channel.
- **The explore-only arm recovers the truth**: every channel's estimate lands near its planted effect, and the true-zero channel is correctly *not* significant. Randomization severed the link between channel choice and account quality, so the estimates are causal.
- **Takeaway for the deck:** the MMM's recommendations are only trustworthy once an exploration arm exists. Without it the model is confidently wrong; with a small epsilon it becomes an honest guide.

_Synthetic data with planted ground truth — it proves the mechanism and the argument, not real channel results._
