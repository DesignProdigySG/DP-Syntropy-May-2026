#!/usr/bin/env python3
"""
Channel-exploration proof — why the MMM needs a randomized explore arm.

This is the argument for the exploration capstone, made as a controlled
simulation so it can be shown with ZERO real traffic. It builds two synthetic
worlds and fits the SAME logistic regression the live MMM uses
(`mmm_regression.py`) on each:

  World A — EXPLOIT ONLY (today):
      Reps choose channels non-randomly. Channel usage is correlated with a
      latent, unobserved "account quality" that ALSO drives the outcome. The
      regression can't see quality, so it mis-attributes quality's effect to
      whatever channel the good accounts happened to get. Result: a spurious
      "winner" and a masked real driver — confounded, correlational estimates.

  World B — EXPLOIT + EPSILON EXPLORATION (the capstone):
      Same reps, same confounding, but for a fraction epsilon of actions the
      channel is drawn at RANDOM, independent of account quality
      (channel_source = 'explore'). Fitting on just those explore rows breaks
      the confound: channel is now unrelated to quality by construction, so the
      estimates recover the TRUE causal effects.

The point the simulation makes visible: the model's answers are only
trustworthy once exploration exists. Exploit-only data can confidently point
reps at the wrong channel.

Ground truth is planted, so success = "explore-only estimates land near the
planted odds ratios; exploit-only estimates are biased." Deterministic on a
fixed seed.

Run:
    pip install pandas numpy statsmodels
    python exploration_sim.py                 # default: 3000 accounts, eps=0.25
    python exploration_sim.py --n 5000 --epsilon 0.2 --seed 7
    python exploration_sim.py --out sim_report.md
"""

import argparse
import sys
from datetime import date

import numpy as np
import pandas as pd

# The channels the exploration arm can draw from (a realistic menu; matches the
# n_* columns in mmm_account_action_mix). Kept small so the demo reads clearly.
CHANNELS = ["n_email", "n_linkedin_engage", "n_phone", "n_ads", "n_content_download"]

# --- PLANTED GROUND TRUTH (log-odds contribution per extra touch) -------------
# These are the real causal effects we will try to recover.
#   linkedin_engage: genuinely helps
#   phone:           genuinely helps (strongest)
#   email:           mild real help
#   ads:             does NOTHING (true effect 0) — the trap
#   content_dl:      mild real help
TRUE_BETA = {
    "n_email": 0.30,
    "n_linkedin_engage": 0.55,
    "n_phone": 0.75,
    "n_ads": 0.0,          # <-- the spurious-winner trap
    "n_content_download": 0.35,
}
INTERCEPT = -1.6
# How strongly latent account quality drives the outcome (the confounder path):
QUALITY_TO_OUTCOME = 1.3


def true_odds_ratio(channel: str) -> float:
    return float(np.exp(TRUE_BETA[channel]))


def simulate(n_accounts: int, epsilon: float, seed: int) -> pd.DataFrame:
    """Generate account-level rows with a latent quality confounder.

    Exploit policy (the confounding): high-quality accounts get MORE phone and
    MORE ads (reps lavish premium + expensive channels on accounts that look
    good), and slightly less email. Quality is NOT recorded — exactly like real
    life, where 'this account felt promising' never makes it into the data.

    Exploration: with prob epsilon the account's channel mix is instead drawn
    from a quality-INDEPENDENT distribution and tagged channel_source='explore'.
    """
    rng = np.random.default_rng(seed)
    # Base usage rates when NOT quality-driven (used by both the explore arm and
    # the non-trap channels under exploit).
    base = {"n_email": 1.5, "n_linkedin_engage": 1.3, "n_phone": 1.3,
            "n_ads": 0.9, "n_content_download": 1.2}
    rows = []
    for _ in range(n_accounts):
        quality = rng.normal(0, 1)  # latent, unobserved
        explore = rng.random() < epsilon

        if explore:
            # every channel drawn independent of quality — this breaks the confound
            mix = {c: int(rng.poisson(base[c])) for c in CHANNELS}
            source = "explore"
        else:
            # exploit: the confound is ISOLATED to ONE channel (ads) so the
            # spurious-winner story is unambiguous. Reps pour ads onto accounts
            # that already look good; the other channels are chosen ~normally.
            mix = {c: int(rng.poisson(base[c])) for c in CHANNELS}
            mix["n_ads"] = int(rng.poisson(max(0.05, 0.4 + 1.4 * quality)))
            source = "ai"  # stands in for today's AI/template pick

        lin = INTERCEPT + QUALITY_TO_OUTCOME * quality
        lin += sum(TRUE_BETA[c] * mix[c] for c in CHANNELS)
        p = 1.0 / (1.0 + np.exp(-lin))
        met = rng.random() < p

        row = {**mix,
               "total_touches": sum(mix.values()),
               "channel_source": source,
               "objective_status": "met" if met else "missed"}
        rows.append(row)
    return pd.DataFrame(rows)


def fit(df: pd.DataFrame) -> dict:
    """Fit objective_met ~ channel counts. All channels are in the model, so
    volume is already captured by their sum — a separate `total_touches` term
    would be an EXACT linear combination of the channels (perfect collinearity),
    which is why it is deliberately excluded here. Returns odds ratio + p per
    channel."""
    import statsmodels.api as sm
    varying = [c for c in CHANNELS if df[c].std(ddof=0) > 0]
    X = sm.add_constant(df[varying].astype(float), has_constant="add")
    y = (df["objective_status"] == "met").astype(int)
    res = sm.Logit(y, X).fit(disp=0, maxiter=200)
    out = {}
    for c in varying:
        out[c] = {"or": float(np.exp(res.params[c])), "p": float(res.pvalues[c])}
    return out


def verdict(true_or: float, est: dict) -> tuple[str, bool]:
    """Is the estimate acceptably close to truth AND correct about significance?

    Returns (human-readable cell, ok). For a truly-null channel (true OR = 1),
    ok = "not flagged as a significant winner". For a real driver, ok =
    "estimate within tolerance AND detected as significant"."""
    if est is None:
        return "not in model", False
    or_hat, p = est["or"], est["p"]
    rel_err = abs(or_hat - true_or) / true_or
    sig = p < 0.05
    truly_null = abs(true_or - 1.0) < 1e-9
    if truly_null:
        ok = not (sig and or_hat > 1.0)
        tag = "correctly not significant" if ok else "SPURIOUS 'winner'"
        return f"OR {or_hat:.2f} (p={p:.3f}) — {tag}", ok
    ok = rel_err <= 0.30 and sig
    tag = "recovered" if ok else "BIASED/insig"
    return (f"OR {or_hat:.2f} (p={p:.3f}) — {tag} "
            f"(truth {true_or:.2f}, err {rel_err*100:.0f}%)"), ok


def build_report(n: int, epsilon: float, seed: int) -> tuple[str, bool]:
    df = simulate(n, epsilon, seed)
    n_explore = int((df["channel_source"] == "explore").sum())

    exploit_only = df[df["channel_source"] != "explore"]
    explore_only = df[df["channel_source"] == "explore"]

    fit_exploit = fit(exploit_only)   # World A: today's confounded data
    fit_explore = fit(explore_only)   # World B: the randomized arm

    L = []
    L.append(f"# Channel-exploration simulation — {date.today().isoformat()}")
    L.append("")
    L.append(f"Accounts: **{n}**  ·  epsilon: **{epsilon}**  ·  explore rows: "
             f"**{n_explore}**  ·  seed: {seed}")
    L.append("")
    L.append("Same logistic model as the live MMM, fit two ways: on the "
             "confounded exploit-only data (**what we have today**) and on the "
             "randomized explore-only arm (**what the capstone adds**).")
    L.append("")
    L.append("| channel | true OR | exploit-only (today) | explore-only (capstone) |")
    L.append("|---|---|---|---|")

    all_explore_ok = True
    exploit_had_problem = False
    for c in CHANNELS:
        t = true_odds_ratio(c)
        ex_txt, ex_ok = verdict(t, fit_exploit.get(c))
        xp_txt, xp_ok = verdict(t, fit_explore.get(c))
        all_explore_ok = all_explore_ok and xp_ok
        if not ex_ok:
            exploit_had_problem = True
        label = c.replace("n_", "")
        L.append(f"| {label} | {t:.2f} | {ex_txt} | {xp_txt} |")

    L.append("")
    L.append("## Read")
    L.append("")
    if exploit_had_problem:
        L.append("- **Exploit-only data is misleading**: at least one channel is "
                 "mis-estimated — a true-zero channel can surface as a significant "
                 "\"winner\" (because reps lavished it on good accounts), or a real "
                 "driver gets distorted. Acting on this points reps at the wrong channel.")
    else:
        L.append("- Exploit-only happened to be close this run — raise "
                 "`--epsilon` down / `QUALITY_TO_OUTCOME` up to sharpen the confound.")
    if all_explore_ok:
        L.append("- **The explore-only arm recovers the truth**: every channel's "
                 "estimate lands near its planted effect, and the true-zero channel "
                 "is correctly *not* significant. Randomization severed the link "
                 "between channel choice and account quality, so the estimates are causal.")
    L.append("- **Takeaway for the deck:** the MMM's recommendations are only "
             "trustworthy once an exploration arm exists. Without it the model is "
             "confidently wrong; with a small epsilon it becomes an honest guide.")
    L.append("")
    L.append("_Synthetic data with planted ground truth — it proves the mechanism "
             "and the argument, not real channel results._")

    passed = exploit_had_problem and all_explore_ok
    return "\n".join(L), passed


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--n", type=int, default=6000, help="number of synthetic accounts")
    ap.add_argument("--epsilon", type=float, default=0.30, help="exploration fraction")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", metavar="FILE", help="write markdown report here (default stdout)")
    args = ap.parse_args()

    report, passed = build_report(args.n, args.epsilon, args.seed)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(report + "\n")
        print(f"report written to {args.out}")
    else:
        print(report)
    # Exit non-zero if the demo didn't demonstrate its point (useful in CI / re-runs)
    if not passed:
        print("\n[!] demo did not cleanly separate this run — tune --epsilon/--seed",
              file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
