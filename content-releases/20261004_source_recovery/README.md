# Three authoritative source repairs — 4 October 2026

All three source pages were recovered and visually inspected. No answer letter, question ID, track, lesson, completed attempt, submitted answer or score is changed.

| Question | Source and repair | Verified key |
|---|---|---|
| `a62bb4f1-6a6d-46af-b5d3-72929458bc2b` | Drive `1sO50D2SCGnRzldtlNqXsdYuo9eVn1zkS`, MSET006 Q49: authentic scatterplot on PDF page 14, choices on pages 14–15, printed key on page 16. Independent checks of curvature, intercept, vertex and endpoint predictions support A. The first plotted year is 1; the old explanation's claim of an observed point at year 0 has been corrected. | A |
| `4ab54efe-2260-eeb3-dbf2-9909db0b4845` | Library `libfile_659c44a8f274819186f73969bb024aa4`, College Panda 10 Practice Tests, Test 1 section 4 Q3, PDF page 11. All four authentic graph choices are cropped together with their original letters and axes. A alone rises from home, stays flat, then returns home. | A |
| `f30234c6-7d80-1640-054d-97b86fde38ad` | Library `libfile_7eb9cc48b3e88191af0159f60dd47ec3`, December 2025 EST I Q8, PDF page 3. Text extraction drops radicals; visual inspection shows A: 29, B: √29, C: √40, D: √41. Restore the three radicals. Distance = √(4²+5²) = √41. | D |

`proof.json` records source PDF and static image SHA-256 hashes and crop coordinates. `est-q8-source.png` preserves the small source excerpt proving the lost radicals. Figures are opaque source renders, not redrawn graphs.

## Rollout

The connected production database was still in the pre-reliability-release state at discovery: none of the three holds or the new private eligibility helper had been applied. This bounded release accepts exactly the reviewed original state, or exactly that original state with the matching October 4 hold. Any other content change aborts the entire transaction. It does not apply unrelated October 4 repairs or function changes.

1. Publish the two matching static figures at the existing custom domain.
2. Run `apply.sql` only after that asset deployment succeeds. This script locks the relevant rows and refuses to run during an active attempt.
3. Verify the three repairs and all replacement mappings. The script creates fresh exam IDs for every currently published exam containing one of these questions, copies the existing audience and opening/closing windows, and unpublishes the original exam. It does not move historical attempts or change their assignment IDs. Completed results remain accessible through the existing Exam history view, whose server function includes unpublished exams.

Discovery found four affected exams:

| Original exam | Original ID | Historical attempts at discovery |
|---|---|---|
| Quizz day 2 | `6f9db392-8928-496d-a79a-735543eeb396` | 1 expired |
| Day 6 | `93319fd8-6a05-4391-9936-8b5ab83ae19a` | 1 graded |
| Coordinate geometry — Reviewed practice 1 | `5841cdca-6743-42e4-bac4-d262d724ee22` | none |
| Interpreting distance-time graphs — Reviewed practice 1 | `061ec83d-f997-422a-9177-b0c6a83febf3` | none |

Replacement titles end with “Source-corrected v2 (Oct 2026)”. Durations, assessment types, order, shuffle, review policies, scoring maps and attempt limits are copied. All 60 distinct questions in the affected papers passed a bounded structural preflight; that check is not a new mathematical certification of every sibling question.

Audit entries retain exact before-content and original exam records. `rollback.sql` refuses to overwrite later question changes or roll back replacement exams with attempts. It preserves the replacements as unpublished audit rows. Do not replay the older `20261004_question_reliability/apply.sql` after these repairs: its original content guards correctly reject the newer state.

## Validation

`tests/source_recovery_db.cjs` runs only in isolated PostgreSQL/WASM. It covers original and held baselines, concurrent content changes, whole-transaction rollback, active-attempt refusal, four replacement versions, audience/window copying, unchanged history/answers/scores, no automatic revision reactivation, replay rejection and guarded rollback. Existing reliability and figure/client regressions are also retained. Desktop/mobile browser coverage renders all three recovered records with the real assets; CI discovers the expanded existing browser spec. Local Chromium installation was blocked by a truncated browser download.
