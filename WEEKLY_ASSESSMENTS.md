# Alex EST I Tuesday algebra assessments

The production scheduler prepares one new assigned quiz for **Alex online** each Tuesday, starting **3 November 2026**. It uses the existing portal at https://math.portal.ghoneem.com and Supabase project `wfhurjyouemahvkcfkdz`. The verified group is `a8509c9b-fe47-4ed7-90c7-cde7c27904cd`, with four members at activation. There were 96 existing group assignments and 65 member attempts; those records were preserved.

| Setting | Value |
| --- | --- |
| Local timezone | Africa/Cairo, including daylight-saving changes |
| Release | Tuesday 13:10 |
| New-start cutoff | Tuesday 13:30; existing portal lookup includes the exact closing instant |
| Timer | 1,200 seconds from the student's start; a late start may finish after 13:30 |
| Size | 10 questions, matching the group's previous 20-minute Tuesday quiz |
| Category | Assigned quiz, with one attempt under existing portal rules |
| Difficulty | Easy or medium only |
| Subjects | Expressions/equations, systems, lines, inequalities/absolute value, quadratics/polynomials, functions, exponents/radicals |
| Daily Quiz | Unchanged; separate records, scoring and scheduling |

The quiz is prepared ahead of its opening time. Students may see an upcoming card, but the existing server assignment lookup rejects starts before 13:10. The backend `pg_cron` job runs every five minutes and prepares only the next eligible Tuesday. It does not backfill missed quizzes or create a term's worth of cards. The assignment window, rather than the timing of an AI run, controls release. There is no end date unless the schedule is explicitly changed or paused.

## Selection and duplication controls

`supabase/sql/weekly_assessments.sql` defines private configuration and run tables and SECURITY INVOKER functions. Only the database owner can execute the worker or change configuration. App roles, including `service_role`, have no access to these new tables/functions. RLS is enabled with intentionally no app policies. No new public RPC or browser privilege is introduced.

Each selection requires the existing structural/visual readiness gate, a verified-release marker, independent solution-review evidence, valid multiple-choice answers and explanations, the correct track, permitted difficulty and algebra topic, and no reserve, removal, duplicate or release hold. Original question IDs preserve figures and keys. Review metadata is evidence from prior reviews, not a new mathematical proof of every bank item.

Questions in any exam attempted by a current group member, and completed Daily Quizzes, are excluded at selection time. All questions previously selected by this weekly series are excluded permanently, including normalized exact-stem copies. Numeric-template families have a four-run cooldown. Each quiz has ten distinct concept labels and template families, at most two questions from one broad topic, with less-used concepts and topics preferred. A per-schedule random seed and release date randomize selection reproducibly. Previously unassigned items are preferred within those constraints.

Most eligible questions had already been included in earlier bulk assignments. Unattempted questions from those assignments can therefore appear; the scheduler does not claim every question was never assigned. The bank currently has few easy-labelled items. It stays within easy/medium and never adds hard or unverified content to fill a shortage. A short pool blocks the run and is reported for review.

A schedule-row transaction lock serializes workers, including workers creating different weeks. A primary key on `(schedule_id, release_date)`, unique run-to-exam/assignment links, and the existing exam/target unique index prevent duplicate copies. A retry returns the original exam. A matching manual title or overlapping dated group quiz blocks creation. A failure after exam insertion rolls back the whole exam/assignment creation. Existing quizzes manually changed or held are reported, not overwritten or recreated. The scheduler never changes attempts, answers, scores, Daily Quiz records, or old assignments.

## Production receipt — 30 October 2026

- Migration: `20261030192023_weekly_algebra_assessments`.
- Schedule: `4781db21-0dfb-4945-9f65-91c51d6fcc66`, code `alex-est1-tuesday-algebra`.
- Cron: `portal-weekly-algebra-assessments`, job 3, `*/5 * * * *`, owner `postgres`.
- First exam: `b9e5497f-8692-4711-9bdb-6b87a1a392b9`.
- First assignment: `f1747564-c61e-4538-9993-53add6b6b9a0`.
- First opening: `2026-11-03T11:10:00Z` = 13:10 Cairo; closing 11:30Z = 13:30 Cairo.
- First quiz: 3 easy and 7 medium questions, ten distinct concept labels, seven algebra topics. Its keys and explanations were checked again; its parabola figure was visually inspected.
- Production replay returned `existing`, with exactly one exam and one group assignment, no weekly attempts, all four students denied early starts, and the 65 historical member attempts retained.
- Security advisors introduced no warnings: the two new informational RLS/no-policy findings are intentional owner-only private tables. Existing unrelated warnings were unchanged.

The frontend remains the inspected Site version 130 (source `1bd3245e827ed396ea5aa3b6afa34c3dd92cbbfb`). This is a database-only deployment; no frontend or Edge Function release was necessary. The existing domain and audience are preserved.

## Verification and operation

Run `node tests/weekly_assessments_db.cjs` after `npm ci --prefix tests/june-review-runtime --ignore-scripts --no-audit --no-fund`. `PGLITE_MODULE` can point to an already-installed pinned PGlite runtime. The separate GitHub workflow runs this regression on pushes and pull requests.

The test executes the actual scheduler SQL and captured production access/timer functions in disposable PostgreSQL. It redirects `now()` only in that isolated database to check release boundaries and Cairo winter/summer conversion. It covers invalid/unready questions, role denial, retries, unique run keys, concept/question rotation, early and late access, outsider denial, timed-only quizzes, one live attempt, attempt limits, paused schedules, missed dates, atomic rollback and preserved historical/Daily Quiz data. It does not impersonate students or create test attempts in production. No new browser/phone verification is claimed.

Use `supabase/sql/enable_alex_weekly_algebra.sql` only for the authorized configuration. It checks unique group identity and refuses divergent pre-existing settings; it is not a general-purpose group seed. The definition SQL was deployed with the migration tool. Do not replay historical assignment migrations.

A separate Monday noon Cairo automation calls the same idempotent worker and checks readiness, configuration and cron history. It does not create assessments by another path and does not re-enable a paused schedule. It reports blocks without sending student messages.

To pause, an authorized database operator can set `enabled=false` on this schedule by code. This prevents future creation and leaves already-prepared quizzes/windows and all history intact. To cancel an upcoming release too, explicitly review and unpublish that specific unattempted quiz. No deletion is needed.

To inspect:

```sql
select code,enabled,timezone,weekday,release_time,session_time,starts_on,ends_on
from portal_private.weekly_assessment_schedules;
select release_date,status,exam_id,assignment_id,detail,checked_at
from portal_private.weekly_assessment_runs order by release_date desc;
select status,start_time,end_time,return_message from cron.job_run_details
where jobid=(select jobid from cron.job where jobname='portal-weekly-algebra-assessments')
order by start_time desc limit 5;
```
