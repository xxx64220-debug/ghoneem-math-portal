-- Rank every answered question by real cohort performance. This combines
-- assigned assessments (including quizzes) with the five-question daily quiz.
-- The invoker view needs a narrowly scoped staff read policy for daily data.
alter table public.daily_progress enable row level security;
drop policy if exists daily_progress_staff_read on public.daily_progress;
create policy daily_progress_staff_read on public.daily_progress
  for select to authenticated
  using (public.staff_can_touch_track(track_id));
grant select on public.daily_progress to authenticated;

drop view if exists public.question_difficulty;
create view public.question_difficulty as
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
   where public.staff_can_touch_track(q.track_id)
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
