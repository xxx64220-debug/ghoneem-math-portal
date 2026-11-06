# Verified daily objective completion

Students earn completion from recorded work. The Daily checklist has no Mark done
controls, and both the Edge action and legacy SQL marking routes refuse manual
claims. Existing assessment submissions, grading, attempts, score calculations,
quiz question selection and streak rules are retained.

## Evidence and scope

- Daily Quiz: the selected group's submitted quiz on the objective's Cairo date.
  The first selected answer records Started; it cannot record completion.
- Daily lesson practice: a submitted, nonempty lesson-exam attempt assigned to
  the selected group or the individual, or a completed course weak-topic drill.
  An exam shared by two groups can count for both only if both assigned it.
- Daily mistake review: a correctly answered course notebook question, recorded
  by the server while grading. Opening a notebook or viewing a solution cannot
  create evidence. A later wrong retry cannot erase a recorded success.
- Personalized lesson/practice/retest: a submitted attempt for the exact linked
  exam and student, with a nonempty saved response. Starting/reading alone does
  not count. A later open retry does not erase completion. Reassigning the same
  exam on a later date requires new work; late work before reassignment counts
  for the original day.
- Planned practice can instead reference the Daily Quiz for an exact group.
  Instructors can skip lesson, practice or retest cards. Students cannot change
  skips, objective definitions, server evidence, or another student's progress.

The view uses security_invoker and the existing session/row policies. Notebook
evidence is in a private, RLS-enabled table with no student access. Public mutation
RPCs are service-only; the Edge function obtains the student ID from verified Auth.
Existing self-report history stays stored but is not completion evidence.

The four existing Alex November 3 objectives are matched by exact scheduled exam
title, course, date, assignment and membership. Alex's weekly shortcut can show
Completed and open the recorded result after its start cutoff on the same day.
Alia's existing linked practice remains intact. Reading/PDF tasks and future
weakness-dependent work without selected assessments show Assessment link needed;
no extra exam is invented or assigned, and the two-hour study budget is unchanged.

## Release

Apply `supabase/migrations/20261106114814_verified_daily_objective_activity.sql`
against the inspected production schema. It is one transaction with a three-second
lock timeout; it does not rewrite attempts or historical scores. The SQL sources
are retained separately in `supabase/sql/` for review, not for a second application.
The current day's verifiable notebook work is retained during rollout; earlier
scores and bonuses are not recomputed. Course drills and notebook corrections can
satisfy the checklist in multiple groups, but group quizzes/scores/streaks remain
independent.

Deploy `content-releases/20261106_verified_daily/edge/` as `daily-challenge`, with
JWT verification enabled. Its shared authentication helper is the inspected live
helper. The root shared helper contains separate staged MFA work and must not be
deployed as part of this change. Publish the frontend built from this source.

For a frontend rollback, keep the server marking route blocked. Do not restore
manual marking to compensate for a stale client. The pre-change server definitions
are retained in `content-releases/20261106_verified_daily/before.json`.

## Verification

Synthetic PostgreSQL tests cover manual-route denial, started/submitted states,
ownership and course/group isolation, shared assignments, retry idempotence,
transaction rollback, unchanged historical attempts, date rollover, skipped work,
exact Daily Quiz targets and Alex's completed-result shortcut.

DOM/API regression tests cover interrupted submissions before/after commit,
retry-button recovery, stale group responses, midnight refresh, automatic progress,
read-only student controls, instructor skip controls, assessment links and Cairo
date selection. The production build and packaged asset/link checks pass.

Live publication succeeded as Site v153 and daily-challenge v7. The production
sign-in page loads in the browser. Signed-in desktop/mobile interaction remains
unverified because this browser has no authenticated portal session. No real
student's attempt was submitted for testing.

Targeted tests pass: 79 isolated PostgreSQL assertions and 31 UI/API tests.
Another 50 assessment/assignment/math/client regressions pass. Browser fixtures
exercise the production checklist code on desktop, tablet and mobile with an
isolated synthetic API; these are distinct from signed-in production checks.
