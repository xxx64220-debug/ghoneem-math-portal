# Uploaded EST notes bank addition — 5 October 2026

Source: `Notes_261005_140129.pdf`, 12 pages, SHA-256 `c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c`. The source is a teacher-uploaded notes packet, not a named official sitting. The release targets the existing EST I track (`est`) only.

## Review outcome

- 20 source questions were identified across pages 1–12.
- 14 complete questions are added with independently worked keys and explanations.
- 3 duplicate questions are excluded: the exact circle translation already in EST (`a8928d2f-90e9-f05d-6dfd-5425820e7b96`), the exact perpendicular-bisector question already in EST (`bb6c8acb-c9e2-532c-ba7d-3306a0d10091`), and the same chained-ratio idea already covered by `d4ba140c-c921-52b0-8d2c-a4fb03baafda`.
- 3 items remain held: the exponent equation has two real solutions although the provided options include only one approximate root; the parabola triangle item has no choices in the notes and its answer is irrational (`3√3`), so it does not fit the numeric-only grid-in field; the score item does not say the student answered all 50 questions, so its key would depend on an unstated assumption.

No existing question, answer key, exam, assignment, revision item, attempt, answer, or result is edited. The new parabola figure is a clean SVG reconstruction from the equations and coordinates stated in the source. Tables are transcribed into the stem. No assessment or Final Revision membership is created.

## Verification

Run `python tests/est_notes_20261005_math.py`. `apply.sql` is an insert-only, atomic transaction. It refuses replay, colliding IDs, normalized-stem duplicates, an unexpected track or exam membership, and any change to existing exams, assignments, attempts, answers, results or revision membership. It records per-question provenance in the existing audit log.

The questions remain in the searchable EST question bank for staff to use; they are not appended to existing exams or the Final Revision set.
