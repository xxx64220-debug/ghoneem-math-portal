# DSAT 117 V2 Math intake — held for review

The supplied 69-page PDF contains 27 Reading/Writing baseline items, two alternative 27-item Reading/Writing second modules, and Math baseline/easy/hard modules of 22 questions each. Only the 66 Math positions are in scope for the SAT Math bank. The two exam paths are M1+M2 easy and M1+M2 hard; combining all 66 into one student test would misrepresent the source structure.

Source SHA-256: `9d6f71a1b55f12d08cbec5502790bc4d4495d914151eb365e3655a4c8d1b4696`. The source PDF was provided privately and is not committed here. `manifest.json` reserves stable source codes and two exam plans. This branch does not alter bank records, keys, exams, assignments, attempts, or production.

## Verification blockers

- Source pages contain printed answers immediately after items and handwritten solutions or marks. Student assets must be reconstructed without answer leakage.
- Several passages contain stray `[ Meo ]` / `[ bluecorn.org ]` tokens and mathematical symbols corrupted by PDF extraction. OCR loses exponents, fractions, equations, and graph information. Every question must be visually transcribed and checked against the page, including graph/table crops.
- Printed keys are not independent verification. Solve each item, record a worked explanation, and hold any ambiguous or inconsistent item.
- Compare normalized stems, options, givens, and required figures with the existing SAT bank; link duplicates instead of creating duplicate records.
- After review, stage insert-only `questions` / `question_keys` records, create two unpublished 35-minute-per-module exam paths using the shared first module, test grading and student render, then explicitly review before release. Do not assign or publish based on this manifest.
