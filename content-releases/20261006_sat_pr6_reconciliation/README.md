# SAT PR #6 reconciliation — 6 October 2026

PR [#6](https://github.com/xxx64220-debug/ghoneem-math-portal/pull/6), head
`4c2b60308e0df2b97453b1444676cec8e4a59c19`, is superseded by this selective
reconciliation against main `f9d865a81bb9e7a790c1c6ea6c01fa96fa593857`.
Its 18 unique commits must not be merged wholesale into the current portal.

## Preserved evidence

All 71 missing `content/sat-*` records are preserved byte for byte at their
original paths: source checksums, question transcriptions, independently
reviewed answer indexes, source crop coordinates, image hashes, duplicate and
hold audits, deterministic builders, and historical release/backfill SQL.
`preservation-index.json` lists every original path, preserved path, byte count
and SHA-256 hash. These are historical intake records, not a current deployment
plan or certification of current production membership.

The records account for 498 graded Chapter 1–13 exercises and 380 Chapter 14–26
exercises (22 exercise sections, 48 worked-answer pages). Chapter 27 is the
answer section. Source defects and unsupported symbolic response formats stay
documented as holds. The September recovery records establish Q19 and Q24;
Q18 remains held. Earlier packet READMEs describe the state at their original
release date; use the later recovery/summary records to interpret that history.

The two original migrations are preserved unchanged under
`historical-migrations/`, outside `supabase/migrations/`:

| Historical migration | Why it is archival only |
| --- | --- |
| `20260928_panda_worked_solution_after_check.sql` | Intermediate implementation reads worked images from prompt assets; superseded by the private-table implementation. |
| `20260928_zz_panda_private_worked_pages.sql` | Historical data transfer expects exactly 48 images, removes prompt assets and writes pre-taxonomy fingerprints; unsuitable for replay on current production. |

## Current architecture

Current main already contains the later live private-page function in
`tests/fixtures/oct4-support-functions.sql`, although the canonical schema
support was missing. `supabase/sql/panda_private_worked_pages.sql` now records
that same state function and private table for clean-environment reconstruction.
It contains no question import, image transfer, fingerprint update, revision
reactivation or student-history change. It explicitly enables RLS, denies
client roles direct table/RPC access, grants server access and uses an invoker
function behind the existing authenticated Edge Function.

The state function retains enrollment, revision visibility, session ownership,
track filtering and checked-answer guards. The current
`supabase/sql/question_eligibility.sql` retains its metadata-only catalogue and
lazy hydration: worked images and solution-page references never enter prompt
snapshots. Use the canonical support after the current revision schema/controls
when rebuilding a disposable database, rather than replaying archival imports.

The four shared runtime/test files from PR #6 were deliberately not copied:
`web/final-revision.js`, `web/revision-formulas.js`, `dist/revision-formulas.js`
and `tests/revision_formulas.test.cjs`. The current formula catalogue and tests
remain authoritative. The old client worked-image disclosure control is also
left out of this repository-record task; this packet does not claim a new UI
release. Any separately requested client work must extend current rendering
and have its own deployment verification.

## Production: do not replay

PR #6 and its recovery README report the imports, private pages and answer
control as already released (Site version 49). The October 4 checked-in live
readback fixture corroborates the private-page lookup. This task made no
production database calls, deployment or imports; the historical 1,941-row
total is not a fresh October 6 live count.

Do **not** run historical `release.sql`, `revision-backfill.sql`,
`repair-source-chapters.sql`, builders' generated SQL, or either archived
migration against production. Their idempotency and fingerprint assumptions
predate lesson taxonomy, representative pruning and later reliability holds.
Builders are retained for source reconstruction using the pinned original PDFs;
their generated output is historical and requires a separate current-schema
review before any use. Original PDFs and generated scanned-image SQL remain
outside git. The canonical support script is not queued for production either;
the already-live state needs no write in this reconciliation.

## Verification

```sh
python tests/sat_pr6_records.py
PGLITE_MODULE="$PWD/tests/june-review-runtime/node_modules/@electric-sql/pglite" node tests/panda_private_worked_pages_db.cjs
node --test tests/final_revision.test.cjs tests/practice_figures.test.cjs tests/revision_formulas.test.cjs tests/lesson_taxonomy.test.cjs tests/client_state.test.cjs
python -m compileall -q content
```

The provenance test validates all 73 exact files, exercise counts, unique
index/key pairs, numeric answer forms, crop bounds and 48 page references,
without executing imports or asserting a new mathematical review of the scan.
The database test uses synthetic images in local PostgreSQL WASM, asserts
canonical state parity with the existing live readback, exercises current
catalogue/start/answer code, and verifies client denial, checked-only reveal,
private prompt snapshots, owner/track/enrollment/visibility checks and
import-free support replay. Both are added to the current CI workflow.

Close PR #6 as superseded only after this reconciliation is preserved on main
and the current CI checks pass. Retain its branch as an additional historical
reference; do not merge or delete it as part of this task.
