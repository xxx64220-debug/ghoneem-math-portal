begin;
set local lock_timeout='3s';


alter table public.daily_progress add column quiz_started_at timestamptz;

-- Evidence is written only while the server grades a notebook answer. Opening
-- the notebook (which seeds its rows), viewing a solution, and client writes
-- cannot create evidence. Keep successes even after a subsequent wrong retry.
create table portal_private.notebook_activity (
  user_id uuid not null references public.profiles(id) on delete cascade,
  track_id text not null references public.tracks(id),
  day date not null,
  question_id uuid not null references public.questions(id) on delete cascade,
  started_at timestamptz not null,
  completed_at timestamptz,
  primary key(user_id, track_id, day, question_id)
);
alter table portal_private.notebook_activity enable row level security;
revoke all on portal_private.notebook_activity from public, anon, authenticated;
grant all on portal_private.notebook_activity to service_role;

-- Retain verifiable work done earlier on the rollout day. Notebook reads only
-- insert zero-try rows; updated_at on a tried row comes from server grading.
insert into portal_private.notebook_activity(user_id,track_id,day,question_id,started_at,completed_at)
select n.user_id,q.track_id,(n.updated_at at time zone 'Africa/Cairo')::date,n.question_id,
 n.updated_at,case when n.correct_streak>0 then n.updated_at end
from public.practice_notebook n join public.questions q on q.id=n.question_id
where n.tries>0 and n.updated_at >= ((now() at time zone 'Africa/Cairo')::date::timestamp at time zone 'Africa/Cairo')
 and n.updated_at<=now();

create function portal_private.record_notebook_activity() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.tries > old.tries then
    insert into portal_private.notebook_activity(user_id,track_id,day,question_id,started_at,completed_at)
    select new.user_id,q.track_id,(now() at time zone 'Africa/Cairo')::date,new.question_id,
      now(),case when new.correct_streak>0 then now() end
    from public.questions q where q.id=new.question_id
    on conflict(user_id,track_id,day,question_id) do update
      set completed_at=coalesce(notebook_activity.completed_at,excluded.completed_at);
  end if;
  return new;
end $$;
revoke all on function portal_private.record_notebook_activity() from public,anon,authenticated;
create trigger record_verified_notebook_activity after update on public.practice_notebook
for each row execute function portal_private.record_notebook_activity();

-- A read-only calculation; the selected group is validated by daily_group_state.
-- A shared exam can satisfy both groups only when both assigned that exam.
-- Weak-topic drills and notebook corrections are explicitly course activities.
create function portal_private.daily_checklist_evidence(p_user uuid,p_track text,p_group uuid,p_day date)
returns jsonb language sql stable security invoker set search_path = '' as $$
with bounds as (
 select p_day::timestamp at time zone 'Africa/Cairo' lo,
        (p_day+1)::timestamp at time zone 'Africa/Cairo' hi
), exam_work as (
 select a.id,a.submitted_at,
   a.status in ('submitted','graded') and a.submitted_at is not null
   and exists(select 1 from public.attempt_answers x where x.attempt_id=a.id
     and x.response is not null and x.response not in ('null'::jsonb,'{}'::jsonb,'""'::jsonb)) done
 from public.attempts a join public.exams e on e.id=a.exam_id cross join bounds b
 where a.user_id=p_user and e.track_id=p_track and e.assessment_type='lesson_exam'
   and ((a.submitted_at>=b.lo and a.submitted_at<b.hi and a.status in ('submitted','graded'))
     or (a.started_at>=b.lo and a.started_at<b.hi and a.status='in_progress'))
   and exists(select 1 from public.assignments x where x.exam_id=a.exam_id
     and (x.user_id=p_user or (x.group_id=p_group and exists(
       select 1 from public.group_members gm where gm.group_id=p_group and gm.user_id=p_user)))
     and (x.open_at is null or x.open_at<=a.started_at)
     and (x.close_at is null or x.close_at>=a.started_at))
), drill_work as (
 select d.id,d.completed_at,d.completed_at is not null done
 from public.practice_drills d cross join bounds b
 where d.user_id=p_user and d.track_id=p_track
   and ((d.completed_at>=b.lo and d.completed_at<b.hi)
     or (d.created_at>=b.lo and d.created_at<b.hi and d.completed_at is null))
), focus as (
 select id,done,submitted_at completed_at,'attempt' kind from exam_work
 union all select id,done,completed_at,'drill' from drill_work
), review as (
 select question_id,completed_at from portal_private.notebook_activity
 where user_id=p_user and track_id=p_track and day=p_day
)
select jsonb_build_object(
 'focus',case when exists(select 1 from focus where done) then 'completed'
   when exists(select 1 from focus) then 'started' else 'pending' end,
 'review',case when exists(select 1 from review where completed_at is not null) then 'completed'
   when exists(select 1 from review) then 'started' else 'pending' end,
 'focus_evidence',(select jsonb_build_object('kind',kind,'id',id,'completed_at',completed_at)
   from focus order by done desc,completed_at desc nulls last,id limit 1),
 'review_evidence',(select jsonb_build_object('kind','notebook','id',question_id,'completed_at',completed_at)
   from review order by completed_at desc nulls last,question_id limit 1)
);
$$;
revoke all on function portal_private.daily_checklist_evidence(uuid,text,uuid,date) from public,anon,authenticated;
grant execute on function portal_private.daily_checklist_evidence(uuid,text,uuid,date) to service_role;

-- Close both legacy marking routes, including old cached clients.
create or replace function public.daily_group_mark(p_user uuid,p_track text,p_task text,p_group uuid,p_day date default null)
returns jsonb language plpgsql security invoker set search_path = '' as $$
begin raise exception 'automatic_completion_required'; end $$;
revoke all on function public.daily_group_mark(uuid,text,text,uuid,date) from public,anon,authenticated;
revoke all on function public.daily_mark(uuid,text,text) from public,anon,authenticated;

-- Preserve the existing quiz selection, grading, score, leaderboard and streak
-- routines. Reconcile checklist evidence under their existing per-user lock.
do $patch$
declare definition text;
begin
 select pg_get_functiondef('public.daily_group_state(uuid,text,uuid)'::regprocedure) into definition;
 if position('verified_daily_checklist_v1' in definition)>0 then raise exception 'already_applied'; end if;
 if position('  week_ jsonb;' in definition)=0 or position('  select * into progress_ from public.daily_progress' in definition)=0 then
   raise exception 'daily_state_source_changed';
 end if;
 definition:=replace(definition,'  week_ jsonb;','  week_ jsonb; evidence_ jsonb; -- verified_daily_checklist_v1');
 definition:=replace(definition,'  select * into progress_ from public.daily_progress',
 $insert$  evidence_:=portal_private.daily_checklist_evidence(p_user,p_track,gid,d);
  update public.daily_progress set focus_done=evidence_->>'focus'='completed',review_done=evidence_->>'review'='completed'
  where user_id=p_user and track_id=p_track and day=d and quiz_group_id is not distinct from gid
    and (focus_done is distinct from (evidence_->>'focus'='completed') or review_done is distinct from (evidence_->>'review'='completed'));
  update public.daily_progress set points=points+5,bonus_awarded=true
  where user_id=p_user and track_id=p_track and day=d and quiz_group_id is not distinct from gid
    and quiz_completed_at is not null and focus_done and review_done and not bonus_awarded;
  select * into progress_ from public.daily_progress$insert$);
 definition:=replace(definition,'''checklist'',jsonb_build_object(',
 '''activity_status'',evidence_ || jsonb_build_object(''quiz'',case when progress_.quiz_completed_at is not null then ''completed'' when progress_.quiz_started_at is not null then ''started'' else ''pending'' end),''checklist'',jsonb_build_object(');
 execute definition;
end $patch$;

create function public.daily_group_start(p_user uuid,p_track text,p_group uuid,p_day date)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare gid uuid; d date:=(now() at time zone 'Africa/Cairo')::date;
begin
 if p_day is distinct from d then raise exception 'daily_date_changed'; end if;
 gid:=public.daily_quiz_group(p_user,p_track,p_group);
 perform public.daily_group_state(p_user,p_track,coalesce(gid,'00000000-0000-0000-0000-000000000000'::uuid));
 update public.daily_progress set quiz_started_at=now()
 where user_id=p_user and track_id=p_track and day=d and quiz_group_id is not distinct from gid
 and quiz_started_at is null;
 return jsonb_build_object('status','started');
end $$;
revoke all on function public.daily_group_start(uuid,text,uuid,date) from public,anon,authenticated;
grant execute on function public.daily_group_start(uuid,text,uuid,date) to service_role;

notify pgrst,'reload schema';


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
