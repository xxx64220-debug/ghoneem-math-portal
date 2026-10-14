# EST I instructor group planning

Open **Finals diagnosis → Group planning**. Select an existing EST I class or choose its students. A uniquely identifiable saved class with seven enrolled students is preselected; otherwise the instructor chooses membership. Manual selection stays in memory only. The student reports and their CSV export remain available.

The view reads the existing staff-scoped `roster`, `results_feed`, `student_by_lesson`, `groups`, `group_members` and `exams` data. Reads use stable, paginated ordering so evidence beyond the first database page is included. Final Revision availability uses the existing read-only `revision.list` action with an explicit EST I track. It performs no assignment, grouping, grading, answer, attempt, release or visibility mutation.

Planning rules:

- Accept named EST I lessons with finite accuracy from 0–100 and at least three scored responses. Reject missing percentages, unclassified lessons and other tracks. Repeated lesson rows never double-count a student.
- Require two evidenced lessons before grouping a student. Show the available lesson evidence separately when that threshold is unmet.
- Use each student's bottom three lessons; below 60% is a weakness, matching the existing dashboard's `focus` threshold. Rank common weaknesses by student count descending, mean accuracy ascending and lesson name ascending.
- Greedily form at most three disjoint clusters using the highest-ranked remaining lesson shared by at least two students. Every member shares the anchor lesson; pairwise overlap chains are not treated as common evidence. Ties and member ordering use stable string comparisons, independent of input order.
- Show all lessons shared by every cluster member. Keep remaining students in individual practice, maintain/retest, or insufficient-evidence sections. Do not force two or three clusters when the evidence supports fewer.

The lesson view counts historical scored responses, which can include retakes. Its counts are not relabeled as distinct questions or as results from the latest exam. The latest score remains in the individual report. Error causes remain teacher-classified; individual question timing is never inferred.

Practice links appear only for currently visible, active, ready Final Revision items with the exact lesson name. They open the existing instructor revision view focused on that lesson; the plan also shows students' navigation path. The October weakness retest appears only when the exact EST I assessment is currently published, using its returned question count and duration. Its link opens the existing exam list; the plan explicitly asks the instructor to check assignments. No exam is created or assigned by planning. Hidden, missing and failed resource reads are disclosed separately.

Validation:

- `tests/finals_diagnosis.test.cjs`: deterministic clusters, membership isolation, invalid evidence, thresholds, nonoverlapping students, pairwise-overlap exclusion, pagination and the existing CSV/student diagnosis checks.
- `tests/group_planning_ui.test.cjs`: actual DOM rendering, view switching, selected membership, read-only requests, missing/hidden resources and stale navigation. Reuses the existing `tests/english-runtime` jsdom dependency.
- `tests/browser/group-planning.spec.cjs`: saved seven-person class, selection changes, actual revision/retest navigation, responsive page width, resource failures, hidden revision and absent retest, on desktop and mobile Chromium. Uses synthetic sessions and fixtures, blocks unknown external requests and never connects to production Supabase.

Production enrollment, assignments and the class's actual evidence still depend on the signed-in staff account. Synthetic checks do not certify students' scores or question mathematics.

## Evidence scope: Overall or an EST I exam

The scope selector defaults to **Overall**, preserving the historical lesson rules above. Choose a full or lesson exam to analyse that exact assessment ID. For each selected student, the staff read uses the latest completed scored attempt (`submitted`, `graded` or `expired` with a non-null score), ordered by submission time, attempt number, then ID. It never combines retakes, substitutes a different assessment with the same title, or falls back to an older unlocked attempt. If no completed scored attempt exists, a completed ungraded submission is shown as awaiting grading; otherwise the student is shown as missing evidence. A selected scored attempt whose full review is not open is shown as locked.

The read returns only attempt identity/date, status and lesson counts. It uses stored correctness, distinct assessment question IDs and explicit `curriculum_lesson` metadata with topic fallback, matching `finalsExamLessons`. Void keys and questions without boolean results are omitted. Counts include missed and unanswered questions; they do not include keys, responses, explanations, question details, error causes or per-question time. Limited and unclassified lesson evidence remains visible for teacher review.

Exam focus lessons rank by missed count descending, accuracy ascending and lesson name, including misses in lessons above 60%. The first three sufficiently evidenced missed lessons feed the existing deterministic shared-lesson planner. The group reliability rule remains two named lessons with at least three scored questions each. Missing, ungraded, locked and insufficient students remain outside clusters. All passed and limited/unclassified evidence remains visible so a maintain/retest suggestion is bounded by the available evidence.

`supabase/sql/group_exam_planning.sql` adds the narrow authenticated `staff_group_exam_evidence` RPC. Apply it after the existing access/scope/upgrade/pending-grading SQL, before serving the updated client. Its fixed empty search path and explicit caller checks protect the necessary private key exclusion lookup. It requires an active staff role, existing EST I track and student read permission, active student EST I enrollment, and (for instructors) membership in an EST I group they own. Unauthorized IDs reject the whole selection. Anonymous/student callers cannot read aggregates. The caller cannot supply an actor identity. The existing student `attempt-review` endpoint and its ownership check are unchanged. No production data or permissions are changed by tests.

Failed or incomplete exam reads show retry and never reuse Overall evidence. Changing scope, membership or page invalidates older responses. Selection and returned evidence stay in memory. Exam selection does not create assignments or retakes.

Additional validation:

- `tests/group_exam_evidence_db.cjs`: actual SQL under authenticated roles in isolated PostgreSQL WASM; track/group/student boundaries, latest retakes including ties, review locks, expiry, missing/ungraded evidence, duplicate question IDs, void/ungraded exclusions, aggregate parity with the student helper, response/key exclusion, and before/after preservation of attempts, results, answers, assignments and keys. Wired into CI.
- `tests/group_planning_ui.test.cjs`: selected-exam rendering and requests, misses above 60%, explicit status separation, limited/unclassified evidence, membership refresh, retries, incomplete responses and stale scope/member/page rejection.
- `tests/browser/group-planning.spec.cjs`: the actual instructor page on desktop and mobile; scope switching, scoped aggregate requests, resource links, membership changes, responsive width and safe failure behavior. All external requests are intercepted or blocked.

Rollout: this PR contains the SQL and UI change; merging alone does not apply support SQL to hosted Supabase. Apply the staff read SQL, deploy the verified web client, then check with an authorized enrolled class. Do not infer live student results from synthetic fixtures.
