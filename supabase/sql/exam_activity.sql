begin;
-- Browser-reported activity is a review aid, never evidence sufficient to grade.
create table if not exists public.exam_activity_events(
 attempt_id uuid not null references public.attempts(id) on delete cascade,
 event_id uuid not null,
 kind text not null check(kind in ('started','hidden','visible')),
 client_at timestamptz not null,
 received_at timestamptz not null default now(),
 primary key(attempt_id,event_id)
);
alter table public.exam_activity_events enable row level security;
revoke all on public.exam_activity_events from public,anon,authenticated;
grant all on public.exam_activity_events to service_role;

create or replace function public.exam_activity(p_actor uuid,p_action text,p_data jsonb default '{}')
returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare role_ text; att public.attempts%rowtype; ex public.exams%rowtype; ev jsonb; event_ uuid; time_ timestamptz; track_ text:=p_data->>'track'; data_ jsonb; accepted_ jsonb:='[]'; page_ int:=coalesce((p_data->>'page')::int,0); n int;
begin
 select role into role_ from public.profiles where id=p_actor and status='active';
 if role_ is null then raise exception 'forbidden';end if;
 if p_action='events' then
  if role_<>'student' then raise exception 'student_account_required';end if;
  select * into att from public.attempts where id=(p_data->>'attempt_id')::uuid and user_id=p_actor;
  if not found then raise exception 'attempt_not_found';end if;
  select * into ex from public.exams where id=att.exam_id;
  if not public.is_enrolled(p_actor,ex.track_id) then raise exception 'not_enrolled_in_track';end if;
  if ex.assessment_type not in ('quiz','full_exam') or not isfinite(att.deadline_at) then raise exception 'activity_not_enabled';end if;
  if now()>least(coalesce(att.submitted_at,att.deadline_at),att.deadline_at)+interval '24 hours' then raise exception 'activity_window_closed';end if;
  if jsonb_typeof(p_data->'events') is distinct from 'array' or jsonb_array_length(p_data->'events') not between 1 and 20 then raise exception 'invalid_events';end if;
  perform pg_advisory_xact_lock(hashtextextended('activity:'||att.id::text,0));
  for ev in select * from jsonb_array_elements(p_data->'events') loop
   event_:=(ev->>'id')::uuid;time_:=(ev->>'at')::timestamptz;
   if event_ is null or ev->>'kind' is null or ev->>'kind' not in ('started','hidden','visible') or time_ is null or not isfinite(time_)
    or time_<att.started_at-interval '5 minutes' or time_>least(now(),coalesce(att.submitted_at,att.deadline_at),att.deadline_at)+interval '5 minutes' then raise exception 'invalid_event';end if;
   if exists(select 1 from public.exam_activity_events where attempt_id=att.id and event_id=event_) then
    accepted_:=accepted_||to_jsonb(event_::text);continue;
   end if;
   if (select count(*) from public.exam_activity_events where attempt_id=att.id)>=1000 then raise exception 'activity_limit_reached';end if;
   insert into public.exam_activity_events(attempt_id,event_id,kind,client_at) values(att.id,event_,ev->>'kind',time_);
   accepted_:=accepted_||to_jsonb(event_::text);
  end loop;
  return jsonb_build_object('accepted',accepted_);
 end if;
 if role_ not in ('admin','instructor') then raise exception 'staff_required';end if;
 if p_action='details' then
  select * into att from public.attempts where id=(p_data->>'attempt_id')::uuid;
  if not found then raise exception 'attempt_not_found';end if;
  select * into ex from public.exams where id=att.exam_id;track_:=ex.track_id;
 end if;
 if track_ is null or not exists(select 1 from public.tracks where id=track_ and is_active) then raise exception 'choose_track';end if;
 if role_='instructor' and not exists(select 1 from public.instructor_tracks where user_id=p_actor and track_id=track_) then raise exception 'forbidden_track';end if;
 if p_action='details' then
  if role_='instructor' and not exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where g.instructor_id=p_actor and g.track_id=track_ and gm.user_id=att.user_id) then raise exception 'attempt_not_found';end if;
  return jsonb_build_object('exam',ex.title,'student',(select full_name from public.profiles where id=att.user_id),'events',(select coalesce(jsonb_agg(jsonb_build_object('kind',kind,'client_at',client_at,'received_at',received_at) order by client_at,received_at),'[]') from public.exam_activity_events where attempt_id=att.id));
 elsif p_action='summary' then
  if page_ not between 0 and 10000 then raise exception 'invalid_page';end if;
  select count(*) into n from public.attempts a join public.exams e on e.id=a.exam_id where e.track_id=track_ and e.assessment_type in ('quiz','full_exam') and isfinite(a.deadline_at)
   and (role_='admin' or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where g.instructor_id=p_actor and g.track_id=track_ and gm.user_id=a.user_id));
  select coalesce(jsonb_agg(x order by x->>'started_at' desc),'[]') into data_ from (
   select jsonb_build_object('id',a.id,'student',p.full_name,'exam',e.title,'status',a.status,'started_at',a.started_at,'departures',d.departures,'starts',d.starts,'events',d.events,'last_received',d.last_received) x
   from public.attempts a join public.exams e on e.id=a.exam_id join public.profiles p on p.id=a.user_id
   left join lateral(select count(*) events,count(*) filter(where kind='hidden') departures,count(*) filter(where kind='started') starts,max(received_at) last_received from public.exam_activity_events where attempt_id=a.id) d on true
   where e.track_id=track_ and e.assessment_type in ('quiz','full_exam') and isfinite(a.deadline_at)
    and (role_='admin' or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where g.instructor_id=p_actor and g.track_id=track_ and gm.user_id=a.user_id))
   order by a.started_at desc,a.id limit 100 offset page_*100) rows_;
  return jsonb_build_object('items',data_,'total',n,'page',page_);
 end if;
 raise exception 'invalid_action';
end $$;
revoke all on function public.exam_activity(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.exam_activity(uuid,text,jsonb) to service_role;
commit;
