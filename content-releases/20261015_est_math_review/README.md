# EST mathematics review — 15 October 2026, Cairo

Production applied at 2026-10-14 23:31:04 UTC / 15 October 02:31:04 Cairo.
Audit event **20006**. This release has already been applied: do not replay it.

## Delivered

Independently reviewed **28 existing records: 14 EST I and 14 EST II**. Replaced
source-key-only explanations with worked solutions. The two EST I mirror
records were reviewed separately in their own track. All accepted keys remain
unchanged. No questions were added, deleted, moved between tracks or unheld.

Two EST II choice-transcription repairs are established by authentic archive
images and independent algebra:

- **E-21**: restore the open endpoint to **−11**, in both A and C. The original
  image has A = (−11, 4] and C = (−11, 12]. The correct answer remains A.
- **E-19**: restore A to a **dashed** boundary shaded above; record the slope
  1/2 and intercept −2 consistently for all descriptions. B remains correct:
  y < x/2 − 2.

The supplied Kimi archive is identified as Library
`libfile_bf57f23ca344819199a3207a9fbcf774`. Exact markdown source hashes and
matching image hashes are recorded per item in `packet.json`. Source crops
were visually compared, including all graphs and tables used by this batch.
This verifies the supplied archive, not an unavailable publisher-original PDF.
MG-13's crop clips part of its fourth figure; the complete first three figures
suffice to select D uniquely, and the archive text records 11 dots in Figure 4.
No pixels or missing source relationships were invented.

## Live status after application

| Track | Nonremoved bank records | Structurally eligible | Held | Explicit independently solved status | Eligible without explicit solved status |
|---|---:|---:|---:|---:|---:|
| EST I | 2,824 | 2,665 | 159 | 75 | 2,590 |
| EST II | 1,387 | 1,375 | 12 | 26 | 1,349 |

**The last column is a workflow-marker backlog, not a claim that every such
question has never been independently reviewed.** Many older independent
reviews are evidenced in earlier release ledgers or different metadata fields.
PR #29's audit 19492 and PR #30's audit 19527 were confirmed live; their SQL was
not replayed. All 50 original EST I practice questions remain recognized as
completed work. The reviewed June ledger also documents 356 earlier reviews.

All seven held questions found in published assessments occur only in versions
already titled “Historical version (held)”. Their content and memberships stay
unchanged. The three nonduplicate EST I historical items have ready, same-track
adaptations; the exponent duplicate retains its canonical reference. All 12
held EST II originals have structurally ready same-track adaptations. These are
explicit practice versions, not proof that the originals' source ambiguities
have been resolved.

The source archive is a separate inventory: EST I has 23 unresolved unlinked
source entries, 94 duplicate entries, nine excluded entries and one nonquestion.
Two source entries labeled ready are unavailable live (one removed sequence and
one held interest-rate question). EST II has three unresolved unlinked sources,
and 13 ready-labeled links are unavailable because they were intentionally
removed from the bank. Do not restore them as a review shortcut.

## Remaining priority

The 159 EST I holds and 12 EST II holds remain unchanged. Exact IDs, reasons,
historical uses and next candidates are in `snapshot.json` and
`production-receipt.json`.

Prioritize source recovery for EST II T7-07, T7-28 and T6-11 because of their
historical assessment uses. The exact archive contains prose descriptions but
no original diagrams for those items; T6-11 additionally lacks the numerator
domain. Do not infer missing diagrams or domains.

EST II MA-30 is the next active high-use item (eight nonhistorical published
uses). Its graph supports F, x > −2, but its J distractor is printed as
∞ < x < −2 in the supplied markdown. This batch leaves the entire record
unchanged rather than invent the missing sign. Obtain its complete original
question/choice image before certifying the full item.

The next EST I source-key-only items are CP-c19-28, CP-c19-23, CP-c12-19 and
CP-c12-11 (one nonhistorical published use each); next EST II items after MA-30
are H-04, T7-11 and H-12 (seven uses each). Their read-only priority snapshot is
included, not a claim of completed review. The broader status-marker backlog
requires reconciliation against earlier exact review ledgers before new work.

## Safety, validation and rollback

`apply.sql` uses a repeatable-read transaction, locks selected question/key and
revision rows, checks full current-row fingerprints and existing eligibility,
refuses replay, preserves every accepted key and source asset, and writes
before-state audits. It checks byte-equivalent digests of exams, assignments,
attempts, answers, results, revision sessions, enrolments and group memberships.
Only the one affected revision fingerprint is refreshed; its membership and
other fields remain unchanged. No schema or frontend publication is required.

Readback confirmed 28 audited records, **zero** after-hash mismatches,
**zero** changed keys, **two** choice repairs, **zero** ineligible reviewed items
and **zero** stale affected revision fingerprints.

`rollback.sql` restores the exact former choices/assets/explanations and revision
fingerprint, refuses subsequent edits and repeated rollback, and does not
rescore saved attempts. No rollback was run on production.

Checks passed:

- `python3 tests/est_math_review_20261015.py`
- `PGLITE_MODULE="$PWD/tests/june-review-runtime/node_modules/@electric-sql/pglite" node tests/est_math_review_20261015_db.cjs`
- Existing 50-question original-practice arithmetic/image checks.
- Existing held-source mathematics checks.
- `git diff --check`

The isolated PostgreSQL test reproduces the actual production before hashes,
rejects late question/key and stale-revision changes atomically, checks every
MCQ alternative and accepted numeric response with the existing grader, verifies
unrelated history/assessment/source preservation, and exercises replay plus
successful and conflict-rejected rollback. No test connects to production.

To rebuild the release, materialize the exact supplied archive into
`../sources/archive` and run `python3 content-releases/20261015_est_math_review/build.py`.
CI runs the committed packet's math and isolated SQL tests without the archive.
