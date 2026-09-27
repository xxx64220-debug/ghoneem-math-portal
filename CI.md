# Continuous integration

`.github/workflows/ci.yml` runs on pull requests targeting `main` and pushes to
`main`. It runs the built-in Node regression tests, compiles the repository's
Python files, and runs the checked-in EST arithmetic/data gates when their
source fixtures are present.

The database job creates a fresh `portal_ci` PostgreSQL 16 service for each
run. It applies the local-only Auth shim, schema migrations and SQL support
scripts, then runs the RLS, adversarial, grading, progress, notification and
upgrade regression scripts with `ON_ERROR_STOP`. The database service password
is a workflow-local test value; it is not a repository or Supabase secret.
No Supabase URL, API key, service-role key, or production credential is read or
required. The workflow does not deploy, publish, or connect to any external
database.

## Checks that remain conditional or outside CI

- `tests/est_bank_2026.py` and `tests/est_bank_2026.sql` need
  `content/est-banks-2026/reviewed-bank.json` and `import-draft.sql`.
- `tests/est_september_2026.py` and `tests/est_september_2026.sql` need the
  September release manifest and its question, review and exam import SQL.
- `tests/est_march_key.py` needs
  `content/est-march-2026/worked-answer-key.json`.
- `tests/est_source_review.test.cjs` needs the September archive JSON and the
  built `dist/` image tree.

The workflow prints a `SKIP` line for a release gate whose required source
artifacts are absent from the checked-out revision. This keeps the checks
visible without synthesizing or substituting release data. Add the complete,
reviewed source artifacts and import SQL to the repository to make those gates
run on every CI build.

Migration `010_expiry_schedule.sql` is intentionally not applied in CI: it
installs `pg_cron` and schedules a recurring database job, behavior provided by
the hosted Supabase environment. The standalone notification scheduler also
needs hosted `pg_cron` and `pg_net`, and is not applied. No browser end-to-end
test or deployed Edge Function test runs here; those need a browser session or
hosted Supabase services and credentials. Migration
`011_sat_partitions_and_module_pairs.sql` is not applied: it assumes an
`exams.assessment_type` column that is absent from the checked-in migration
chain, as well as imported SAT bank rows. Keep it out of the clean-database job
until those schema and data prerequisites are represented in versioned source.
Database behavior is checked against the isolated PostgreSQL service instead.
