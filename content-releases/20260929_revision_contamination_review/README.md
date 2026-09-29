# June revision contamination review — September 29, 2026

Applied to the existing portal database after the reported linear-quiz corruption.
The previously repaired slope and midpoint questions are not counted in this batch.

## Scope and result

- Structurally scanned all 484 records in the two June full-revision imports.
- Reviewed 61 contaminated questions and their 61 matching records against the source and independent mathematical solutions.
- Also repaired two additional records with section-note leakage, both copies of a missing biscuit-transfer context, and both copies of a flattened-exponent question.
- Updated 128 records in total: 126 corrected/verified and two copies of one ambiguous coefficient question placed on hold with a void key.
- Restored five sets of overwritten answer choices from the original PDF; removed neighboring-question text, section notes, and watermark fragments.
- Restored grade-11 shared context, corrected the exact equal-card probability to 19/66, and clarified that the fractional-exponent question asks for a possible real value (the complete solution is ±64).
- Replaced generic verification statements with worked explanations.

Source: `DOC-20260623-WA0016_260916_184619.pdf`, 56 pages. The repair manifest records the physical page for every question. Pages 6, 18, 21, 26, 38–40, 44–45, 52 and 54 were visually inspected for graphs, overwritten choices, shared context and lost superscripts.

The coefficient identity on page 14 permits `(a,b,c)=(8,0,0)` and `(8,-1/4,-1)`, giving 8 and 5 respectively. The original question does not specify the missing condition. Both copies are held and marked unscorable. The live exam grader recognizes void keys and the daily selector recognizes release holds. Previously saved scores were not recomputed, and questions were not removed from existing exams.

## Verification

Run `python3 tests/revision_contamination_review.py` from the repository root. This test uses only local files. It independently enumerates cards, dice, letter arrangements and committees, checks both branches of the ambiguous identity, and checks restored exponents and shared-context calculations.

Live readback after application returned:

| Check | Result |
| --- | ---: |
| Reviewed records | 128 |
| Before/after audit entries | 128 |
| Held records with void keys | 2 |
| Mismatches against intended content and assets | 0 |
| Remaining watermark, section-note or neighboring-question markers in the two imports | 0 |

`apply.sql` preserves all question IDs, track assignments, existing exam membership, visual assets, unrelated release holds, and stored student responses/results. It locks rows, checks exact before images, writes the existing audit log, and applies the batch atomically. A replay skips records only if their reviewed state still matches. Concurrent content differences abort the transaction.

The scan does not certify every mathematical answer in all 484 records. The fully worked review covers the 128 records in `repairs.json`. Figure content was checked against the source PDF; existing figure URLs were preserved. Direct HTTP checks of those URLs returned 403 in this execution environment, so live browser image delivery is not claimed as verified.
