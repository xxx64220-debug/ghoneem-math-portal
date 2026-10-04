# Question reliability release — 4 October 2026

Published exams and practice must not introduce held, removed, void, malformed or incomplete records. A private structural eligibility helper now guards publication, exam start/resume, notebook retrieval/grading, daily generation/frozen sets, weak-topic drills and new Final Revision sets. Completed historical results remain available. Structural eligibility does not certify mathematical correctness or fidelity to an original source.

The publish trigger covers the existing admin publish-only path as well as direct exam writes. Students see **Under review** for affected exam cards and can still review completed attempts. The legacy exam builder now selects an exact canonical lesson rather than a substring match.

Final Revision builds its catalogue and candidate pool from metadata. It hydrates stems, choices and assets only after selecting up to 10/20 questions, then rechecks current eligibility and fingerprints. Existing saved revision snapshots remain intact.

## Content repairs

The guarded release touches 15 existing IDs without changing any answer key, track, lesson, exam membership or student score:

| Repair | Records |
| --- | ---: |
| Remove neighboring chapter/exercise headings and add worked solutions | 10 |
| Restore Elite May Module 2 Q21 graph and verify answer C | 1 |
| Add Panda statistics Q9 worked solution; retain D | 1 |
| Hold distance question with no correct stored option | 1 |
| Hold missing scatterplot and missing graph-choice item | 2 |

The Elite graph is rendered with an opaque white background directly from original source page97; its complete prompt and choices were checked on page98. The source PDF hash matches the import. `elite-restoration-proof.json` records a conservative regression-influence check: the y-intercept decreases and the quadratic coefficient increases when the erroneous central point is removed. It does not invent exact point coordinates.

The browser now decodes UTF-8 SVG data-URI figures through the existing markup allowlist. All 16 actual attachments have a regression fixture. Scripts, event handlers, external references and malformed SVGs are rejected or stripped. Source data remains unchanged.

## Rollout and recovery

1. Apply `supabase/sql/question_eligibility.sql` to the existing database. Exact function-definition hashes reject concurrent changes. Existing ACLs are preserved; new helpers are private and unavailable to browser roles.
2. Apply `content-releases/20261004_question_reliability/apply.sql`. Every record and revision entry is locked and compared with the reviewed hash before mutation. A private backup stores prior choices, assets, explanations and revision metadata.
3. Publish the matching web/dist assets to the existing Site. Preserve the current domain and Supabase project. Both the live navigation enhancement and main’s diagnosis CSV export are present.
4. Verify affected hashes, active revision fingerprints, frozen question pools and exam readiness with read-only queries. Tests run only in isolated local PostgreSQL/WASM or mocked local browsers.

`rollback.sql` refuses to restore over later content/revision changes and restores the backed-up data transactionally. It leaves all keys, membership and scores untouched. Restoring function behavior is a separate reviewed operation using `functions-before.sql`; do not casually remove the eligibility guard while damaged records remain published.

## Validation and remaining work

`tests/question_reliability_db.cjs` covers every active track, numeric/alternative grid-in keys, publication-only rejection, start/resume, notebooks, frozen daily quizzes, drills, exact lesson selection, metadata-only catalogues, hydrated revision sessions, private helper ACLs, late-error transaction rollback, release replay rejection, rollback and reapply. Desktop/mobile browser coverage checks preserved history and SVG rendering through exams, revision, daily quizzes, notebooks and drills.

The next audit queue remains source recovery for the three newly held records, clean replacement exam versions where question holds affect existing papers, unknown-skill classification, bank pagination/lazy previews, and independent mathematical/source review of the remaining bank. This release does not mark the full bank as mathematically certified.
