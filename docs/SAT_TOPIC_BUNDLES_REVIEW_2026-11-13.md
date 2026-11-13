# SAT topic bundles — proposal awaiting approval

No production deployment, SQL mutation, rollout change, student attempt or score change was performed for this proposal.

## Verified starting point

The live Site was version 189. Its source HEAD was `a68ba44524226da1a6b24e4586c3e09757c8392a` when retrieved on 13 November 2026. GitHub main was `1237eb14a9bfe2268beacd8f9bd789707cf08c72` and lacked the already-hosted Practice Bundles files. The live database's bundle rollout flag was already enabled before this work. Final Revision matched between these sources.

The existing bundle service already provides 1–100 questions, difficulty filtering, exact-ID repeat exclusion, autosave/resume, server grading, private answer snapshots, completed-result immutability and separate retakes. Building another session engine inside Final Revision would duplicate that current functionality. This proposal adds a SAT-only link from Final Revision to that same workspace and extends its controls.

The draft PR contains two commits. The first preserves the already-hosted bundle source and its dependencies in GitHub, adapting static-file parity checks to this repository's `dist/` directory. It does not replace the main page or navigation. The second is the proposed enhancement. Review that second commit for the exact change from the current bundle implementation. The new workflow runs isolated tests only and has no production credentials or deployment step.

## Exact changes from the current hosted source

| Files | Proposed change |
|---|---|
| `web/final-revision.js` and static copy | Add **Custom topic practice** for SAT, linking to the existing builder. The Final Revision runner, answers, explanation timing and saved progress remain intact. |
| `web/practice-bundles.html`, `.js`, `.css`, `bundle-core.js` and static copies | Four SAT domains; whole-lesson and individual-subtopic checkboxes; counts beside each option; overall eligible count; refresh counts; explicit shortage explanation and **Use N available questions**. Keep the existing 1–100 range and difficulty control. |
| `supabase/sql/sat_bundle_hierarchy.sql` | Guarded upgrade of four existing functions: section classification, eligible pool, catalogue and creation. Add private, trigger-maintained subtopic metadata, without reading diagram payloads on each catalogue request. No new grading endpoint. |
| Tests and CI | Exercise domain/subtopic selection, exact counts, insufficiency, repeat exclusion, source eligibility, historical preservation, access control, DOM interaction and rendering. |

The four SAT domains are Algebra; Advanced Math; Problem-Solving and Data Analysis; Geometry and Trigonometry. The mapping uses existing canonical lesson labels plus explicitly mapped legacy aliases. Supplementary or unclassified lessons are excluded from these four-domain bundles; they are not deleted or reclassified in the bank. Other courses retain their existing sections.

Subtopics use existing `assets.lesson_subtopic` metadata. Missing tags are shown as **General lesson practice**, not inferred from question text. Selecting a whole lesson includes all its subtopics; selecting individual subtopics clears that lesson's whole-lesson checkbox. Selections across lessons form a union. No checkboxes selected means the whole selected domain. Difficulty and exclusion apply to all selections.

A catalogue failure now clears old course data and disables creation. Refresh retains chosen lessons/subtopics even when their count becomes zero. Counts are advisory until creation: the server repeats eligibility and history checks and returns an explicit shortage without creating a shorter/repeated bundle.

## Repeat exclusion evidence

The existing `portal_private.bundle_answered(user)` queries saved nonblank answers in:

- Exam and assignment `attempt_answers`, owned through `attempts`.
- Mistake notebook records with `tries > 0`.
- Daily Quiz `daily_progress`.
- `practice_drills`.
- Final Revision `revision_sessions`.
- Saved partial and completed `practice_bundles`.

There is no recent-session or row-count cutoff. Correct and incorrect answers both exclude the same question ID. Merely opening a question or leaving a blank does not count. Other students' answers do not affect eligibility. Similar ideas with different question IDs can still appear. Unsaved answers and erased historical records cannot be reconstructed; exclusion uses the portal's retained server history.

## Validation

- **139 passing Node tests; 0 failures; 3 existing skipped baseline tests.** Coverage includes bundles, authentication, Final Revision, navigation, session recovery, mathematical rendering, diagrams, tables, calculator, assignments, Today objectives and study plans.
- **71 existing database assertions passed** before the upgrade and again against the upgrade, spanning six courses, creation, saving, resumption, grading, retakes, owner isolation, key privacy, held content, deletion behavior and historical scores.
- **50 new database assertions passed** for the hierarchy, union/intersection selection, all six history sources, blanks, tenant isolation, no duplicates, 100-question sets, exact shortage/no insert, malformed settings, metadata refresh, reserve/hold/missing-key/missing-figure eligibility, other courses and migration replay rejection.
- Desktop browser fixture: selected Geometry and Trigonometry → Right triangles, observed 8 eligible against a request for 10 and disabled creation, then created a small fixture set; diagram/table/formula display and a 2/2 completed result were verified.
- Mobile browser fixture: 390px iframe (375px content plus scrollbar), nested controls and counts worked; document scroll width equalled viewport width, with no horizontal overflow. This is responsive browser testing, not a physical Android/iOS device test.
- `git diff --check` and changed-JavaScript syntax checks passed.
- The reconciled GitHub package was retested independently: 32 focused Node tests passed without skips; the 71 baseline database checks, 71 post-upgrade checks and 50 hierarchy checks passed there too.

The three skips are pre-existing baseline expectations about unresolved-session login display (index/admin) and instructor-profile failure behavior. No new tests were skipped.

Database tests run in isolated PostgreSQL/WASM with synthetic users and questions. Browser tests used explicitly labeled synthetic account/data and made no live practice writes. The upgrade has not undergone authenticated staging/production testing because it remains unapplied pending approval.

## Deployment after approval

1. Re-read the latest hosted source and current database function hashes. Reconcile any concurrent changes; do not overwrite newer Site work.
2. Apply only `supabase/sql/sat_bundle_hierarchy.sql`. Its transaction checks the four reviewed function hashes and rejects replay/drift. Do **not** replay `practice_bundles.sql` or `question_eligibility_cache.sql`; those are existing baseline source, not upgrade scripts.
3. Deploy the changed frontend files through the existing Site build. No new Edge Function deployment or rollout toggle is needed.
4. Verify an enrolled test student's catalogue, selection, saved history and answer review; confirm counts against the server and inspect held-question behavior before broader use.

Rollback: restore the four previous function definitions from `practice_bundles.sql` and restore the previous five frontend files (and static copies). Retain all practice records and the small metadata table/trigger; do not delete student work. No historical score recomputation is required.

## Reproduce

```bash
npm ci --prefix tests/device-runtime --ignore-scripts --no-audit --no-fund
npm ci --prefix tests/passage-runtime --ignore-scripts --no-audit --no-fund
npm ci --prefix tests/english-runtime --ignore-scripts --no-audit --no-fund
node tests/practice_bundles_db.cjs
SAT_HIERARCHY=1 node tests/practice_bundles_db.cjs
node tests/sat_bundle_hierarchy_db.cjs
node --test tests/practice_bundles.test.cjs tests/practice_bundles_dom.test.cjs tests/final_revision.test.cjs tests/auth_security.test.cjs tests/practice_bundle_auth.test.cjs tests/navigation.test.cjs tests/portal_math.test.cjs tests/practice_figures.test.cjs tests/session_restore.test.cjs tests/sat_calculator.test.cjs tests/exam_assignments.test.cjs tests/student_objective.test.cjs tests/study_planner_ui.test.cjs
```
