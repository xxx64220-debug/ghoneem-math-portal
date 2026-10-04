# Remaining skill labels and four assessment defects

146 current EST I questions had the skill label `Needs classification`. Review of their stored stems and choices assigns a specific skill to every record and corrects 19 canonical lesson assignments. Eight existing source holds remain held. Classification describes the mathematical subject; it does not certify the answer key or recover missing source material.

The review also found four concrete defects: a slope coordinate yielding no valid choice, an undefined expression with corrupted option powers, a weighted mean with no correctly rounded choice, and an unreadable requested exponent. `packet.json` records the evidence. Original stems, choices, keys, explanations and source assets remain preserved, with a release hold excluding each defective original from new practice.

Four assessments without attempts receive independently checked replacements: two existing complete questions, the previously reviewed weighted-mean adaptation, and one explicitly authored inverse-proportion adaptation. The new adaptation asks for a squared value and includes its rounding rule; it is not claimed to reproduce the unreadable original. Five assessment titles receive canonical lesson or mixed-skill names and a stable eight-character identifier. Question counts, timers, publication, assignment audiences and every other assessment setting remain unchanged.

`apply.sql` applies this bounded release atomically. It guards all 146 original question/key records, revision membership, five exam records, assignment digests, the existing weighted-mean adaptation, unexpected published uses and new student attempts. It keeps private before/after records and refuses replay. No student identifiers or assignment rows are included in the checked-in packet.

Build with `python scripts/build_remaining_skill_review.py`. Validate with `python tests/remaining_skill_review_math.py` and `PGLITE_MODULE=<installed @electric-sql/pglite path> node tests/remaining_skill_review_db.cjs`. The database fixture tests preservation and release guards; synthetic unchanged questions do not constitute mathematical certification. Existing browser checks continue to verify the shared question/asset rendering paths.

`rollback.sql` is deliberately limited to taxonomy fields and exam titles. It retains all four proven source holds, the verified exam replacements and the new adaptation. It refuses later question/key or exam edits. Restoring defective originals as eligible assessment questions requires a separate source-backed review, never this rollback.
