# Ghoneem SAT & EST Exam Portal

Live student portal: https://math.portal.ghoneem.com/

Instructor console: https://math.portal.ghoneem.com/admin.html

Read [RELEASE.md](RELEASE.md) for the current delivered features, verification, content status, and remaining requirements. This release extends the existing Supabase-backed portal and preserves its data.

Staff can manage questions, import a JSON question bank, compose and assign exams, manage accounts and groups, grant retakes, and view reports directly from the console. See `web/question-bank-example.json` for the supported import format. Correct answers and explanations stay server-side until review opens.

The GitHub repository contains the frontend, database schema/migrations, public
question assets, release manifests, and automated tests. It intentionally does
not export authentication secrets, student identities, student answers/results,
or the live private answer-key table.

The sections below are the historical deployment notes for the original release; they are retained for schema history. Current deployment and limitations are documented in RELEASE.md.

---

# SAT & EST Exam Portal

Two exam tracks, one deployment. Server-side grading, one graded attempt per exam
enforced by the database, and answer keys that never reach the browser.

**Abdelrahman Ghoneem | 01116004434**

---

## What is here

```
supabase/migrations/
  001_schema.sql      tables, constraints, the partial unique index
  002_functions.sql   attempt engine, grading, scoring, policy helpers
  003_policies.sql    RLS policies and table grants
  004_seed.sql        the sat and est track rows
  005_function_hardening.sql  EXECUTE lockdown (see "Security fixes" below)
  006a_bank_staging.sql       landing table when the bank comes from another project
  006_import_legacy_sat.sql   imports your existing 352-question SAT bank
  007_exam_builder.sql        cohorts, new_exam(), new_exam_per_lesson()
supabase/functions-standalone/  paste-into-the-dashboard builds of the 7 functions
supabase/functions/
  _shared/http.ts     auth, CORS, SQL-error -> HTTP mapping
  me-tracks/          enrolled tracks, and exams within a track
  start-attempt/      creates or resumes an attempt, returns keyless questions
  submit-attempt/     atomic submit + server-side grading
  attempt-review/     read-only result view
  grant-retake/       instructor action
  admin-users/        create a student and enrol them in one call
  enrollments/        add or pause a track enrollment
tests/
  00_shim.sql         LOCAL ONLY - fakes auth.uid() and the Supabase roles
  rls_test.sql        34 acceptance tests
  adversarial_test.sql 21 privilege-escalation attempts, all must be refused
web/index.html        the student client, single file
```

## Deploy

**See DEPLOY.md** for the numbered, browser-only walkthrough. The notes below
are reference.

**1. Migrations.** In the Supabase SQL editor, run `001` → `002` → `003` → `004`
→ `005` → `006` in that order. **`005` is not optional** — without it the whole
attempt engine is callable from the browser. Do **not** run `tests/00_shim.sql` there; Supabase already provides
the `auth` schema and the `anon` / `authenticated` / `service_role` roles.

**2. Role claim.** In Authentication → Hooks, set the Custom Access Token hook to
`public.custom_access_token_hook`. Every policy also falls back to a
`SECURITY DEFINER` profile lookup, so the portal is correct with or without it —
the hook only makes it faster.

**3. Functions.**

```bash
supabase functions deploy me-tracks start-attempt submit-attempt \
  attempt-review grant-retake admin-users enrollments
supabase secrets set ALLOWED_ORIGIN=https://your-site.netlify.app
supabase secrets set STUDENT_EMAIL_DOMAIN=students.ghoneem-math.com
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected
automatically. **The service-role key belongs only in these functions.** If it
ever appears in `web/index.html`, the whole design is void.

**4. Sweeper.** Enable `pg_cron`, then:

```sql
select cron.schedule('sweep-expired-attempts', '* * * * *',
                     $$select public.sweep_expired_attempts()$$);
```

Without this, a student who closes the laptop mid-exam stays blocked by the
`one_live_attempt` index until the sweeper finalises the abandoned attempt.

**5. Client.** Fill in the two constants at the top of the `<script>` block in
`web/index.html` (project URL and the **publishable/anon** key — never the service
key), then drop the file on Netlify.

**6. First admin.** Create one user in the Supabase dashboard, then:

```sql
insert into public.profiles (id, full_name, role)
values ('<that-user-uuid>', 'Abdelrahman Ghoneem', 'admin')
on conflict (id) do update set role = 'admin';
```

Every account after that is created through `admin-users`.

## Importing your existing SAT bank

Your 352 verified questions are already in this project, in the old portal's
`site_content` table. `006` copies them across — stems, choices, answer keys,
explanations, SVG figures and data tables — without retyping or re-solving a
single one. Run it in three steps in the SQL editor:

```sql
select * from public.legacy_probe();      -- 1. read-only, shows the JSON shape
select * from public.legacy_import(true); -- 2. DRY RUN, writes nothing
select * from public.legacy_import(false);-- 3. writes
```

Step 2 reports how many map cleanly and lists every one it cannot read.
**If that list is not empty, do not run step 3 — send me the list.** A question
whose answer key cannot be read is skipped rather than guessed, because a wrong
key in an exam portal is worse than a missing question.

Afterwards, check the labelling and figures landed:

```sql
select * from public.sat_bank_by_lesson;
```

One row per lesson, with a count of questions, how many carry a figure, how many
are grid-in, and how many are missing an explanation. Re-running the import is
safe: it replaces the imported set and leaves anything you authored in the new
portal alone.

## Security fixes found by the adversarial suite

Three real escalations existed before `005` and are now closed. Postgres grants
`EXECUTE` on new functions to `PUBLIC` by default, and `SECURITY DEFINER` runs as
the owner, so RLS was never consulted:

| Route | What a student could do |
|---|---|
| `rpc/grant_retake` | grant themselves unlimited retakes |
| `rpc/start_attempt` | burn **another** student's single attempt |
| `rpc/my_exams` | read another student's exam list and scores |

`005` revokes `EXECUTE` from `public`, `anon` and `authenticated` across the
schema, hands it back to only the thirteen read-only helpers that RLS policies
call, and sets a default privilege so a future migration cannot silently reopen
it. If you have already deployed anything from an earlier version, run `005`
now.

## Verify before students touch it

```bash
createdb portal
psql -d portal -f tests/00_shim.sql
psql -d portal -f supabase/migrations/001_schema.sql
psql -d portal -f supabase/migrations/002_functions.sql
psql -d portal -f supabase/migrations/003_policies.sql
psql -d portal -f supabase/migrations/004_seed.sql
psql -d portal -f supabase/migrations/005_function_hardening.sql
psql -d portal -f supabase/migrations/006_import_legacy_sat.sql
psql -d portal -f tests/rls_test.sql
psql -d portal -f tests/adversarial_test.sql
```

Both scripts print a pass/fail table. `rls_test` must end with all 34 passing;
`adversarial_test` must end with all 21 attacks refused.
It covers key exposure, insert denial, SAT/EST isolation, double-submit,
post-deadline behaviour, the sweeper, retake grants, review locking, grid-in
answer matching, and the audit log. Run it against a scratch database, not
production — it creates fixture rows.

## Adding a third track

```sql
insert into public.tracks (id, name, theme, scoring, default_duration_seconds)
values ('act', 'ACT Math',
        '{"label":"ACT","accent":"#2F6F4F","navy":"#14243E"}',
        '{"type":"linear","min":1,"max":36,"step":1}', 3600);
```

No migration, no code change. The chooser picks it up on the next login.

## Two things done deliberately

**Autosave bypasses the API.** Answers go straight to Postgres under an RLS
policy that checks the attempt is the caller's own, still `in_progress`, and
inside its deadline. This avoids a ~300 ms cold start every ten seconds.
Correctness is never written on this path — it lives in `attempt_results`, which
students cannot write at all.

**Repeat submit returns 409 with the existing grade.** The design called for an
`Idempotency-Key` header; returning the standing result on conflict achieves the
same thing — a retried submit shows the student their score instead of an error —
without a second table to keep. The client treats `409` with a `result` body as
success.

## Not built yet

This historical list is superseded by RELEASE.md. Device sessions, staff authoring, and CSV exports are now implemented.
