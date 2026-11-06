begin;
-- Match an existing objective to its own scheduled assessment, never by topic
-- alone. No exam, attempt, schedule or student assignment is created here.
update public.student_daily_objectives p set practice_exam_id=r.exam_id
from portal_private.weekly_assessment_schedules s
join portal_private.weekly_assessment_runs r on r.schedule_id=s.id and r.status='ready'
join public.assignments a on a.id=r.assignment_id and a.exam_id=r.exam_id and a.group_id=s.group_id
join public.exams e on e.id=r.exam_id and e.track_id=s.track_id
where s.code='alex-est1-tuesday-algebra' and p.track_id=s.track_id
 and p.title=e.title and p.study_date=(a.open_at at time zone 'Africa/Cairo')::date
 and p.practice_exam_id is null and exists(select 1 from public.group_members gm where gm.group_id=s.group_id and gm.user_id=p.user_id);

create or replace function portal_private.my_alex_weekly_objective()
returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object('id',e.id,'title',e.title,'open_at',a.open_at,'close_at',a.close_at,
 'resume',coalesce(t.status='in_progress' and t.deadline_at>now(),false),
 'attempt_id',t.id,'completed',coalesce(t.completed,false),
 'status',case when t.completed then 'completed' when t.status='in_progress' then 'started' else 'pending' end)
from portal_private.weekly_assessment_schedules s
join portal_private.weekly_assessment_runs r on r.schedule_id=s.id and r.status='ready'
join public.assignments a on a.id=r.assignment_id and a.exam_id=r.exam_id and a.group_id=s.group_id
join public.group_members m on m.group_id=a.group_id and m.user_id=auth.uid()
join public.exams e on e.id=a.exam_id and e.track_id=s.track_id and e.is_published
left join lateral(
 select x.id,x.status,x.deadline_at,
   x.status in ('submitted','graded') and x.submitted_at is not null and exists(
    select 1 from public.attempt_answers ans where ans.attempt_id=x.id and ans.response is not null
      and ans.response not in ('null'::jsonb,'{}'::jsonb,'""'::jsonb)) completed
 from public.attempts x where x.user_id=m.user_id and x.exam_id=e.id
 order by completed desc,x.attempt_no desc limit 1
) t on true
where s.code='alex-est1-tuesday-algebra' and s.enabled and s.track_id='est'
and exists(select 1 from jsonb_array_elements(public.my_course_access()) x
 where x->>'track_id'=s.track_id and (x->>'practice_open')::boolean)
and (a.close_at>=now() or (t.status='in_progress' and t.deadline_at>now())
 or (t.completed and (a.open_at at time zone 'Africa/Cairo')::date=(now() at time zone 'Africa/Cairo')::date))
order by a.open_at limit 1
$$;
notify pgrst,'reload schema';
commit;
