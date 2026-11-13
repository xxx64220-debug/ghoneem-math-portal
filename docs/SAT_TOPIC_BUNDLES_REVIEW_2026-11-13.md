# Topic bundles for all groups — proposal awaiting approval

No production deployment, SQL mutation, rollout change, student attempt, score or enrollment change was performed for this proposal. This document retains its original filename so existing review links continue working.

## Scope and existing architecture

The current draft extends Practice Bundles to every enrolled student in all six supported courses. Group membership is not a feature gate: students in different groups or multiple groups use the same course workspace, while their answer history and progress remain personal. Existing enrollment, active-account, device and authentication checks stay authoritative.

| Course | Main topic organization |
|---|---|
| SAT Math | Algebra; Advanced Math; Problem-Solving and Data Analysis; Geometry and Trigonometry |
| EST I Math and EST II Math | Existing Algebra, Advanced algebra, Geometry, Trigonometry, Statistics/probability/data and additional bank-topic sections |
| ACT 2 Math | Existing mathematics sections, including Additional mathematics for matrices, vectors and related lessons |
| EST English and SAT English | Existing reading, conventions, expression of ideas, craft/structure and English-skills sections |

Every course supports whole lessons and nested subtopics, difficulty, 1–100 questions, exact eligible counts, and exclusion of previously answered questions. Only sections represented in the course's eligible bank are listed, except SAT's four fixed domain choices. Missing subtopic tags show **General lesson practice**. Tags are taken from `assets.lesson_subtopic`; no question content is guessed or relabeled.

The initial source inspection found Site v189 at `a68ba44524226da1a6b24e4586c3e09757c8392a`, ahead of GitHub main `1237eb14a9bfe2268beacd8f9bd789707cf08c72`. Practice Bundles was already hosted and its database rollout enabled. The PR's first commit preserves that existing service and dependencies, adapting static copies to GitHub's `dist/`. Subsequent commits are the proposed hierarchy and all-course extension. The live catalogue definition still matched the reviewed hash when rechecked for this extension; the proposal metadata table did not exist.

## Proposed changes

| Files | Result |
|---|---|
| `web/practice-bundles.html`, `.js`, `.css`, `bundle-core.js` and static copies | Nested lesson/subtopic controls; counts follow difficulty and repeat exclusion; refresh preserves selections, even at zero availability. Failed catalogue loads disable creation. |
| `web/final-revision.js` and static copy | A course-specific **Custom topic practice** shortcut for SAT, EST I and EST II, the courses supported by Final Revision. The existing hosted global Practice Bundles navigation already serves all six courses. |
| `supabase/sql/practice_bundle_hierarchy.sql` | Guarded upgrade of four existing functions and a private, trigger-maintained subtopic cache for all six courses. It supersedes the unapplied SAT-only proposal; do not apply both. |
| Tests and `.github/workflows/sat-topic-bundles.yml` | All-course filtering, history, eligibility, isolation, saves, grades, rendering and enrollment regressions. The workflow runs tests only, with no production credentials or deployment step. |

Whole lessons and chosen subtopics form a union; domain and difficulty intersect that selection. Choosing a whole lesson clears its individual subtopic checkboxes. Choosing a subtopic clears its whole-lesson checkbox. No checkboxes means all lessons in the selected main topic.

If fewer questions remain than requested, creation is disabled and **Use N available questions** offers an explicit count change. The server rechecks eligibility and history at creation and rejects a shortage without inserting a smaller bundle or repeating answers. SAT supplementary/unclassified topics remain outside the four-domain pool; other courses retain their existing topic coverage.

## Repeat prevention and preservation

The unchanged history query checks saved nonblank responses in exam/assignment attempts, notebook tries, Daily Quiz, drills, Final Revision, and partial/completed practice bundles. It has no recent-session limit. Correct and incorrect responses both exclude that exact question ID; blanks and other students' answers do not.

Similar ideas with different IDs can still appear. Unsaved answers or erased history cannot be reconstructed. Existing grading, explanations, immutable completed results, retakes, autosave and resumption are reused. Exams, assignments, Today objectives, Daily Quiz points and historical scores are not rewritten. Access to a course still requires the existing active enrollment.

## Validation

- **37 focused Node tests passed with no skips**, including nested controls in every course, shortages, correct course/subtopic payloads, saved progress, auth, mathematical rendering and Final Revision shortcuts.
- **71 existing database assertions passed against the expanded upgrade**, spanning six courses, grading, retakes, key privacy, holds, owner isolation, cache behavior and historical scores.
- **162 hierarchy database assertions passed**: SAT domain selection plus all-course metadata backfill and updates, exact counts, six history sources in every added course, students in separate/multiple groups, enrollment restrictions, peer isolation, shortages without inserts, malformed settings, retakes, score preservation and migration replay rejection.
- Browser fixture: switched through all six courses, checked course-specific section labels and nested subtopics, verified an English shortage and an EST II selected-subtopic count. No live practice request or student write was made.
- Earlier unchanged-layout verification covered desktop and a 390px mobile viewport with no horizontal overflow. The earlier broader hosted-source regression passed 139 tests with three pre-existing skips. Those results are supplemental, not claims of new live validation.
- Source/static parity, syntax checks and `git diff --check` passed. GitHub reruns are tracked on the current PR head.

All tests use synthetic users/questions in isolated PostgreSQL/WASM or browser fixtures. Authenticated staging/production testing of this unapplied upgrade remains outstanding.

## Deploy only after approval

1. Refresh the current hosted source and database hashes; reconcile concurrent work before changing production.
2. Apply only `supabase/sql/practice_bundle_hierarchy.sql`. It checks the four reviewed function hashes and rejects drift/replay. Do not replay `practice_bundles.sql` or `question_eligibility_cache.sql`, which document the already-live baseline.
3. Deploy the five changed frontend files and their static copies. No existing Edge Function redeployment, rollout toggle, enrollment edit or group-by-group setup is required.
4. Check an enrolled test account's catalogue and selection in each relevant course, saved-answer exclusion, explanations and navigation; confirm ordinary exams, assignments and Today still behave as expected.

Rollback restores the previous four function definitions from `practice_bundles.sql` and the previous frontend files. Retain practice records and the small metadata cache/trigger; never delete or recompute historical student results.

## Reproduce

```bash
npm ci --prefix tests/device-runtime --ignore-scripts --no-audit --no-fund
npm ci --prefix tests/passage-runtime --ignore-scripts --no-audit --no-fund
npm ci --prefix tests/english-runtime --ignore-scripts --no-audit --no-fund
node --test tests/practice_bundles.test.cjs tests/practice_bundles_dom.test.cjs tests/practice_bundle_auth.test.cjs tests/final_revision.test.cjs tests/portal_math.test.cjs tests/practice_figures.test.cjs
node tests/practice_bundles_db.cjs
BUNDLE_HIERARCHY=1 node tests/practice_bundles_db.cjs
node tests/practice_bundle_hierarchy_db.cjs
```
