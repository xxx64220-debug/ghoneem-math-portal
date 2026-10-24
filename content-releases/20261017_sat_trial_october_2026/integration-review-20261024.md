# Repository integration review — October 24, 2026

PR #37's original release commit is `c5e84306529774c38aee37069e45497377b44d68`. Integration was reviewed against main `21f954d60838dfdc683d54ab913015ddb2ba9a0a`.

The release payload, SQL, receipt, mathematical checks, transcription, duplicate review and 25 PNGs are unchanged from that commit. The only shared-file change relative to current main is the additional October intake CI step. Every existing CI job, step, permission and trigger is preserved, including `portal_math.test.cjs`; the separate Security workflow is byte-for-byte unchanged. This reconciliation does not add a deployment or production SQL runner.

## Release evidence

- The build definitions reproduce all 142 transcription records. All 137 UUIDs follow the original deterministic identity rule; the five repeated occurrences link to their canonical records. Source references, keyed choices and explanations agree across the build, transcription and payload.
- The source-mathematics suite passes for all 137 records, and all 25 embedded PNGs match their checked-in files and SHA-256 hashes. The diagrams were also visually inspected during integration review. The four documented numeric-description corrections retain the original verified choice letters.
- A read-only production transaction confirmed audit **20245**, timestamp `2026-10-17 10:16:18.722576+00`, release identity and original fingerprint. A separate read-only query compared every question/key payload field using PostgreSQL JSONB fingerprints: **137 matches, zero mismatches**. All 25 decoded production PNG hashes match; 137 records remain practice eligible and 106 remain daily-quiz eligible.
- The original production receipt records the preserved historical counts and original-question fingerprint. This review does not claim that unrelated production counts have remained frozen since October 17.

## Verification

The combined tree passed every runnable step of the JavaScript/Python CI job and the complete Security workflow locally, including locked dependency audits, math-rendering, taxonomy, figures, account/group authorization and public-artifact checks. Existing conditional source-fixture gates retain their normal skip behavior.

The exact original intake SQL was executed **only in disposable PGlite**, including actual grading and eligibility checks, key-access restrictions, replay rejection, late identity collisions, corrupt keys/options, missing or changed graphics and atomic rollback. Existing fixture questions, keys, examinations and attempts remain unchanged.

Fresh GitHub checks on the reconciled PR head are the final merge gate: JavaScript/Python, browser smoke, PostgreSQL and Security. Their results remain available on the PR's Checks tab.

No production SQL was replayed, no questions were reimported, and no examinations, assignments or historical results were changed. Reconstructing and assigning the separate October SAT module paths remains independent work.
