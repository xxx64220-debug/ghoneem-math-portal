begin;

alter table public.student_daily_objectives
  add column if not exists lesson_exam_id uuid references public.exams(id);

create index if not exists student_daily_objectives_lesson_exam_idx
  on public.student_daily_objectives (lesson_exam_id);

-- Retain old self-reports as history, but clients can no longer write them.
revoke insert, update, delete on public.study_activity_progress from public, anon, authenticated;
drop policy if exists planner_progress_insert on public.study_activity_progress;
drop policy if exists planner_progress_update on public.study_activity_progress;

-- Read through the caller's existing objective, exam and attempt access policies.
create or replace view public.study_activity_completion
with (security_invoker = true) as
select p.user_id, p.track_id, p.study_date, target.activity,
       target.exam_id as linked_exam_id,
       evidence.id as attempt_id,
       evidence.submitted_at,
       case
         when target.exam_id is null then 'needs_link'
         when evidence.status in ('submitted', 'graded') then 'completed'
         when evidence.status = 'in_progress' then 'in_progress'
         else 'pending'
       end as status
from public.student_daily_objectives p
cross join lateral (values
  ('lesson'::text, p.lesson_exam_id),
  ('practice'::text, p.practice_exam_id),
  ('retest'::text, p.retest_exam_id)
) target(activity, exam_id)
left join lateral (
  select a.id, a.status, a.submitted_at
  from public.attempts a
  join public.exams e on e.id = a.exam_id and e.track_id = p.track_id
  where a.user_id = p.user_id and a.exam_id = target.exam_id
    and a.started_at >= (p.study_date::timestamp at time zone 'Africa/Cairo')
    and (
      a.status = 'in_progress'
      or (a.status in ('submitted', 'graded') and a.submitted_at is not null
          and exists (
            select 1 from public.attempt_answers answer
            where answer.attempt_id = a.id
              and answer.response is not null
              and answer.response not in ('null'::jsonb, '{}'::jsonb, '""'::jsonb)
          ))
    )
    -- A later assignment of this exam needs a new attempt. Late work can still
    -- complete the earlier objective until that exam is assigned again.
    and not exists (
      select 1 from public.student_daily_objectives next_plan
      where next_plan.user_id = p.user_id and next_plan.track_id = p.track_id
        and next_plan.study_date > p.study_date
        and next_plan.study_date <= (a.started_at at time zone 'Africa/Cairo')::date
        and target.exam_id in (next_plan.lesson_exam_id, next_plan.practice_exam_id, next_plan.retest_exam_id)
    )
  order by (a.status in ('submitted', 'graded')) desc, a.submitted_at desc nulls last, a.started_at desc, a.id
  limit 1
) evidence on true;

revoke all on public.study_activity_completion from public, anon, authenticated;
grant select on public.study_activity_completion to authenticated;
comment on view public.study_activity_completion is
  'Read-only study completion from submitted assessment attempts. Existing RLS applies. Unlinked activities cannot be self-certified.';

notify pgrst, 'reload schema';
commit;
