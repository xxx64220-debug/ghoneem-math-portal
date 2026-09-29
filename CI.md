# Continuous integration

`.github/workflows/ci.yml` runs on pull requests targeting `main` and pushes to
`main`. It runs the built-in Node regression tests, compiles the repository's
Python files, and runs the checked-in EST arithmetic/data gates when their
source fixtures are present.

The database job creates a fresh `portal_ci` PostgreSQL 16 service for each
run. It applies the local-only Auth shim, schema migrations and SQL support
scripts, then runs the RLS, adversarial, grading, progress, notification and
upgrade regression scripts with `ON_ERROR_STOP`. The checked-in
`student_progress.sql` upgrade script runs before later SQL that consumes its
`assessment_type` column. The checked-in SAT staging bank is imported only into
the disposable database so migration 011 can run. The database service password
is a workflow-local test value; it is not a repository or Supabase secret.
No Supabase URL, API key, service-role key, or production credential is read or
required. The workflow does not deploy, publish, or connect to any external
database.

The baseline RLS and adversarial scripts run before the upgrade answer guard;
the remaining regression scripts run after it is installed.

## September 28 daily-quiz regressions

`tests/daily_quiz_quality.sql` covers SAT, EST I and EST II in all three daily
selection modes: random, lessons and selected questions. Unlike the streak test,
it starts without a frozen quiz and calls the actual `daily_state` selector.
CI applies the checked-in revision/controls dependencies and then
`20260928_daily_quiz_placeholder_guard.sql`, so an older support script cannot
silently replace the function under test.

Inside one rolled-back transaction the test creates the six known broken-record
fixtures, applies `20260928_daily_quiz_missing_context.sql` twice, and checks the
shared circle context/SVG, polynomial choices, independent arithmetic, preserved
keys/explanations/metadata and idempotency. The repaired content is replayed on
all three math tracks. Generated quizzes must retain complete stems and assets,
real choices, a unique matching key, a nonempty explanation, a verification mark
and no release hold. Both four- and five-choice MCQs are exercised. Answers stay
hidden until submission, correct submissions score 5/5, and reopened quizzes
remain frozen after selection settings change.

Each of 15 defective candidates is tested with exactly four valid questions, in
each track/mode, to make exclusion deterministic on any Cairo date. Cases cover
placeholder distractors and correct options (including mixed case), missing,
empty or null verification, a release hold, grid-ins, too few choices, absent,
non-string or unmatched keys, and empty/blank explanations. Failed generation
must create neither a partial quiz nor progress.

The SQL exports 36 actual before/after RPC states to a temporary JSON file.
`tests/daily_quiz_quality.test.cjs` feeds them through the production daily panel
and figure renderer to check question-to-figure/table mapping, all displayed
choices, answer secrecy and completed explanations. The existing Node VM pattern
uses a sanitizer spy for trusted fixture markup; this is not a browser DOM or
visual-layout test. No new package dependency is needed.

After the CI schema/dependencies above have been applied to **local `portal_ci`
only**, the same commands can be run manually:

```sh
export DAILY_QUIZ_TEST_PAYLOAD="$(mktemp)"
psql -X -qAt -v ON_ERROR_STOP=1 -f tests/daily_quiz_quality.sql > "$DAILY_QUIZ_TEST_PAYLOAD"
node --test tests/daily_quiz_quality.test.cjs
bash tests/daily_quiz_mutations.sh
rm -f "$DAILY_QUIZ_TEST_PAYLOAD"
```

The mutation script verifies that the real pre-guard selector fails the new
placeholder test and that omitting the content repair fails the shared-context
test, restoring the current selector afterwards. These checks need no production
question dump or Supabase credentials and do not certify the live bank contents.

## Checks that remain conditional or outside CI

- `tests/est_bank_2026.py` and `tests/est_bank_2026.sql` need
  `content/est-banks-2026/reviewed-bank.json` and `import-draft.sql`.
- `tests/est_september_2026.py` and `tests/est_september_2026.sql` need the
  September release manifest and its question, review and exam import SQL.
- `tests/est_march_key.py` needs
  `content/est-march-2026/worked-answer-key.json`.
- `tests/fair_exam_keys.sql` needs the imported 50-question March 2026 exam
  with ID `67a68471-59b3-5bf1-8a80-21ce851bef5f`.
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
hosted Supabase services and credentials. The clean migration sequence relies
on the checked-in upgrade SQL for `assessment_type`; CI applies it explicitly
before dependent migrations. Database behavior is checked against the isolated
PostgreSQL service instead.
