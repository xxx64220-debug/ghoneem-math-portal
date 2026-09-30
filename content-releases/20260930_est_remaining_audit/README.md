# Remaining EST I review and live corrections — 30 September 2026

Completed the 430 previously available EST I records without an answer-review, review-method or verified-release marker: 425 independently solved and five explicitly excluded. Eight guarded batches record the exact reviewed source versions and proofs. The keys of the 425 verified records were already mathematically correct and were preserved.

There are 149 records with repairs, including 84 with text, choices, explanations or domain/wording corrections. Other repairs replace obsolete image-host URLs with the current portal host. Original source crops were checked for 211 records. Image-backed questions may intentionally retain their source crop and option-selection controls; these are not missing-information defects when the complete original is visible.

Examples: restore complete Amani-style currency wording using USD; recover incomplete question text and choices; correct the combined car-table total from 373 to 376 and mean from 2.33125 to 2.35; use parallelogram diagonal bisection rather than call it a rectangle; state the real radical domain; distinguish an overall two-year change from an annual change; normalize integer coefficients in the rationalized-surds question; state independent shots and all darts hitting the target; correct a graph-option vertex transcription; distinguish observed dots from fitted curves.

## Explicit source exclusions

| ID / source | Proven defect | Disposition |
| --- | --- | --- |
| 25341cd9-57d3-529c-bd83-36eae2d1f3a7 / March Q23 | Single-answer prompt has both B and D valid; D holds for every real x | Held, revision disabled, containing published set unpublished |
| be507dd8-d608-59a3-970e-10e05284131b / March Q4 | Honda revenue is printed 117,00; assuming a missing zero changes the source | Held; existing void key preserved |
| d734bf83-7cbd-5bd2-b857-db3656c5018d / March Q35 | Actual slope is −11.5; none of the printed options matches | Held; existing void key preserved |
| c5b39981-f58c-5d56-b5b2-79f1702ad1da / March Q27 | 1.2 cubic meters of water is not 9 gallons; proportional arithmetic does not repair the units | Held; no guessed unit correction |
| fa4af000-7c2b-5a7c-a0f2-222016a9d1e9 / HOA 056 | Prompt says “admits solutions”: A, B and D do; keyed C admits none | Held; replace its exact revision slice with verified HOA 179 |

Questions, keys, IDs, attempt history and exam memberships are retained. Sets containing a defective original are unpublished, rather than changing a historical source silently. These five source versions have no verified exact repairs; they stay excluded. No ACT or Math Level 2 source is used as a replacement.

## Final Revision coverage

The earlier pruning audit remains a historical record of commit 2c239765459ea8ccbc8b1a71ba10b2f255e7880d. This follow-up explicitly reconciles three corrected EST I versions after independently checking their current mathematics:

| Exact slice | Verified action |
| --- | --- |
| EST I / Inequalities and absolute value / Optimising a linear expression / hard / All and Unique | HOA 007: x≤4/3, increasing target maximum 2.5. Original revision hard/Unique metadata preserved, despite source-bank difficulty being medium. |
| EST I / Quadratics and polynomials / Reading a parabola graph / medium / All | AAF 048: source and embedded graphs checked; vertex (1,0), equation −(x−1)², I and III true. Restore one representative; AAF 050 remains inactive. |
| EST I / Probability and conditional probability / Union and overlapping events / medium / All | DAP 049: 25+10−5=30 favorable pens, probability 30/50, final requested half 0.30. Easy slice retained separately. |
| EST I / Systems of equations / No-solution conditions / medium / Must Know | Distinct already independently reviewed HOA 179, 97a4e8db-e914-5a56-a4c6-f3b6efe36600. a=25/2 makes coefficient rows proportional but constants 1/2 and 2/25 unequal. Defective HOA 056 stays held. |
| EST II / Quadratics and polynomials / Common polynomial factor / hard / All and Unique | Explicit exclusion continues: the matching source is Math Level 2, removed by instructor request. No verified distinct eligible EST II replacement found. |

These are deliberate mathematical certificate reconciliations, not an automatic refresh of stale rows. Batch repairs refresh only certificates that were current before the repair. Original lesson, idea, revision difficulty, track programmes and focused collections remain intact; no new Unique or Most Repeated provenance is invented. Representative cap remains two per exact source-track/lesson/normalized-idea/difficulty.

Live read-back after all changes: 0 available void keys, 0 missing available keys/explanations, 0 pending records without a review marker, 0 active held revision rows, 0 active stale revision certificates, 0 representative-cap violations, 0 ACT sources available in EST I, and 0 Math Level 2 sources available in EST II. Active revision counts are EST I 409 / 268 ideas, EST II 280 / 245 ideas, SAT 456 / 326 ideas; instructor removals account for the difference from the original prune totals.

Prior authorized live removal receipts: questions.est_act_removed.20260930 (634 questions), revision.est_act_removed.20260930 (35 rows), exams.est_act_removed.20260930 (50 sets); questions.est2_level2_removed.20260930 (199 sources), revision.remove_math_level2.20260930 (170 rows). The existing audit log contains before-state receipts.

## Validation and scope

Eleven isolated PGlite regressions cover all eight repair batches, the four later exclusions, the verified replacement and the three deliberate reconciliations. They check guarded source-version matching, exact key preservation, numeric results, original publication state where appropriate, stale-certificate preservation, explicit exclusion effects, revision metadata, cap and rerun rejection. Coverage mutation checks reject silent loss. The original prune coverage regressions remain enabled.

This audit covers the 430 previously unmarked records and the four revision restoration/replacement sources. Earlier review markers include source-keyed and visual/structural checks; they are not all equivalent to a new independent mathematical certification. Zero remaining unmarked records or a passing CI run is not a guarantee that every one of the 2,614 available EST I questions is error-free. Existing holds and exclusions remain enforced.

SQL files are immutable, one-shot live receipts guarded against the captured pre-update row digests; tests remap those digests only to isolated fixtures. Do not run old source-dependent scripts to overwrite these current corrections.
