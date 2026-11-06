begin;

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
commit;
