begin;
alter table public.student_daily_objectives
 add column skipped_activities text[] not null default '{}'
   check (skipped_activities <@ array['lesson','practice','retest']::text[]),
 add column practice_source text not null default 'exam' check(practice_source in ('exam','daily_quiz')),
 add column practice_group_id uuid references public.groups(id);

create function portal_private.validate_objective_activity() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if exists(select 1 from public.exams e where e.id in (new.lesson_exam_id,new.practice_exam_id,new.retest_exam_id)
   and e.track_id<>new.track_id) then raise exception 'objective_exam_track_mismatch'; end if;
 if new.practice_source='daily_quiz' and new.practice_group_id is not null and not exists(
  select 1 from public.groups g join public.group_members gm on gm.group_id=g.id
  where g.id=new.practice_group_id and g.track_id=new.track_id and gm.user_id=new.user_id
 ) then raise exception 'objective_quiz_group_not_assigned'; end if;
 return new;
end $$;
revoke all on function portal_private.validate_objective_activity() from public,anon,authenticated;
create trigger validate_objective_activity before insert or update on public.student_daily_objectives
 for each row execute function portal_private.validate_objective_activity();

-- Students can read only their own quiz evidence. All score writes remain
-- server-only. Existing staff and approved-session policies remain in force.
grant select on public.daily_progress to authenticated;
create policy daily_progress_own_read on public.daily_progress for select to authenticated
 using (user_id=(select auth.uid()));

create or replace view public.study_activity_completion with(security_invoker=true) as
select p.user_id,p.track_id,p.study_date,target.activity,target.exam_id linked_exam_id,
 evidence.id attempt_id,
 case when target.source='daily_quiz' then quiz.quiz_completed_at else evidence.submitted_at end submitted_at,
 case
   when target.source='daily_quiz' and quiz.quiz_completed_at is not null then 'completed'
   when target.source='exam' and evidence.status in ('submitted','graded') then 'completed'
   when target.activity=any(p.skipped_activities) then 'skipped'
   when target.source='exam' and target.exam_id is null then 'needs_link'
   when target.source='daily_quiz' and quiz.quiz_started_at is not null then 'in_progress'
   when evidence.status='in_progress' then 'in_progress'
   else 'pending' end status
from public.student_daily_objectives p
cross join lateral(values
 ('lesson'::text,p.lesson_exam_id,'exam'::text),
 ('practice'::text,p.practice_exam_id,p.practice_source),
 ('retest'::text,p.retest_exam_id,'exam'::text)
) target(activity,exam_id,source)
left join public.daily_progress quiz on target.source='daily_quiz' and quiz.user_id=p.user_id
 and quiz.track_id=p.track_id and quiz.day=p.study_date and quiz.quiz_group_id is not distinct from p.practice_group_id
left join lateral(
 select a.id,a.status,a.submitted_at
 from public.attempts a join public.exams e on e.id=a.exam_id and e.track_id=p.track_id
 where target.source='exam' and a.user_id=p.user_id and a.exam_id=target.exam_id
 and a.started_at>=(p.study_date::timestamp at time zone 'Africa/Cairo')
 and (a.status='in_progress' or (a.status in ('submitted','graded') and a.submitted_at is not null
   and exists(select 1 from public.attempt_answers x where x.attempt_id=a.id and x.response is not null
    and x.response not in ('null'::jsonb,'{}'::jsonb,'""'::jsonb))))
 and not exists(select 1 from public.student_daily_objectives next_plan
  where next_plan.user_id=p.user_id and next_plan.track_id=p.track_id and next_plan.study_date>p.study_date
   and next_plan.study_date<=(a.started_at at time zone 'Africa/Cairo')::date
   and (target.exam_id in (next_plan.lesson_exam_id,next_plan.retest_exam_id)
     or (next_plan.practice_source='exam' and target.exam_id=next_plan.practice_exam_id)))
 order by (a.status in ('submitted','graded')) desc,a.submitted_at desc nulls last,a.started_at desc,a.id limit 1
) evidence on true;

revoke all on public.study_activity_completion from public,anon,authenticated;
grant select on public.study_activity_completion to authenticated;
notify pgrst,'reload schema';
commit;
