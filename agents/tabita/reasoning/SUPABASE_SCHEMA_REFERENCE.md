# Supabase Schema Reference

*This is the single source of truth for table structure. Any UI code, SQL, or integration work should be checked against this document first to avoid the column-mismatch errors that repeatedly broke the build.*

## accounts

| Column | Notes |
|---|---|
| id | UUID, must be explicitly set with gen_random_uuid() on insert |
| name | text |
| industry | text |
| hq | text |
| status | text |
| confidence_floor | text/numeric |
| valid_until | date |
| context_director | text |
| approval_date | date |
| created_at | timestamp |
| updated_at | timestamp |

No `region` column exists. Do not reference it.

## facts

| Column | Notes |
|---|---|
| id | UUID |
| account_id | UUID, foreign key to accounts |
| source_id | UUID, foreign key to sources (currently unused — facts store source info as free text in `notes` instead, which is a structural gap to fix) |
| content | text — the actual fact claim. NOT called `claim`. |
| type | text — A, B, C, or D |
| trust_status | text — used for rejection tracking (e.g. 'rejected') |
| collected_date | date |
| valid_until | date |
| rep_confirmed_by | text |
| rep_confirmed_date | date |
| notes | text — currently used to store source name + URL as free text. NOT called `source_name` or `source_url`. |
| confidence | integer, 0–100, nullable |
| intended_use | text, constrained to: account_qualification, buying_committee_mapping, conversation_prep, gap_identification, timing_signal |

No `created_at` column — do not order queries by it. No `tags` column.

## sources

Columns confirmed to exist (registry currently unused/empty — facts don't link to it via source_id yet):
id, account_id, name, type, credibility_tier, url, valid_until, notes, created_at

## conflicts

| Column | Notes |
|---|---|
| id | UUID |
| account_id | UUID |
| fact_a | text — content of first conflicting fact |
| fact_b | text — content of second conflicting fact (nullable, e.g. for stale-fact-only conflicts) |
| level | text — critical, moderate, low |
| trusted_fact | text — which fact's content is considered more reliable |
| resolution_condition | text — what needs to happen to resolve this |
| status | text — open, resolved, suppressed |
| resolved_by | text |
| resolved_date | date |
| notes | text — explanation of why this was flagged |

## gaps

Exists as a table but Type D facts (stored directly in `facts` with type='D') are currently used instead for gap tracking. The `gaps` table itself is not actively used by the current UI.

## rejections

| Column | Notes |
|---|---|
| id | UUID |
| account_id | UUID |
| fact_id | UUID, foreign key to facts |
| rejection_type | text — one of: Stale fact, Wrong contact, Incorrect information, Wrong timing, Wrong approach, Wrong channel |
| rejected_by | text — who flagged it |
| rejection_date | date |
| notes | text |
| routed_to | text — 'source' (CaP acts) or 'engine_logic' (WHEN Layer acts, CaP only logs) |
| resolved | boolean |
| resolved_date | date |
| resolved_by | text |
| created_at | timestamp |

## pattern

Exists but not actively used by current UI.

## Deletion dependency order

Required strictly, in this sequence, due to foreign key constraints:
1. rejections (where fact_id references facts being deleted)
2. pattern
3. conflicts
4. gaps
5. facts
6. sources
7. accounts

## RLS notes

Every table needs explicit SELECT, INSERT, and UPDATE policies for the anon role (or public) — RLS being enabled without matching policies causes silent empty reads, not errors, which is the hardest failure mode to debug. Always verify with:

select * from pg_policies where tablename = 'TABLE_NAME';

## API key

Use the JWT-format anon/public key (starts with eyJ...) from Project Settings → API, not the newer sb_publishable_... format — the newer format was found to cause "No API key found in request" errors against this project's REST endpoint.
