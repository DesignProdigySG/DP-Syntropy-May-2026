# MMM step 4 — the regression scaffold

This folder holds the last piece of the MMM plan (`MMM_STATUS_FOR_LEADERSHIP.md`):
the model itself, pre-built so it can run the day the data exists. Everything
upstream — objectives, the daily met/missed labeler, the `mmm_account_action_mix`
matrix — is already live and fills itself as campaigns run.

## Run it

```bash
pip install pandas numpy statsmodels          # once
python mmm_regression.py --demo               # synthetic data, proves the pipeline
python mmm_regression.py --csv mix.csv        # real data (CSV export of the view)
DATABASE_URL=postgresql://... python mmm_regression.py --db   # live query
                                              # (needs sqlalchemy + psycopg2-binary)
python mmm_regression.py --csv mix.csv --out report.md --json coeffs.json
DATABASE_URL=postgresql://... python mmm_regression.py --db --db-write   # fit live + push to the dashboard
DATABASE_URL=postgresql://... python mmm_regression.py --db --explore-only   # CAUSAL fit on the randomized explore arm only
```

`--explore-only` reads `mmm_account_action_mix_explore` (channel counts from
`channel_source='explore'` touches only). Because those channels were assigned
at random by the exploration hook, this fit is **causal** — free of the
account-quality confounding that makes the all-rows fit merely correlational.
See `CHANNEL_EXPLORATION_DESIGN.md` for the full feature.

`--db-write` upserts the fitted odds ratios into `public.mmm_channel_effects`
(delete-then-insert, so the table always holds the latest run). Only stages
that actually fit are written; not-ready stages leave no rows.

CSV export: Supabase Studio → `mmm_account_action_mix` → download CSV. Must be
exported after the 2026-07-09 migration (which added `objective_status` to the
view — required so open objectives can be excluded from training).

## What it does, per funnel stage

1. **Readiness gate** — needs ≥30 labeled rows (objective `met` or `missed`),
   ≥10 of the rarer class, and ≥1 channel with variance. If not met it prints
   exactly how many rows are still missing (the same numbers as the dashboard's
   "MMM readiness" tile, which reads `dashboard_mmm_readiness`).
2. **EPV cap** — supports one channel predictor per 10 minority-class rows;
   keeps the channels most correlated with the outcome, reports what it dropped.
3. **Logistic regression** — objective_met ~ channel counts + total_touches
   (volume control). Falls back to L1-regularized fit on separation.
4. **Output** — odds ratio + 95% CI + p per channel. OR 1.5 on `n_phone` =
   each extra phone touch multiplies the odds of hitting the stage objective
   by 1.5×, holding the rest of the mix constant.

`--demo` plants known effects (linkedin_engage at engaged, phone+email at
qualified) and the fit recovers them — verified 2026-07-09.

## Dashboard

The control tower's **MMM** tab reads `mmm_channel_effects` and renders a
forest plot (odds ratio + 95% CI per channel, per funnel stage; green =
significant helper, red = significant drag). Until any stage clears the
readiness gate the tab shows readiness progress bars instead. Run the model
with `--db-write` to populate it.

## What to do with the results

Significant winners feed the Channel Recommendation AI's system prompt in
Brief Approval Handler — replacing the heuristic channel leaderboard with
per-stage evidence.

**Caveat:** this is correlational. Reps pick channels non-randomly, so account
quality confounds channel choice. For causal answers, randomize a held-out
channel per campaign once volume allows.
