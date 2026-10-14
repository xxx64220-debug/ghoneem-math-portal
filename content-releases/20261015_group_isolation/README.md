# Group isolation — applied October 15, 2026 (Cairo)

Existing Site and production project retained. Production began with four default cohorts and two teaching groups, all without custom daily lessons. No student membership, existing plan or completed attempt was changed automatically.

All five numbered SQL packets were installed once in the existing project. Read-only production verification confirmed the group editor, explicit daily selector, group-scoped ranking, anonymous denial and default-plan guard. `daily-before.sql` is the exact prior definition; `04-daily.sql` refuses to overwrite a differing definition. Do not replay installed packets.

The first group-editor installation request expired before applying. The final editor preserves existing members while atomically saving metadata and additions; it returns explicitly unchecked members for separate, targeted `student-groups` edits. A successful metadata save is retained across removal retries. This avoids clearing a roster or losing a paused subscriber.

`student-groups` version 2 is active with JWT verification. Active administrators may set a per-track daily group; active instructors may edit memberships only for groups they own. Preferences must match the student's course and membership. Removing that membership clears its preference, retaining daily and exam history. `staff-console` version 3 rejects the obsolete `group.save` roster-replacement action and requests a page refresh.

Each teaching group has a fixed parent track and stable ID, its own instructor, members, course dates, target exam, plan and lesson selection. Names are unique within their parent track. Default cohort identity and plans are protected. Paused, expired and future subscribers remain visible and eligible for membership. Instructor/track mismatch, wrong-track members, stale group snapshots and wrong-track lessons are refused.

A preferred daily group supplies the next unopened daily set. Automatic mode selects a teaching group only when exactly one eligible group exists; multiple groups fall back to the parent's settings rather than creation order. Already-opened sets continue using their recorded group ID. Group leaderboard points count only progress recorded for that group. Course-level streaks and the one-quiz-per-student/track/day contract are retained.

Validation: group UI and endpoint fixtures, 21 disposable PostgreSQL isolation gates, 129 existing course-management gates, and related student/bulk/navigation/daily regressions. No production student writes were used for testing. No new group-related security advisor findings were returned. Visual browser QA was unavailable.
