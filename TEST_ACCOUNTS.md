# Test accounts

The `ghoneem` student login is marked `profiles.is_test=true`. It remains an active student with its existing enrollments, groups, assignments, private exam history and normal practice permissions.

Live real-student statistics exclude test accounts at read time, so both earlier and later test activity is excluded. This covers result feeds and averages, lesson heatmaps, staff diagnosis and exact-exam group evidence, daily quiz rankings and reports, current/all-history Hardest reports, question usage, exam attempt totals, subscription summaries, group student counts and assignment progress. Test accounts retain their own scores, points, streaks and review history; they have no real-student leaderboard rank.

Accounts & groups retains the login with a TEST ACCOUNT badge and a Test accounts filter. The Students filter omits it. Group editors keep its memberships manageable and label the account separately. The flag is stored in the protected profile row; authenticated students have no UPDATE privilege on it.

Original frozen Hardest snapshots are historical evidence and are not rewritten. Their screen explicitly warns that earlier test activity may remain. Use Bank usage & cycles with the matching closed trial for recalculated real-student statistics. Existing source repairs make some old snapshot counts impossible to reproduce exactly; silently subtracting or rewriting them would claim unsupported precision.

## Database rollout

`supabase/sql/test_accounts.sql` installs the reporting definitions and flag. `content-releases/20261022_test_account/guard.sql` checks the pre-rollout definitions; `activate.sql` resolves the requested login by its exact email, requires a unique student, marks only that account, records the action and reloads the API schema. The production packet was applied once on 22 October 2026. Do not replay the source guard after rollout.

Verification: `node tests/test_accounts_db.cjs` passes 49 checks against isolated PostgreSQL with synthetic accounts across all four tracks. It covers historical/future exclusion, normal daily scoring, real-student rank, private history, reversibility and denied student flag edits. `node --test tests/student_management_ui.test.cjs tests/group_management_ui.test.cjs tests/exam_assignments.test.cjs` passes 31 interface regressions. The production build passes.

Read-only production verification confirms one flagged account; it remains active with the student role, appears in account management, and is absent from result feeds, lesson heatmaps and staff diagnosis on all four tracks. Fingerprints of all 48 exam attempts and 54 daily-progress records are unchanged. No real-student account was marked.
