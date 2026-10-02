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
needs hosted `pg_cron` and `pg_net`, and is not applied. Deployed Edge Function tests remain outside CI; those require hosted Supabase
services and credentials. The clean migration sequence relies
on the checked-in upgrade SQL for `assessment_type`; CI applies it explicitly
before dependent migrations. Database behavior is checked against the isolated
PostgreSQL service instead.

## Local SAT and EST English browser checks

Run `npm ci --prefix tests/browser --ignore-scripts`, then
`cd tests/browser && npx playwright install --with-deps chromium && npm test`.
CI runs this suite on Chromium at desktop and mobile viewport sizes. Python
serves the actual `web/` tree on `127.0.0.1:4173`; no configurable preview or
production target is accepted and existing servers are not reused. Service
workers are blocked. The SDK is replaced at its network boundary with an
explicit synthetic session and in-memory answer writes. Edge Function requests
receive synthetic fixtures; unknown external requests abort and fail the test.
No request reaches Supabase. Optional CDN fonts/math are stubbed offline, so
this does not verify CDN availability or KaTeX typesetting.

Coverage: track chooser, SAT dashboard, Final Revision catalogue, exam stems,
four real choices, decoded graph image and table, MCQ/grid-in answer state and
autosave, next/previous palette navigation, flags, disabled boundary controls,
and timer countdown without reset on navigation. The current calculator is an
official SAT Desmos link, not an embed; visibility, URL, safe new-tab attributes
and horizontal layout are checked. This does not certify actual Desmos service
behavior. Traces are retained on failure; English desktop/mobile screenshots are retained on every run. Fixtures are deliberately synthetic
and do not certify bank mathematics or production content/assets.

Still requires an enrolled account: actual authentication/enrolment, assignment
visibility, server-backed answer persistence after reload, module unlocking,
submission/grading, production Final Revision availability and deployed assets.
Still requires a physical device: touch/keyboard behavior, screen locking and
app switching, PWA installation and opted-in notification display. Mobile
viewport emulation does not establish those device behaviors.

EST English coverage and fixture provenance are documented in `ENGLISH_READING.md`. Eight additional Chromium cases check English layout/formatting, collapse/reopen, answers, navigation and review, and unchanged SAT/EST I/EST II math paths.
