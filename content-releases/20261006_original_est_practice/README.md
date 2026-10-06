# October 6 original EST I practice expansion

Adds 50 instructor-authored EST I MCQs: the 24-question practice pack and 26 new variations inspired by the web-source shortlist. Thirteen questions include original embedded PNG graphs or diagrams. Every item has four distinct choices, one independently solved answer and a worked explanation.

Search the bank for `GH-EST-OCT26` (codes 01–50). Topics include percentages and ratios, scale and similarity, means and distributions, lines, circles, quadratics, exponents, probability, absolute value, composition domains, polynomial factors and remainders, and graphical inequalities. No sequences or EST II-only content is introduced. Difficulty labels are instructor estimates, not calibrated predictions of the exam.

Reference links identify skills and ideas only. These questions are new practice, not official EST or SAT items. Graphs were drawn from recorded numerical specifications and visually checked. Mathematical specifications stay in this private review packet; student assets contain the rendered figures and provenance, not answer keys. Answers and explanations go only into the existing private `question_keys` table.

## Validation

`python tests/original_est_practice_math.py` checks all 50 answers using arithmetic, exact fractions, enumeration, domain boundary samples and graph-model comparisons, plus unique choices and PNG hashes. `tests/original_est_practice_db.cjs` runs the actual SQL in isolated PGlite, checking exact content, question eligibility, preserved existing questions and student history, replay/collision rejection and rollback on failures late in the packet. Tests never use production.

The duplicate review examined all 3,424 existing EST records: no normalized exact-stem match was found. High-similarity prompts were reviewed for different values, figures or requested outputs. Intentional variants of existing skills remain available for practice.

## Insert-only application

`apply.sql` is an atomic, guarded release. It inserts 50 questions and 50 private keys, then records one audit event. It rejects previously applied releases, existing IDs/source codes, normalized duplicate stems, invalid answers/choices and missing required images. It fingerprints existing question fields and keys and rejects unrelated changes. There are no assessment, revision, assignment, attempt, score, user, schema or frontend writes. Images are embedded in the existing supported assets format, so no frontend deployment is required.

Production application and final verification are recorded below after successful execution.
