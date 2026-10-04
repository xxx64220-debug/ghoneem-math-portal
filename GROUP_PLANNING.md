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
