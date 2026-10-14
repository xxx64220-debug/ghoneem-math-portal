# Consistent lesson classification — 29 September 2026

Consolidates question-bank names into the formula lesson vocabulary and keeps SAT, EST I and EST II memberships unchanged. Detailed skills are retained as `assets.lesson_subtopic`; previous topics as `assets.lesson_original_topic`. Advanced concepts outside the existing formula vocabulary remain separate named lessons.

`assignments.json` records 6,916 question-to-lesson decisions. Sources include existing revision labels, unambiguous topic aliases, question wording and individual review of ambiguous imports. This is a taxonomy review, not a new answer-key certification.

`apply.sql` locks the two affected tables, checks the reviewed question-bank fingerprints, records original labels in `audit_log`, updates question and revision lesson names together, and checks that question content and non-taxonomy assets have not changed. It refuses a second application. Answer keys, exam membership, historical sessions and student scores are untouched.

The shared browser catalogue supplies authoring options and rejects missing, mixed or unknown lesson names on math JSON imports. English categories retain their existing behavior. Formula lesson names use this same catalogue, with advanced track formula variants retained.
