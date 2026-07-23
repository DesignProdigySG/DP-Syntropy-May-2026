#!/usr/bin/env python3
"""
MMM step 4 — per-funnel-stage logistic regression on mmm_account_action_mix.

Answers, per funnel stage: "which channels actually move the objective?"
by regressing objective_met on the channel-mix counts the pipeline records
automatically. This is the model MMM_STATUS_FOR_LEADERSHIP.md calls the
last step — everything upstream (objectives, labels, the matrix view) is
already live and fills itself as campaigns run.

Data source (one of):
  --demo              synthetic data, proves the pipeline end-to-end
  --csv FILE          export of mmm_account_action_mix (Supabase: table editor
                      -> mmm_account_action_mix -> download CSV, or:
                      \\copy (select * from mmm_account_action_mix) to 'mix.csv' csv header)
  --db                live query via DATABASE_URL env var (postgresql://...)

Output: readiness verdict + fitted channel odds-ratios per stage, as a
markdown report (stdout, or --out report.md; --json coeffs.json for the
machine-readable version the Channel Recommendation AI would consume).

Rules baked in (documented so the numbers aren't magic):
  * Only LABELED rows train the model: objective_status in ('met','missed').
    Open objectives are excluded — treating them as "not met" poisons the label.
  * Readiness per stage = at least MIN_ROWS labeled rows AND at least
    MIN_MINORITY examples of the rarer class AND >=1 channel with variance.
  * EPV (events-per-variable) heuristic: the minority-class count divided by
    10 caps how many channel predictors the fit can support; lowest-variance
    channels are dropped first if over the cap.
  * A significant positive odds ratio is CORRELATIONAL evidence. For causal
    channel effects you still need randomized holdouts (see report footer).
"""

import argparse
import json
import sys
from datetime import date

import numpy as np
import pandas as pd

CHANNELS = [
    "n_email", "n_linkedin_connect", "n_linkedin_engage", "n_invite",
    "n_landing_page", "n_content_download", "n_ads", "n_webinar",
    "n_phone", "n_partner",
]
CONTROLS = ["total_touches"]  # volume control so channel effects aren't just "more touches"
MIN_ROWS = 30       # floor per stage before any fit is attempted
MIN_MINORITY = 10   # rarer-class floor (met or missed, whichever is smaller)
EPV = 10            # labeled minority rows needed per predictor


def load_demo(seed: int = 42, n_per_stage: int = 120) -> pd.DataFrame:
    """Synthetic matrix with known ground truth so the pipeline is testable:
    engaged: linkedin_engage helps (+), ads does nothing.
    qualified: phone helps (+), email mildly (+)."""
    rng = np.random.default_rng(seed)
    rows = []
    truth = {
        "engaged":   {"n_linkedin_engage": 0.9, "n_email": 0.2},
        "qualified": {"n_phone": 1.1, "n_email": 0.35},
    }
    for stage, effects in truth.items():
        for _ in range(n_per_stage):
            x = {c: int(rng.poisson(1.2)) for c in CHANNELS}
            x["n_ads"] = int(rng.poisson(0.8))
            lin = -1.2 + sum(effects.get(c, 0.0) * x[c] for c in CHANNELS)
            p = 1 / (1 + np.exp(-lin))
            met = rng.random() < p
            rows.append({
                "funnel_stage": stage, **x,
                "total_touches": sum(x.values()),
                "objective_status": "met" if met else "missed",
            })
    return pd.DataFrame(rows)


def load_csv(path: str) -> pd.DataFrame:
    return pd.read_csv(path)


def load_db(view: str = "mmm_account_action_mix") -> pd.DataFrame:
    import os
    url = os.environ.get("DATABASE_URL")
    if not url:
        sys.exit("--db requires DATABASE_URL env var (postgresql://user:pass@host:5432/postgres)")
    try:
        import psycopg2  # noqa: F401
        from sqlalchemy import create_engine
        eng = create_engine(url)
    except ImportError:
        sys.exit("pip install sqlalchemy psycopg2-binary for --db mode")
    if view not in ("mmm_account_action_mix", "mmm_account_action_mix_explore"):
        sys.exit(f"refusing to query unexpected view '{view}'")
    return pd.read_sql(f"select * from {view}", eng)


def stage_readiness(df: pd.DataFrame) -> dict:
    labeled = df[df["objective_status"].isin(["met", "missed"])]
    met = int((labeled["objective_status"] == "met").sum())
    missed = len(labeled) - met
    minority = min(met, missed)
    varying = [c for c in CHANNELS if c in labeled and labeled[c].std(ddof=0) > 0]
    max_predictors = minority // EPV
    ready = len(labeled) >= MIN_ROWS and minority >= MIN_MINORITY and len(varying) >= 1
    return {
        "labeled_rows": len(labeled), "met": met, "missed": missed,
        "minority": minority, "varying_channels": varying,
        "max_predictors": max_predictors, "ready": ready,
        "need_rows": max(0, MIN_ROWS - len(labeled)),
        "need_minority": max(0, MIN_MINORITY - minority),
    }


def fit_stage(labeled: pd.DataFrame, readiness: dict) -> dict:
    import statsmodels.api as sm
    # Cap predictors by EPV: keep the channels most correlated with the
    # outcome first (abs point-biserial r), so the cap doesn't drop a real driver.
    varying = readiness["varying_channels"]
    cap = max(1, readiness["max_predictors"])
    y_tmp = (labeled["objective_status"] == "met").astype(float)
    ranked = sorted(varying, key=lambda c: abs(labeled[c].astype(float).corr(y_tmp)) if labeled[c].std(ddof=0) > 0 else 0, reverse=True)
    used = ranked[:cap]
    dropped = ranked[cap:]
    X = labeled[used + [c for c in CONTROLS if c in labeled and labeled[c].std(ddof=0) > 0]].astype(float)
    X = sm.add_constant(X, has_constant="add")
    y = (labeled["objective_status"] == "met").astype(int)
    result = {"channels_used": used, "channels_dropped_epv": dropped}
    try:
        fit = sm.Logit(y, X).fit(disp=0, maxiter=200)
        if not fit.mle_retvals.get("converged", False):
            raise RuntimeError("no convergence")
        ci = fit.conf_int()
        result["method"] = "MLE logistic"
        result["coeffs"] = {
            c: {
                "odds_ratio": float(np.exp(fit.params[c])),
                "or_ci_low": float(np.exp(ci.loc[c, 0])),
                "or_ci_high": float(np.exp(ci.loc[c, 1])),
                "p_value": float(fit.pvalues[c]),
            } for c in X.columns if c != "const"
        }
    except Exception:
        # separation / non-convergence -> L1-regularized fallback (no p-values)
        fit = sm.Logit(y, X).fit_regularized(alpha=1.0, disp=0)
        result["method"] = "L1-regularized logistic (separation fallback — no p-values/CIs)"
        result["coeffs"] = {
            c: {"odds_ratio": float(np.exp(fit.params[c]))}
            for c in X.columns if c != "const"
        }
    return result


def run(df: pd.DataFrame, explore_only: bool = False) -> tuple[str, dict]:
    for col in ["funnel_stage", "objective_status"]:
        if col not in df.columns:
            sys.exit(f"input is missing required column '{col}' — export mmm_account_action_mix "
                     f"AFTER the 2026-07-09 migration (adds objective_status)")
    title = "MMM regression report" + (" — EXPLORE-ONLY (causal)" if explore_only else "")
    lines = [f"# {title} — {date.today().isoformat()}", ""]
    if explore_only:
        lines += [
            "> Fit on the **randomized exploration arm only** "
            "(`channel_source='explore'`, view `mmm_account_action_mix_explore`). "
            "Because those channels were assigned at random, these odds ratios are an "
            "**unconfounded / causal** estimate — unlike the all-rows fit, where reps' "
            "non-random channel choices confound the result. Expect fewer labeled rows "
            "here (only explore touches count), so readiness fills more slowly.",
            "",
        ]
    machine = {"generated": date.today().isoformat(), "explore_only": explore_only, "stages": {}}
    stages = [s for s in df["funnel_stage"].dropna().unique()]
    if not stages:
        lines.append("**No rows with a funnel stage found.** The matrix is empty — "
                     "no campaigns with executed touches yet. Nothing to fit.")
    for stage in sorted(stages):
        sdf = df[df["funnel_stage"] == stage]
        r = stage_readiness(sdf)
        lines.append(f"## Stage: {stage}")
        lines.append(f"- labeled rows: **{r['labeled_rows']}** (met {r['met']} / missed {r['missed']}) "
                     f"— target ≥{MIN_ROWS} rows, ≥{MIN_MINORITY} minority")
        machine["stages"][stage] = {"readiness": {k: v for k, v in r.items() if k != "varying_channels"}}
        if not r["ready"]:
            need = []
            if r["need_rows"]:
                need.append(f"{r['need_rows']} more labeled rows")
            if r["need_minority"]:
                need.append(f"{r['need_minority']} more of the rarer outcome class")
            if not r["varying_channels"]:
                need.append("channel variation (all campaigns used identical mixes)")
            lines.append(f"- **NOT READY** — need: {', '.join(need) or 'more data'}.")
            lines.append("")
            continue
        res = fit_stage(sdf[sdf["objective_status"].isin(["met", "missed"])], r)
        if explore_only:
            res["method"] = "explore-only (causal) — " + res["method"]
        machine["stages"][stage]["fit"] = res
        lines.append(f"- fit: {res['method']}; predictors capped at {max(1, r['max_predictors'])} by EPV"
                     + (f" (dropped: {', '.join(res['channels_dropped_epv'])})" if res["channels_dropped_epv"] else ""))
        lines.append("")
        lines.append("| channel | odds ratio | 95% CI | p | read |")
        lines.append("|---|---|---|---|---|")
        for c, v in sorted(res["coeffs"].items(), key=lambda kv: -kv[1]["odds_ratio"]):
            orr = v["odds_ratio"]
            ci = f"{v['or_ci_low']:.2f}–{v['or_ci_high']:.2f}" if "or_ci_low" in v else "—"
            p = f"{v['p_value']:.3f}" if "p_value" in v else "—"
            sig = "p_value" in v and v["p_value"] < 0.05
            read = ("**helps**" if orr > 1 else "**hurts**") + (" (significant)" if sig else " (weak evidence)")
            lines.append(f"| {c} | {orr:.2f} | {ci} | {p} | {read} |")
        lines.append("")
    lines += [
        "---",
        "**How to read this:** odds ratio 1.5 on `n_phone` = each extra phone touch multiplies "
        "the odds of hitting the stage objective by 1.5x, holding the other channels and total "
        "volume constant. Feed significant winners back into the Channel Recommendation AI prompt.",
        "",
        ("**Caveats:** this is the EXPLORE-ONLY arm — channels were randomized, so the estimate "
         "is causal (no account-quality confounding). Main limits now are sample size (only "
         "explore touches count toward the mix) and that the label reflects the whole campaign's "
         "outcome, not the explore touches in isolation. v1 matrix is one objective per campaign."
         if explore_only else
         "**Caveats:** correlational, not causal (reps choose channels non-randomly — confounding "
         "by account quality is likely). For causal answers, run this with `--explore-only` once the "
         "exploration arm has volume. v1 matrix is one objective per campaign, joined by campaign_id."),
    ]
    return "\n".join(lines), machine


def write_db(machine: dict) -> None:
    """Persist the fitted coefficients into public.mmm_channel_effects so the
    dashboard MMM tab can render them. Delete-then-insert = the table always
    holds exactly the latest run. Only stages that actually fit are written;
    not-ready stages leave no rows (the dashboard falls back to the readiness
    view for those)."""
    import os
    url = os.environ.get("DATABASE_URL")
    if not url:
        sys.exit("--db-write requires DATABASE_URL env var (postgresql://user:pass@host:5432/postgres)")
    try:
        import psycopg2  # noqa: F401
        from sqlalchemy import create_engine, text
    except ImportError:
        sys.exit("pip install sqlalchemy psycopg2-binary for --db-write mode")
    rows = []
    for stage, s in machine["stages"].items():
        fit = s.get("fit")
        if not fit:
            continue
        labeled = s.get("readiness", {}).get("labeled_rows")
        for ch, v in fit["coeffs"].items():
            p = v.get("p_value")
            rows.append({
                "funnel_stage": stage, "channel": ch,
                "odds_ratio": float(v["odds_ratio"]),
                "ci_low": v.get("or_ci_low"), "ci_high": v.get("or_ci_high"),
                "p_value": p, "significant": (p < 0.05) if p is not None else None,
                "method": fit.get("method"), "labeled_rows": labeled,
            })
    eng = create_engine(url)
    with eng.begin() as cx:
        cx.execute(text("DELETE FROM public.mmm_channel_effects"))
        if rows:
            cx.execute(text(
                "INSERT INTO public.mmm_channel_effects "
                "(funnel_stage, channel, odds_ratio, ci_low, ci_high, p_value, significant, method, labeled_rows) "
                "VALUES (:funnel_stage, :channel, :odds_ratio, :ci_low, :ci_high, :p_value, :significant, :method, :labeled_rows)"
            ), rows)
    print(f"wrote {len(rows)} channel-effect row(s) to mmm_channel_effects", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--demo", action="store_true", help="synthetic data with known ground truth")
    src.add_argument("--csv", metavar="FILE", help="CSV export of mmm_account_action_mix")
    src.add_argument("--db", action="store_true", help="query live via DATABASE_URL")
    ap.add_argument("--out", metavar="FILE", help="write markdown report here (default: stdout)")
    ap.add_argument("--json", metavar="FILE", help="write machine-readable coefficients here")
    ap.add_argument("--db-write", action="store_true",
                    help="persist fitted coefficients into public.mmm_channel_effects for the dashboard (needs DATABASE_URL)")
    ap.add_argument("--explore-only", action="store_true",
                    help="fit only the randomized exploration arm (view mmm_account_action_mix_explore) "
                         "for an unconfounded, causal channel estimate. Applies to --db; with --csv/--demo it "
                         "only relabels the report (export the explore view yourself for --csv).")
    args = ap.parse_args()

    view = "mmm_account_action_mix_explore" if args.explore_only else "mmm_account_action_mix"
    df = load_demo() if args.demo else (load_csv(args.csv) if args.csv else load_db(view))
    report, machine = run(df, explore_only=args.explore_only)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(report + "\n")
        print(f"report written to {args.out}")
    else:
        print(report)
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(machine, f, indent=2)
        print(f"coefficients written to {args.json}", file=sys.stderr)
    if args.db_write:
        write_db(machine)


if __name__ == "__main__":
    main()
