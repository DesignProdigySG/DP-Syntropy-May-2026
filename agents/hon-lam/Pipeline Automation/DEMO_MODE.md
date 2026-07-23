# Demo mode — showing the pipeline without real traffic

The system is pre-traffic: with an empty database the dashboards are blank and the
MMM model has nothing to fit. **Demo mode** seeds a realistic synthetic dataset so
the entire pipeline is demonstrable end-to-end at any time — for a walkthrough, a
screen-share, or a handover.

## What it does

`supabase/demo_seed.sql` inserts **~300 labeled campaigns** (all tagged `ZZ-DEMO`)
spread across three funnel stages, each with a varied channel mix and a met/missed
outcome. Channel effects are deliberately *planted* so the analytics and the model
have real signal to show:

| Funnel stage | Planted "winning" channel |
|---|---|
| aware | content downloads |
| engaged | LinkedIn engagement |
| qualified | phone (and email) |

Loading it lights up:

- **Dashboard tab** — KPIs, funnel, channel charts, MMM readiness (all three stages ~95–100%).
- **MMM tab** — the channel-effectiveness **forest plot**, drawn from a real logistic-regression fit of the seeded data (the fit recovers the planted winners with significance).

## How to run it

```bash
# seed
psql "$DATABASE_URL" -f supabase/demo_seed.sql
# ...demo the dashboards...
# tear down (restore empty pre-traffic state)
psql "$DATABASE_URL" -f supabase/demo_teardown.sql
```

Or paste either file into the Supabase SQL editor. Both are idempotent.

## Why it's safe

- Every row is tagged `ZZ-DEMO` / `zz-demo-` and removed cleanly by the teardown.
- States are set so the **live workflows ignore the demo data**: campaigns are
  `completed` with `opportunity_status = 'offered'`, actions are `measured`, and
  objectives are already resolved — so the scheduled measurement, adaptive-decision,
  and opportunity-offer workflows won't act on it or send anything.

## Why it's reproducible

Campaign attributes are derived from `md5(n)` hashes rather than `random()`, so the
seed generates **identical data on any Postgres**. That's why the MMM coefficients
baked into `demo_seed.sql` always match the seeded data. To recompute them from the
data instead of using the baked values:

```bash
python mmm/mmm_regression.py --db --db-write   # needs DATABASE_URL + sqlalchemy/psycopg2
```

## Important

This is **synthetic data for demonstration only** — not real customer results. It
proves the pipeline, the analytics, and the model all work; the real numbers appear
once real traffic flows. Always say so when showing it.
