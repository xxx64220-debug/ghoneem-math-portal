-- The report is still a security-invoker view. Cache the already-existing
-- administrator permission in read policies once per statement instead of re-running
-- nested staff checks for every answer/question. Other roles retain their
-- original predicates. This grants no additional INSERT/UPDATE/DELETE permissions.
begin;
-- Match the live report's helper grants. These SECURITY INVOKER, immutable
-- functions compare only their supplied values; they never look up answer keys.
-- fair_exam_keys.sql revokes this grant, so apply this report patch after it.
grant execute on function public.answer_matches(text,jsonb,jsonb), public.norm_num(text) to authenticated;
-- CASE guarantees the cheap cached check runs before nested row checks.
-- Each original predicate already allows admins; its other-role branch is kept.
-- ALTER POLICY preserves roles, commands, and any existing WITH CHECK expression.
alter policy questions_staff on public.questions
  using (case when (select public.is_admin()) then true else (public.staff_can_touch_track(track_id)) end);
alter policy question_keys_staff on public.question_keys
  using (case when (select public.is_admin()) then true else (public.staff_can_touch_track(public.question_track(question_id))) end);
alter policy results_read on public.attempt_results
  using (case when (select public.is_admin()) then true else ((public.attempt_review_open(attempt_id,auth.uid()) and public.attempt_is_mine(attempt_id,auth.uid())) or public.staff_can_read_attempt(attempt_id)) end);
alter policy attempts_read on public.attempts
  using (case when (select public.is_admin()) then true else ((user_id=auth.uid() and public.is_enrolled(auth.uid(),public.exam_track(exam_id))) or (public.staff_can_touch_track(public.exam_track(exam_id)) and public.staff_can_read_student(user_id))) end);
alter policy exams_read on public.exams
  using (case when (select public.is_admin()) then true else (public.staff_can_touch_track(track_id) or (is_published and public.is_enrolled(auth.uid(),track_id) and public.exam_assigned_to(id,auth.uid()))) end);
alter policy exams_staff_write on public.exams
  using (case when (select public.is_admin()) then true else (public.staff_can_touch_track(track_id)) end);
alter policy daily_progress_staff_read on public.daily_progress
  using (case when (select public.is_admin()) then true else (public.staff_can_touch_track(track_id)) end);

-- Keep the report's additional staff guard, evaluating its admin branch once.
-- The definition is copied from the existing report; metrics and keys are unchanged.
create or replace view public.question_difficulty with (security_invoker=true) as
with response_events as (
  select r.question_id,
         r.is_correct,
         case
           when e.assessment_type = 'quiz' then 'Assigned quiz'
           when e.assessment_type = 'lesson_exam' then 'Lesson exam'
           when e.assessment_type = 'full_exam' or e.is_full_length then 'Full exam'
           else 'Assessment'
         end as source
    from public.attempt_results r
    join public.attempts a on a.id = r.attempt_id
    join public.exams e on e.id = a.exam_id
  union all
  select answer_key.question_id::uuid,
         public.answer_matches(q.type, dp.answers -> answer_key.question_id, k.correct),
         'Daily quiz'::text
    from public.daily_progress dp
    cross join lateral jsonb_object_keys(dp.answers) answer_key(question_id)
    join public.questions q on q.id = answer_key.question_id::uuid
    join public.question_keys k on k.question_id = q.id
   where dp.quiz_completed_at is not null
), metrics as (
  select q.track_id,
         q.topic as lesson,
         q.id as question_id,
         q.stem,
         string_agg(distinct e.source, ' + ' order by e.source) as sources,
         count(*)::integer as answered_by,
         count(*) filter (where e.is_correct)::integer as got_it_right,
         count(*) filter (where not e.is_correct)::integer as got_it_wrong,
         round(100.0 * count(*) filter (where e.is_correct) / count(*), 1) as percent_correct
    from response_events e
    join public.questions q on q.id = e.question_id
   where (select public.is_admin()) or public.staff_can_touch_track(q.track_id)
   group by q.track_id, q.topic, q.id, q.stem
)
select row_number() over (
         partition by track_id
         order by percent_correct asc, answered_by desc, question_id
       )::integer as rank,
       track_id, lesson, question_id, stem, sources,
       answered_by, got_it_right, got_it_wrong, percent_correct
  from metrics
 order by track_id, rank;

alter view public.question_difficulty set (security_invoker=true);
revoke all on public.question_difficulty from anon;
grant select on public.question_difficulty to authenticated;

commit;
