# Final Revision idea-loss audit — 30 September 2026

Audited commit `2c239765459ea8ccbc8b1a71ba10b2f255e7880d`, release SQL, revision manifests/releases, and read-only current portal rows. No question or production revision row was changed. A fresh fingerprint is not mathematical certification; this audit does not silently refresh fingerprints or reactivate sources.

## Exactly three normalized lesson/idea groups disappear

| Track | Lesson | Idea | Revision difficulty | All candidates | Cause | Focus lost |
| --- | --- | --- | --- | --- | --- | --- |
| EST I | Inequalities and absolute value | Optimising a linear expression | hard | HOA 007 (`afee4921-ee14-551e-abe7-c86f4f3acb45`) | Fingerprint stale; no hold | Unique |
| EST I | Quadratics and polynomials | Reading a parabola graph | medium | AAF 048 (`b515a6ed-1c6f-5848-b2b4-12c02a5d4524`), AAF 050 (`0f808148-2950-5c6c-b3de-637ce88d6c56`) | Both fingerprints stale; no holds | None |
| EST II | Quadratics and polynomials | Common polynomial factor | hard | EST2-L2-DEC2020-Q09 (`a0c46847-72c6-581c-8eae-e24748c74a81`) | Fingerprint stale; no hold | Unique |

These are source-not-ready losses, not representative-cap losses. Their manifest fingerprints match the stale revision fingerprints. Source corrections occurred after the manifests were built: HOA 007 has the independently worked maximum 2.5; AAF 048/050 have recovered shared parabola context and answers D/B; the EST II polynomial choices were repaired by `20260928_daily_quiz_missing_context.sql`, answer −8. Verification metadata is present on current sources, but their revision certification fingerprints were never reconciled to the corrected versions. The classification-only prune correctly refused those changed source versions.

The SQL definition of `ready` checks holds and fingerprint equality; it does not itself establish independent mathematical verification. All four affected rows are unheld and fingerprint-stale. The synthetic fixture proves the aggregate reduction, but its original `Idea 299`, `Idea 300`, and `Idea 368` names cannot identify real portal lessons. The updated fixture gives the stale-only groups the actual names and lost Unique focus, while keeping synthetic question content.

## Replacement search and explicit exclusions

Search covered existing EST I/II source stems, detailed skills, keys/explanations, verification markers, active revision rows, and checked-in revision manifests/releases. A verification marker alone was insufficient to accept an unrelated or source-key-only item.

* **Linear optimisation:** HOA 054 (`3d79b5c1-fe84-5cba-96da-2a470fbf0121`) is a distinct independently worked, source-checked candidate: x≤5/3, maximum 6.5, key D. HOA 116 (`32dab31e-cd82-5355-bec6-95c6cbb8abf2`) also has an independently worked bound. Both source difficulties are medium. Neither replaces the exact hard slice without an editorial difficulty change. Exclude the hard All/Unique slices pending a verified hard replacement or explicit reviewed reconciliation of HOA 007. Do not manufacture a hard label or Unique provenance.
* **Parabola graph:** June item `42023659-d382-865a-80ae-05cbd582fc6f` and copy `6ea81a14-c958-830c-d582-7a6502bb9f8d` are a verified graph-to-equation candidate (vertex (−2,−3), answer B). They are duplicates of each other and currently classified under Functions and transformations, not the vanished Quadratics and polynomials lesson. Other graph-evaluation/inequality candidates likewise belong to Functions and transformations. Do not import both copies or silently move their lesson. Exclude the exact medium Quadratics slice pending a distinct verified candidate in that lesson or explicit reviewed reconciliation of AAF 048/050.
* **Common factor:** the only matching EST II source is the stale existing representative. `e04957e5-b3a2-5e5d-9f1b-f49fb7325540` is its EST I shared copy, not a distinct EST II replacement. No eligible distinct same-track replacement was found. Exclude the EST II hard All/Unique slices pending a verified distinct source or reviewed reconciliation of the corrected original. No cross-track substitution.

These are explicit exclusions of the existing release, not a claim that the ideas are unsuitable or that the current original questions are mathematically wrong. Reconciliation requires reviewing the exact changed source version and deliberately updating its revision fingerprint; it is separate from merely lifting a hold.

## Additional difficulty loss

EST I / Probability and conditional probability / Union and overlapping events loses its **medium All** slice: DAP 049 (`4e5d0e24-836e-5e18-85af-6868807dc27e`) is unheld but fingerprint-stale. Its ready easy representative (`022b3fdc-5d52-5f55-a3f1-d309e62e6035`) remains. Explicitly exclude the medium slice rather than counting the easy row as its replacement. This explains why total normalized idea counts reveal only three losses while exact difficulty coverage reveals four.

## Regression guard

`tests/final_revision_prune_coverage.sql` compares the complete intended catalogue against retained All, Must Know, Most Repeated, and Unique slices using exact source track, lesson, normalized idea, difficulty, and collection. It explicitly lists the six historically excluded slices (four All, two Unique). It rejects any additional unexplained loss and rejects any exclusion that discards every ready representative. Unlike the old guard, it does not remove unready candidates from the intended baseline.

The in-memory runner tests successful pruning, protected-data preservation, cap and rerun rejection, and mutations that remove an entire idea or only its Unique collection. PostgreSQL CI also runs the new coverage assertion. All executable regression tests run on isolated fixture databases. Production was queried read-only only to establish audit facts; it was never connected to test runners.

The earlier README's “Every existing ... slice remains represented” statement should be read as **every ready pre-release focused slice**; two stale-only Unique slices were actually lost. No verified replacement satisfying all existing track/lesson/difficulty/duplicate constraints was selected by this audit. Counts remain 1,344 active rows, EST I 298 ideas and EST II 367 ideas.
