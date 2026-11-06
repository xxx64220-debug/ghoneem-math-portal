create or replace function portal_private.my_alex_weekly_objective() returns jsonb
language sql stable security definer set search_path='' as $$
select jsonb_build_object('id',e.id,'title',e.title,'open_at',a.open_at,'close_at',a.close_at,'resume',coalesce(t.status='in_progress' and t.deadline_at>now(),false))
from portal_private.weekly_assessment_schedules s
join portal_private.weekly_assessment_runs r on r.schedule_id=s.id and r.status='ready'
join public.assignments a on a.id=r.assignment_id and a.exam_id=r.exam_id and a.group_id=s.group_id
join public.group_members m on m.group_id=a.group_id and m.user_id=auth.uid()
join public.exams e on e.id=a.exam_id and e.track_id=s.track_id and e.is_published
left join lateral (select status,deadline_at from public.attempts where user_id=m.user_id and exam_id=e.id order by attempt_no desc limit 1) t on true
where s.code='alex-est1-tuesday-algebra' and s.enabled and s.track_id='est'
and exists(select 1 from jsonb_array_elements(public.my_course_access()) x where x->>'track_id'=s.track_id and (x->>'practice_open')::boolean)
and ((t.status is null and a.close_at>=now()) or (t.status='in_progress' and t.deadline_at>now()))
order by a.open_at limit 1
$$;
revoke all on function portal_private.my_alex_weekly_objective() from public,anon;
grant execute on function portal_private.my_alex_weekly_objective() to authenticated;
create or replace function public.my_alex_weekly_objective() returns jsonb language sql stable security invoker set search_path='' as $$select portal_private.my_alex_weekly_objective()$$;
revoke all on function public.my_alex_weekly_objective() from public,anon;
grant execute on function public.my_alex_weekly_objective() to authenticated;
