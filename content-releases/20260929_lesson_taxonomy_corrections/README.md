# Lesson taxonomy audit corrections — 29 September 2026

Independent review found 13 over-broad classifications in the original 6,916-row taxonomy: one function-range question, seven cofunction-identity questions, and five factor/remainder-theorem questions. `assignments.json` records the evidence and the exact lesson-only changes.

`apply.sql` is a guarded follow-up to the already-recorded `question.lesson_taxonomy.20260929` release. It refuses to run without that base audit, refuses a second application, verifies each target's ID, track, old lesson, and taxonomy version, preserves all non-taxonomy question data and detailed lesson assets, updates matching revision lessons, and records 13 audit rows. It does not change mathematical content, keys, explanations, release holds, exam membership, sessions, attempts, or scores.
