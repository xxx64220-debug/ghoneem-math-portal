# September 2026 SAT intake

The 27-page SAT Valley September practice set supplied by Eng. Abdelrahman Ghoneem has 24 numbered questions. `questions.json` contains 21 independently checked, standalone SAT items, with source page, original number, choices, answer, explanation, skill, and difficulty. `audit.json` records the original PDF checksum and the three items held from grading. The original attachment remains in the user's file collection; its PDF is not copied into the public repository.

## Duplicate review

- The two August International II PDFs repeat the same 44 prompts. The SAT graded bank already contains 43, including a corrected negative-only version of its ambiguous Module 2 Q13 and the corrected fractional answer to Module 2 Q21. The defective original Module 2 Q18 is absent.
- The 44 August Prediction questions and all 50 MSET008 questions already appear in the SAT graded bank.
- All 120 detectable question IDs in the 129-page College Board-style packet appear in the SAT bank. Some PDF pages are continuations of a preceding item's rationale.
- None of the 21 September prompts matched a preexisting SAT source code or exact normalized stem. A second pass compared token overlap against all 918 existing SAT stems, and apparent nearest neighbors had different numbers, settings, or mathematical tasks. The SQL release checks source codes, exact normalized stems, and stable IDs again before inserting.
- The March International, March US, and Elite May files were subsequently audited in their own `content/sat-*` intakes. The 413-page SAT Panda workbook still needs a separate exercise-by-exercise intake.

## Held September questions

- Q18 (PDF page 18): the printed `6x⁴ + 35x + 11` conflicts with the proposed factorization into expressions in `x²`; the worked solution silently treats the middle term as `35x²`.
- Q19 (PDF page 19): depends on several angle labels in a small source diagram. It is held until a faithful student-facing figure is made and checked.
- Q24 (PDF page 24): the equation defining `g(x)` is absent in the rendered source page, while extracted text contains an expression. It is held until the exact original can be established visually.

## Release and verification

Run `python3 content/sat-sep-2026/build-release.py`, then review the generated `release.sql`. The SQL transaction inserts 21 graded `questions`, 21 private `question_keys`, and 21 SAT-only `revision_items`; it refuses duplicate source codes or exact normalized stems. It updates no preexisting questions, keys, student attempts, exams, or enrollments. The new revision items have recorded lesson, distinct idea, checked explanation and a concise method takeaway.

Run `python3 content/sat-sep-2026/build-backfill.py`, then review `revision-backfill.sql`. That transaction links 114 previously verified August International II, August Prediction and MSET008 questions to Final Revision. It requires existing private keys, substantive explanations and the prior verified review flag; twelve other missing-revision entries fail those conditions and remain out. Existing revision labels are preserved. The SAT formula lessons add related methods as individually rendered rules; the EST tracks do not inherit this addition.

The independent answer review covers the concentration equation, chained percentages, revenue vertex, integer inequality, extremal-data mean and spread, pyramid surface area, similarity scaling, altitude theorem, and sign chart. The build script additionally asserts several independently calculated results. After release, query the 21 new source codes and 114 new revision links and confirm their keys and revision fingerprints match. The existing checked questions are not reimported.
