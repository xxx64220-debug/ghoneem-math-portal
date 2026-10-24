# SAT Trial 2026 October

Imported the mathematics sections of the two instructor-supplied Bluebooky trial PDFs into the existing SAT bank. The collection has 142 source occurrences: Paper 1 has 24 baseline, 25 easy and 27 hard items; Paper 2 has 22 in each of those sections. These are alternative module paths, not one 142-question exam. No English content or new assessment is added.

The release inserts 137 unique questions (106 MCQs and 31 student-response questions), all with independently worked explanations, the existing canonical lesson vocabulary, and searchable source label **SAT Trial 2026 October**. Twenty-five original diagrams are embedded losslessly. Source filenames, SHA-256 hashes, page/module/question references and the five repeated occurrences remain attached to the canonical entries. Baseline difficulty is recorded as medium; easy/hard follow source labels and are not calibrated difficulty estimates. The requested collection label is not a claim of independently verified official exam provenance.

Search Admin → Question bank → SAT for `SAT Trial 2026 October`, or individual codes `SAT-OCT26-P1-M1-01` etc. All 137 items are eligible for practice and exam construction; the 106 complete MCQs also pass the existing daily-quiz content gate. Group assignment and scheduling still use the portal's existing rules.

## Source review

Both scanned papers were rendered and their mathematical givens, choices and diagrams checked visually. Publisher tags embedded in sentences were omitted from searchable text. Tables were transcribed as labeled pairs when this is clearer in the existing renderer. Original diagrams were cropped without answer lines. `transcription.json` preserves all 142 source positions; `review.json` contains the exact 137-row payload and private keys, and `figures/` contains the exact embedded PNG bytes. Private keys and explanations are stored only in `question_keys`; no answer fields or worked solutions were put into student assets.

Five exact repeats were linked instead of inserted again:

- P1 hard Q12 → P1 easy Q5 (graphical inequality).
- P1 hard Q17 → P1 easy Q20 (triangle midpoint).
- P2 baseline Q8 → P1 baseline Q8 (similar triangles).
- P2 hard Q9 → P2 easy Q4 (exponential y-intercept).
- P2 hard Q13 → P2 easy Q19 (vehicle percentages).

The separate Paper 2 key has malformed numeric descriptions: baseline Q18 prints `1/122` instead of `1/√2`; easy Q3 prints `2/552` instead of `2/5`; easy Q4 and hard Q9 print `(0,217)` instead of `(0,2/17)`; hard Q8 prints `1/1991` instead of `1/9`. The correct choice letters agree with the independently solved choices. `source-key-corrections.json` records these findings.

Duplicate review used all 2,184 existing SAT records, normalized text, option comparisons, numerical givens and requested outputs, with manual review of near matches. No identical existing bank item was identified. Related skills with changed mathematical givens, graph values or requested outputs remain distinct. A generic graph prompt alone is not considered a duplicate.

## Validation and application

- `python tests/sat_trial_october_2026_math.py`: all 137 solutions, arithmetic/domain/choice checks, graph specifications, canonical taxonomy, all 142 references and all 25 PNG hashes.
- `PGLITE_MODULE=<isolated-module-path> node tests/sat_trial_october_2026_db.cjs`: exact SQL application and field readback; actual grader; 31 student-response / 106 daily MCQs; existing questions, keys, exams and attempts preserved; anonymous/student roles cannot read keys; replay rejection and atomic rollback for late source collisions, invalid keys, public answers and missing/modified images.
- Existing lesson taxonomy and practice figure renderer regressions passed. CI adds these intake checks without removing any existing checks.

`apply.sql` is an insert-only atomic release. It rejects repeated release/source identities, invalid keys/options, image hash mismatches, ineligible records and unrelated question/key changes. It does not change schema, runtime, assessments, assignments, revision membership, groups, accounts or historical results.

**Already applied on October 17, 2026 at 10:16:18 UTC (audit 20245). Do not replay.** Production readback found all 137 records with zero payload mismatches, all 25 exact PNG hashes, 137 practice-eligible items and 106 daily-eligible MCQs. The SAT bank increased from 2,184 to 2,321 records. The complete fingerprint of all older question and key fields is unchanged, and exam/assignment/attempt/enrollment/group/revision counts match the baseline. See `production-receipt.json`. No frontend deployment is needed for these embedded content records.
