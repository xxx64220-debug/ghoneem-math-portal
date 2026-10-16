# EST I / EST II unusable-record cleanup — 15 October 2026

**Already applied** to the existing production project at 23:43:41 UTC on
14 October / **02:43:41 Cairo on 15 October**. Audit **20202**. Do not replay.

This follows the earlier 28-record review (audit 20006, PR #32). The instructor
authorized adding/removing unfixable material and completing missing data.

## Outcome

- Archive **172 existing records**, without deleting their content or keys:
  **159 EST I and 13 EST II**. These comprise 133 duplicate records and 39
  defective/incomplete originals, including the newly retired MA-30 copy.
- Complete **172 validated, same-track replacement links**. All 171 previously
  held records already have usable counterparts; reuse those rather than add
  duplicates. Exact existing canonical references were recovered from the
  recorded hold reasons where the structured replacement field was missing.
  Their current fingerprints and live eligibility are guarded.
- Add **one independently solved instructor adaptation**,
  `GH-EST2-EXP-GRAPH-20261015`,
  ID `d224713e-da71-5966-81d2-910764d7cd04`.
  It retains the authentic MA-30 graph as a verified embedded PNG and supplies
  explicit wording plus four complete instructor-authored choices. Key **F**:
  x > −2. The original J typography is not claimed to be recovered.
- Repair **eight published assessments** using that adaptation. Seven
  never-attempted assessments update in place. One attempted assessment gets a
  new version with the same audience/windows/count/timer/settings. Its original
  exact question list and saved attempt stay in a held historical version.
  Two already historical exams containing MA-30 remain unchanged.
- Correct **15 stale source-archive labels**: 14 instructor-excluded curriculum
  items are marked excluded; PSD 132 is marked source repair rather than ready.
  Original source text/images, links and mathematical notes are retained.

## Fresh live verification

| Measure | EST I | EST II |
|---|---:|---:|
| Nonremoved active bank records | 2,665 | 1,375 |
| Structurally eligible | 2,665 | 1,375 |
| Structurally blocked in the active bank | 0 | 0 |
| Explicit independently solved status | 75 | 27 |

This is **not a new mathematical certificate for all 4,040 active questions**.
Older reviews use other evidence fields; 2,590 EST I and 1,348 EST II eligible
records lack the explicit solved marker. That metadata backlog must still be
reconciled with exact earlier ledgers before treating it as new unsolved work.

Readback found zero archived-content hash mismatches, zero changed original
keys, zero failed replacement links, zero blocked corrected exams and zero
stale ready-source labels. All six remaining published blocked assessments
(two EST I, four EST II) are explicitly held historical versions; no
nonhistorical published EST assessment is blocked.

No current/future daily track or group quiz references an archived record.
Two old unfinished drills from September 26/29 have zero saved answers and are
outside the automatic one-day resume window. Existing state/submit guards block
ineligible drills, and new drills use eligible questions. Sixteen historical
notebook rows are retained; existing notebook eligibility filters hide the
archived items. No student progress was reset or fabricated.

The separate source archive retains 23 EST I and three EST II unlinked,
unresolved entries as evidence only. Their original missing conditions,
damaged choices or diagrams were not invented and were not released.

## Guards and regressions

`before.json` records question-only content plus assessment metadata, not
student identities/responses. `replacement-guards.json` fingerprints existing
counterparts. `packet.json` is the reviewed disposition manifest.

The atomic repeatable-read transaction checks complete question/key hashes,
all unchanged assessment members, counterpart readiness, exam hashes,
assignment hashes, exact attempt counts and revision state. Brief locks prevent
new attempts racing an in-place assessment change. It backs up affected
question/source/exam fields in the existing protected audit log, preserves
every original key and snapshots history/membership digests.

Saved attempts, answers, results, revision sessions, revision membership,
enrolments and group memberships have identical digests before/after. Existing
assignments remain unchanged; one matching assignment is added for the new
exam version. No grades are recalculated. No schema or frontend deployment is
needed.

Passed:

- `python3 tests/est_cleanup_20261015_math.py`: independent monotone-function
  solution, four-choice uniqueness, endpoint samples, authentic PNG hash and
  every disposition/substitution.
- `PGLITE_MODULE="$PWD/tests/june-review-runtime/node_modules/@electric-sql/pglite" node tests/est_cleanup_20261015_db.cjs`: actual archived/source/exam
  fingerprints, same-track replacements, late-failure atomic rollback,
  concurrent history/member rejection, seven in-place edits plus one historical
  version, unchanged original keys/grades/answers/timers/audiences and replay.
- The actual shared renderer displays exactly one embedded authentic graph,
  without an answer-key field. Existing practice-figure regression passed.
- `git diff --check`.

The isolated fixture uses synthetic unchanged assessment members/counterparts
and substitutes only their hashes and synthetic audience hashes. It does not
mathematically certify those unchanged records. It never connects to production.

## Safe rollback

`rollback.sql` rejects new exam/practice use, changed content/assignments and
replay. It restores the previous held metadata for 171 records, original source
labels and unused assessment contents, removes the unused new version/item,
and preserves all saved history. Restored unused exams become drafts rather
than republishing a defective source item. MA-30 remains archived and its
historical version stays held because its source defect is still established.
Tests cover successful rollback and rejection after new practice use. No
production rollback was run.

Rebuild with `python3 content-releases/20261015_est_cleanup/build.py`.
The required authentic source image is already committed. SQL must only be
applied to the exact guarded before state; this release is already complete.
