-- =====================================================================
--  SAT & EST EXAM PORTAL  —  003  ROW LEVEL SECURITY
--  Default posture: deny. A student's only writable table is
--  attempt_answers, and only while their own attempt is live.
--
--  Every cross-table condition below goes through a SECURITY DEFINER
--  helper from 002. A policy must never query another RLS-protected
--  table directly — two tables referencing each other produce
--  "infinite recursion detected in policy" at query time.
--  Abdelrahman Ghoneem | 01116004434
-- =====================================================================

alter table public.profiles          enable row level security;
alter table public.tracks            enable row level security;
alter table public.enrollments       enable row level security;
alter table public.instructor_tracks enable row level security;
alter table public.groups            enable row level security;
alter table public.group_members     enable row level security;
alter table public.questions         enable row level security;
alter table public.question_keys     enable row level security;
alter table public.exams             enable row level security;
alter table public.assignments       enable row level security;
alter table public.attempts          enable row level security;
alter table public.attempt_answers   enable row level security;
alter table public.attempt_results   enable row level security;
alter table public.retake_grants     enable row level security;
alter table public.device_sessions   enable row level security;
alter table public.audit_log         enable row level security;

-- ------------------------------------------------------------- profiles
drop policy if exists profiles_self_read on public.profiles;
create policy profiles_self_read on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_staff());

drop policy if exists profiles_admin_write on public.profiles;
create policy profiles_admin_write on public.profiles
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- --------------------------------------------------------------- tracks
drop policy if exists tracks_read on public.tracks;
create policy tracks_read on public.tracks
  for select to authenticated
  using (public.is_staff() or public.is_enrolled(auth.uid(), id));

drop policy if exists tracks_admin_write on public.tracks;
create policy tracks_admin_write on public.tracks
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------- enrollments
drop policy if exists enrollments_read on public.enrollments;
create policy enrollments_read on public.enrollments
  for select to authenticated using (user_id = auth.uid() or public.is_staff());

drop policy if exists enrollments_admin_write on public.enrollments;
create policy enrollments_admin_write on public.enrollments
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------- instructor_tracks
drop policy if exists instructor_tracks_read on public.instructor_tracks;
create policy instructor_tracks_read on public.instructor_tracks
  for select to authenticated using (user_id = auth.uid() or public.is_admin());

drop policy if exists instructor_tracks_admin on public.instructor_tracks;
create policy instructor_tracks_admin on public.instructor_tracks
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- --------------------------------------------------------------- groups
drop policy if exists groups_read on public.groups;
create policy groups_read on public.groups
  for select to authenticated
  using (public.staff_can_touch_track(track_id) or public.in_group(id, auth.uid()));

drop policy if exists groups_staff_write on public.groups;
create policy groups_staff_write on public.groups
  for all to authenticated
  using (public.staff_can_touch_track(track_id))
  with check (public.staff_can_touch_track(track_id));

drop policy if exists group_members_read on public.group_members;
create policy group_members_read on public.group_members
  for select to authenticated using (user_id = auth.uid() or public.is_staff());

drop policy if exists group_members_staff_write on public.group_members;
create policy group_members_staff_write on public.group_members
  for all to authenticated
  using (public.staff_can_touch_track(public.group_track(group_id)))
  with check (public.staff_can_touch_track(public.group_track(group_id)));

-- ------------------------------------------------------------ questions
-- NO student policy. Question text reaches a student only through
-- attempt_payload(), called with the service-role key from an Edge Function.
drop policy if exists questions_staff on public.questions;
create policy questions_staff on public.questions
  for all to authenticated
  using (public.staff_can_touch_track(track_id))
  with check (public.staff_can_touch_track(track_id));

-- --------------------------------------------------------- question_keys
-- NO student policy, ever. This is the table a leaked publishable key
-- must not be able to read.
drop policy if exists question_keys_staff on public.question_keys;
create policy question_keys_staff on public.question_keys
  for all to authenticated
  using (public.staff_can_touch_track(public.question_track(question_id)))
  with check (public.staff_can_touch_track(public.question_track(question_id)));

-- ---------------------------------------------------------------- exams
-- Published + enrolled in its track + assigned. This is where SAT/EST
-- isolation appears in the student's exam list.
drop policy if exists exams_read on public.exams;
create policy exams_read on public.exams
  for select to authenticated
  using (public.staff_can_touch_track(track_id)
         or (is_published
             and public.is_enrolled(auth.uid(), track_id)
             and public.exam_assigned_to(id, auth.uid())));

drop policy if exists exams_staff_write on public.exams;
create policy exams_staff_write on public.exams
  for all to authenticated
  using (public.staff_can_touch_track(track_id))
  with check (public.staff_can_touch_track(track_id));

-- ---------------------------------------------------------- assignments
drop policy if exists assignments_read on public.assignments;
create policy assignments_read on public.assignments
  for select to authenticated
  using (public.staff_can_touch_track(public.exam_track(exam_id))
         or user_id = auth.uid()
         or public.in_group(group_id, auth.uid()));

drop policy if exists assignments_staff_write on public.assignments;
create policy assignments_staff_write on public.assignments
  for all to authenticated
  using (public.staff_can_touch_track(public.exam_track(exam_id)))
  with check (public.staff_can_touch_track(public.exam_track(exam_id)));

-- ------------------------------------------------------------- attempts
-- Layer 1: read-only for students. No INSERT or UPDATE policy exists for
-- them on this table, in any state.
drop policy if exists attempts_read on public.attempts;
create policy attempts_read on public.attempts
  for select to authenticated
  using (user_id = auth.uid()
         or public.staff_can_touch_track(public.exam_track(exam_id)));

drop policy if exists attempts_staff_write on public.attempts;
create policy attempts_staff_write on public.attempts
  for update to authenticated
  using (public.staff_can_touch_track(public.exam_track(exam_id)))
  with check (public.staff_can_touch_track(public.exam_track(exam_id)));

-- ------------------------------------------------------ attempt_answers
-- Lane A. The only student-writable table, and only while their own
-- attempt is live and inside its deadline.
drop policy if exists answers_read on public.attempt_answers;
create policy answers_read on public.attempt_answers
  for select to authenticated
  using (public.attempt_is_mine(attempt_id, auth.uid())
         or public.staff_can_touch_track(public.attempt_track(attempt_id)));

drop policy if exists answers_insert_live on public.attempt_answers;
create policy answers_insert_live on public.attempt_answers
  for insert to authenticated
  with check (public.attempt_live_for(attempt_id, auth.uid()));

drop policy if exists answers_update_live on public.attempt_answers;
create policy answers_update_live on public.attempt_answers
  for update to authenticated
  using (public.attempt_live_for(attempt_id, auth.uid()))
  with check (public.attempt_live_for(attempt_id, auth.uid()));

-- ------------------------------------------------------ attempt_results
-- Server-written. A student may read their own only once review is unlocked.
drop policy if exists results_read on public.attempt_results;
create policy results_read on public.attempt_results
  for select to authenticated
  using (public.attempt_review_open(attempt_id, auth.uid())
         or public.staff_can_touch_track(public.attempt_track(attempt_id)));

-- -------------------------------------------------------- retake_grants
drop policy if exists retakes_read on public.retake_grants;
create policy retakes_read on public.retake_grants
  for select to authenticated
  using (user_id = auth.uid()
         or public.staff_can_touch_track(public.exam_track(exam_id)));

drop policy if exists retakes_staff_write on public.retake_grants;
create policy retakes_staff_write on public.retake_grants
  for all to authenticated
  using (public.staff_can_touch_track(public.exam_track(exam_id)))
  with check (public.staff_can_touch_track(public.exam_track(exam_id)));

-- ------------------------------------------------------ device_sessions
drop policy if exists devices_own on public.device_sessions;
create policy devices_own on public.device_sessions
  for all to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

-- ------------------------------------------------------------ audit_log
drop policy if exists audit_admin_read on public.audit_log;
create policy audit_admin_read on public.audit_log
  for select to authenticated using (public.is_admin());

-- =====================================================================
--  TABLE AND FUNCTION PRIVILEGES
--  RLS narrows these further; it never widens them.
-- =====================================================================
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all functions in schema public from anon, authenticated;

grant select on
  public.profiles, public.tracks, public.enrollments, public.instructor_tracks,
  public.groups, public.group_members, public.questions, public.question_keys,
  public.exams, public.assignments, public.attempts, public.attempt_results,
  public.retake_grants, public.audit_log
  to authenticated;

grant select, insert, update on public.attempt_answers to authenticated;
grant select, insert, update, delete on public.device_sessions to authenticated;

-- Staff write paths. Still filtered by the policies above.
grant insert, update, delete on
  public.profiles, public.tracks, public.enrollments, public.instructor_tracks,
  public.groups, public.group_members, public.questions, public.question_keys,
  public.exams, public.assignments, public.retake_grants
  to authenticated;

-- Helpers referenced by the policies must be executable by the caller.
grant execute on function
  public.jwt_role(), public.is_admin(), public.is_staff(),
  public.is_enrolled(uuid, text), public.staff_can_touch_track(text),
  public.exam_track(uuid), public.group_track(uuid), public.question_track(uuid),
  public.attempt_track(uuid), public.in_group(uuid, uuid),
  public.exam_assigned_to(uuid, uuid), public.attempt_is_mine(uuid, uuid),
  public.attempt_live_for(uuid, uuid), public.attempt_review_open(uuid, uuid)
  to authenticated;

-- Engine functions are service-role only. The browser must go through the
-- Edge Functions, which is where authentication and rate limiting happen.
revoke execute on function
  public.start_attempt(uuid, uuid),
  public.submit_attempt(uuid, uuid),
  public.grade_attempt(uuid),
  public.attempt_payload(uuid, uuid),
  public.attempt_review(uuid, uuid),
  public.grant_retake(uuid, uuid, uuid, text, timestamptz),
  public.finalize_expired_for(uuid, uuid),
  public.sweep_expired_attempts(),
  public.scale_score(text, integer, integer),
  public.student_assignment_for(uuid, uuid),
  public.my_tracks(uuid),
  public.my_exams(uuid, text)
  from anon, authenticated;

-- ------------------------------------------------------------ scheduling
-- Enable pg_cron in the dashboard (Database → Extensions), then run once:
--   select cron.schedule('sweep-expired', '* * * * *',
--                        $$select public.sweep_expired_attempts()$$);
