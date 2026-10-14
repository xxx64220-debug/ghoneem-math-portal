# Reviewed exam replacements — 5 October 2026

The new structural guards stopped 30 published EST I/EST II assessments because they referenced 26 held records. Seventeen copies have genuinely ambiguous or incorrect June source wording, eight EST II records have text-only diagram transcriptions, and one copy is superseded by a verified duplicate.

This packet restores the assessments using **16 independently solved instructor adaptations** and two existing independently checked questions. Adaptations have new stable IDs, explicit missing conditions, full worked solutions, canonical curriculum lessons, and eight SVG diagrams generated from their mathematical givens. They are labeled `content_origin: instructor_adaptation`; none is claimed to be a recovered source question or authentic examination item. The archive `Kimi_Agent_Math PDF Question Bank(4).zip` contains the eight text transcriptions but no corresponding T6/T7/T9/T10 diagram files.

- 25 never-attempted assessments update in place. Membership guards reject any unexpected attempt or edit.
- Five attempted assessments receive new versions with the same group/user targets and open/close windows. Original question lists, attempts, responses, marks and review policies remain intact. Original versions retain publication for access to student history and carry `Historical version (held)` in their titles. They remain blocked for new starts; this is intentional, not an unresolved replacement.
- All 30 current corrected versions keep their original counts and timers. The two 40-question/60-minute EST II full-practice sets mislabeled internally as quizzes receive the full-exam type and one-attempt limit only in their corrected versions. Canonical lesson names replace obsolete or unspecified labels in the affected EST I assessments; replacement EST II titles omit the obsolete `Math Level 2` label.
- The original 26 held question records and their keys are unchanged. Duplicate and fairness-die replacements use the verified existing IDs, avoiding unnecessary copies.
- One additionally discovered, unused interest copy falsely claims `6000 × 1.05⁸ ≈ 8950.95`. The correct result is `8864.732662734377`; the implied rate for 8950.95 is approximately 5.1271123%. This copy is held while its key and historical data are preserved. The instructor adaptation states rounding to the nearest whole percent explicitly.

## Safety and validation

`guards.json` contains PostgreSQL-produced fingerprints for all 564 original assessment/canonical question records, all 30 exams, their assignment targets, and whether they have history. SQL rejects concurrent question, exam, assignment, history or revision changes. The release is atomic and rejects replay. Backups reside in an unexposed private schema with RLS and no anonymous/authenticated table privileges.

Tests cover each adaptation's mathematics, choice uniqueness, explicit assumptions, actual SVG geometry, all 30 corrected assessments, original keys/history/audiences, five historical versions, keyless history payloads, concurrent-change rejection and rollback refusal after new exam or practice use. Browser tests render all 16 questions and the eight diagrams in desktop/mobile exams, daily practice, drills, notebooks and revision, with all external endpoints mocked.

Healthy unchanged members of the disposable database fixture are synthetic. These tests validate the release and substitutions; they do **not** certify the mathematical accuracy of all 564 unchanged questions or the entire bank.

## Apply and rollback

Run `apply.sql` only after tests and fresh fingerprints pass, using the existing production Supabase project. No frontend or hosting change is required; the current shared renderer already supports the inline SVGs.

`rollback.sql` refuses to discard newly created exam/practice history or overwrite later edits. If safe, it removes unused adaptations and cloned versions, restores old titles and memberships, and leaves the 25 unused assessments as **drafts** rather than republishing held content through the new guard. The five historical versions retain their original publication state. Reapplication after rollback requires a freshly reviewed packet and current fingerprints.

Regenerate deterministically with `python3 scripts/build_reviewed_exam_versions.py`. Mathematical verification: `python3 tests/reviewed_exam_versions_math.py`. Disposable database verification: `PGLITE_MODULE=... node tests/reviewed_exam_versions_db.cjs`.
