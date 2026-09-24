# Deployment — SAT & EST Exam Portal
**Abdelrahman Ghoneem | 01116004434**

Target: a **brand-new Supabase project**. Your existing portal keeps running
untouched throughout, so there is no downtime and no rush.

Everything is done in the browser. No command line.

---

## Step 0 — Create the project
supabase.com → New project. Save the database password somewhere safe.
Then note two values from **Project Settings → API**:
- Project URL
- the **publishable / anon** key  ← this one is safe in the website file
- the **service_role** key  ← never leaves Supabase. Do not paste it anywhere.

## Step 1 — Pre-flight
SQL Editor → New query → paste `000_preflight.sql` → Run.
On a new project the verdict row must read **YES — nothing clashes**.
It writes nothing.

## Step 2 — Migrations
Run these one at a time, in order, waiting for "Success" each time.

    001_schema.sql
    002_functions.sql
    003_policies.sql
    004_seed.sql
    005_function_hardening.sql      <-- not optional, closes 3 escalations
    006a_bank_staging.sql
    007_exam_builder.sql

If any file errors, STOP and send the message. Do not continue past it.

## Step 3 — Role claim
Authentication → Hooks → Customize Access Token → enable →
choose `custom_access_token_hook` → Save.

## Step 4 — Make yourself admin
Create your own account first: Authentication → Users → Add user
(your email, a password, tick Auto Confirm). Then in SQL Editor:

    insert into public.profiles (id, full_name, role)
    select id, 'Abdelrahman Ghoneem', 'admin' from auth.users
    where email = 'YOUR-EMAIL-HERE'
    on conflict (id) do update set role = 'admin';

## Step 5 — Bring the SAT bank across
The bank lives in the OLD project. Pick one route.

**Route A — you have setup.sql on your computer.**
Open it in Notepad, Ctrl+F for `insert into public.site_content`, select that
whole line through its closing `;` (one very long line — normal), copy, paste
into the NEW project's SQL Editor, Run.

**Route B — no local file.**
OLD project: Table Editor → site_content → Export → Download as CSV.
NEW project: Table Editor → site_content → Insert → Import data from CSV.

Then run the check at the bottom of `006a_bank_staging.sql`.
It must say **1 row, 352 questions**.

## Step 6 — Import
Run `006_import_legacy_sat.sql`, then:

    select * from public.legacy_import(true);    -- DRY RUN, writes nothing

Read the `skip reasons` row. If it is anything other than `none`, STOP and send
it to me — a question whose answer key cannot be read is skipped, never guessed.
If it says `none`:

    select * from public.legacy_import(false);   -- writes
    select * from public.sat_bank_by_lesson;     -- lessons, figures, gaps

## Step 7 — Build the exams
Questions are not exams. One line turns the bank into a working portal:

    select * from public.new_exam_per_lesson('sat', 12, 20);

That makes one 12-question, 20-minute exam per lesson, publishes each, and
assigns it to the SAT cohort. The `action` column says `created` or
`already existed - left alone` — it is safe to run again, it will not
duplicate anything. Check the result:

    select * from public.exam_overview;

Every row must show `assignments = 1`, or students will not see it.
For a single custom exam instead:

    select public.new_exam('sat', 'Quadratics Mock', 20, 35, 'quadratic');

## Step 8 — Deploy the 7 functions
Edge Functions → Deploy a new function → **via Editor**. Seven times.
The function name must match the filename exactly. Paste the whole file
from the **functions-standalone/** folder (shared code is baked in, which is
why the browser editor accepts it).

    me-tracks   start-attempt   submit-attempt   attempt-review
    grant-retake   admin-users   enrollments

## Step 9 — Secrets
Edge Functions → Secrets. Add:

    ALLOWED_ORIGIN         *          (tighten in step 12)
    STUDENT_EMAIL_DOMAIN   students.ghoneem-math.com

The three SUPABASE_* keys are injected automatically.

## Step 10 — The sweeper
Database → Extensions → enable `pg_cron`. Then SQL Editor:

    select cron.schedule('sweep-expired-attempts', '* * * * *',
                         $$select public.sweep_expired_attempts()$$);

Skip this and the first student who closes their laptop mid-exam is locked
out permanently.

## Step 11 — Put the site online
Open `web/index.html` in Notepad. Near the top of the <script> block:

    const SB_URL = 'https://YOUR-NEW-PROJECT.supabase.co';
    const SB_KEY = 'your publishable key';

Use the **publishable** key, never service_role. Save.
Go to app.netlify.com/drop and drag the file on. Use a NEW Netlify site,
not the one hosting your live portal.

## Step 12 — Test it yourself, then open up
1. Sign in as yourself. No tracks appear — correct, admins are not enrolled.
2. Create a test student. Edge Functions → admin-users → Test, body:

       { "username": "test1", "password": "changeme123",
         "full_name": "Test Student", "tracks": ["sat"] }

3. Open the site in a private window, sign in as `test1`, sit a short exam.
   Check: graphs render, timer counts down, submit shows answers and
   explanations, and a second submit is refused.
4. Change `ALLOWED_ORIGIN` from `*` to your Netlify URL.
5. Create the real students the same way as step 12.2.

---

## Notes
- Student accounts do NOT transfer between projects — password hashes cannot be
  exported. Recreate them with `admin-users`. Same usernames, new passwords.
- After the import is confirmed, `drop table public.site_content;` — it is only
  staging. Keep the CSV or setup.sql as your backup.
- Free tier pauses after 7 days idle. Log in once before an exam day.
