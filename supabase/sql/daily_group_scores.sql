-- Preserve every existing daily row; null group means unattributed course history.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
do $$begin if md5(pg_get_functiondef('public.daily_state(uuid,text)'::regprocedure))<>'6495c6c7587ba94a38dc4a4b3d4b485e' then raise exception 'daily_group_source_changed'; end if;end$$;
do $$begin if md5(pg_get_functiondef('public.daily_submit(uuid,text,jsonb)'::regprocedure))<>'219299804aded2f41c87dc32e9e37990' then raise exception 'daily_group_source_changed'; end if;end$$;
do $$begin if md5(pg_get_functiondef('public.daily_mark(uuid,text,text)'::regprocedure))<>'8463ad0aa13c965bdde24b13335e83a8' then raise exception 'daily_group_source_changed'; end if;end$$;
do $$begin if md5(pg_get_functiondef('public.portal_manage(uuid,text,jsonb)'::regprocedure))<>'9f4928a36dfda83849b07de0cfe51b08' then raise exception 'daily_group_source_changed'; end if;end$$;
lock table public.daily_progress in access exclusive mode;
select set_config('portal.daily_rows_before',coalesce((select md5(string_agg((to_jsonb(p)-'group_scope')::text,'|' order by user_id,track_id,day,quiz_group_id)) from public.daily_progress p),md5('')),true);
-- Adding a generated discriminator avoids ambiguous NULL uniqueness and keeps old rows intact.
alter table public.daily_progress add column group_scope uuid generated always as (coalesce(quiz_group_id,'00000000-0000-0000-0000-000000000000'::uuid)) stored;
alter table public.daily_progress add constraint daily_group_scope_reserved check(quiz_group_id is distinct from '00000000-0000-0000-0000-000000000000'::uuid);
alter table public.daily_progress drop constraint daily_progress_pkey;
alter table public.daily_progress add primary key(user_id,track_id,day,group_scope);
create index daily_progress_group_rank_idx on public.daily_progress(track_id,group_scope,user_id,day);
alter policy daily_progress_staff_read on public.daily_progress using (
 (select public.is_admin()) or (public.staff_can_touch_track(track_id) and
  ((quiz_group_id is null and public.staff_can_read_student(user_id)) or exists(
   select 1 from public.groups g where g.id=quiz_group_id and g.instructor_id=auth.uid() and g.track_id=daily_progress.track_id))));
create function public.daily_quiz_group(p_user uuid,p_track text,p_group uuid) returns uuid
language plpgsql stable security invoker set search_path=public,pg_temp as $$
declare gid uuid; d date:=(now() at time zone 'Africa/Cairo')::date;
begin
 if not exists(select 1 from profiles p where p.id=p_user and p.role='student' and p.status='active')
  or not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
 if p_group='00000000-0000-0000-0000-000000000000'::uuid then
  if exists(select 1 from daily_progress where user_id=p_user and track_id=p_track and quiz_group_id is null)
   or not exists(select 1 from groups g join group_members gm on gm.group_id=g.id where gm.user_id=p_user and g.track_id=p_track
    and (g.course_starts_on is null or g.course_starts_on<=d) and (g.course_ends_on is null or g.course_ends_on>=d)) then return null; end if;
  raise exception 'daily_group_not_assigned';
 elsif p_group is not null then
  select g.id into gid from groups g join group_members gm on gm.group_id=g.id where gm.user_id=p_user and g.track_id=p_track and g.id=p_group
   and (g.course_starts_on is null or g.course_starts_on<=d) and (g.course_ends_on is null or g.course_ends_on>=d);
  if gid is null then raise exception 'daily_group_not_assigned'; end if;
  return gid;
 end if;
 -- An already-opened legacy course quiz stays available to old clients.
 if exists(select 1 from daily_progress where user_id=p_user and track_id=p_track and day=d and quiz_group_id is null) then return null; end if;
 select dp.quiz_group_id into gid from daily_progress dp join groups g on g.id=dp.quiz_group_id join group_members gm on gm.group_id=g.id and gm.user_id=p_user
  where dp.user_id=p_user and dp.track_id=p_track and dp.day=d and g.track_id=p_track
   and (g.course_starts_on is null or g.course_starts_on<=d) and (g.course_ends_on is null or g.course_ends_on>=d)
  order by dp.quiz_completed_at nulls first,dp.quiz_group_id limit 1;
 if gid is not null then return gid; end if;
 select g.id into gid from enrollments e join groups g on g.id=e.daily_group_id join group_members gm on gm.group_id=g.id and gm.user_id=e.user_id
  where e.user_id=p_user and e.track_id=p_track and g.track_id=p_track
   and (g.course_starts_on is null or g.course_starts_on<=d) and (g.course_ends_on is null or g.course_ends_on>=d);
 if gid is not null then return gid; end if;
 select g.id into gid from groups g join group_members gm on gm.group_id=g.id where gm.user_id=p_user and g.track_id=p_track
  and (g.course_starts_on is null or g.course_starts_on<=d) and (g.course_ends_on is null or g.course_ends_on>=d)
  order by (g.id is not distinct from public.default_group(p_track)),lower(g.name),g.id limit 1;
 return gid;
end $$;
CREATE OR REPLACE FUNCTION public.daily_group_state(p_user uuid, p_track text, p_group uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  d date := (now() at time zone 'Africa/Cairo')::date;
  qids uuid[]; gid uuid; existing_progress boolean;
  progress_ public.daily_progress%rowtype;
  quiz_ jsonb;
  leaders_ jsonb;
  myrank_ integer;
  mytotal_ integer;
  current_ integer;
  best_ integer;
  week_ jsonb;
begin
  if not exists (
    select 1 from public.profiles p join public.enrollments e on e.user_id=p.id
    join public.tracks t on t.id=e.track_id
    where p.id=p_user and p.role='student' and p.status='active'
      and e.track_id=p_track and public.is_enrolled(p_user,p_track)
  ) then raise exception 'not_enrolled_in_track'; end if;

  gid:=public.daily_quiz_group(p_user,p_track,p_group);
  perform pg_advisory_xact_lock(hashtextextended('daily-user:'||p_user::text||':'||p_track||':'||coalesce(gid::text,'course')||':'||d::text,0));
  perform pg_advisory_xact_lock(hashtextextended('daily:'||coalesce(gid::text,p_track)||':'||d::text,0));
  if gid is null then select question_ids into qids from public.daily_quizzes where track_id=p_track and day=d;
  else select question_ids into qids from public.daily_group_quizzes where group_id=gid and day=d;end if;
  if qids is null then
  select array(
    select q.id from public.questions q join public.question_keys k on k.question_id=q.id
    where q.track_id=p_track and q.type='mcq' and portal_private.question_eligible(q,k,p_track,true) and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve)
      and ((gid is not null and exists(select 1 from public.groups g where g.id=gid and cardinality(g.daily_lessons)>0 and q.topic=any(g.daily_lessons)))
       or ((gid is null or exists(select 1 from public.groups g where g.id=gid and cardinality(g.daily_lessons)=0))
       and exists(select 1 from public.portal_track_controls c where c.track_id=p_track and
       (c.daily_mode='random' or (c.daily_mode='lessons' and q.topic=any(c.daily_lessons)) or (c.daily_mode='selected' and q.id=any(c.daily_question_ids))))))
    order by md5(d::text || coalesce(gid::text,'') || q.id::text) limit 5
  ) into qids;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;
  if gid is null then insert into public.daily_quizzes(track_id,day,question_ids) values(p_track,d,qids);
  else insert into public.daily_group_quizzes(group_id,day,question_ids) values(gid,d,qids);end if;
  end if;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;

  insert into public.daily_progress(user_id,track_id,day,quiz_group_id) values(p_user,p_track,d,gid)
  on conflict (user_id,track_id,day,group_scope) do nothing;
  select * into progress_ from public.daily_progress
  where user_id=p_user and track_id=p_track and day=d and quiz_group_id is not distinct from gid;

  if progress_.quiz_completed_at is null and (select count(*) from public.questions q join public.question_keys k on k.question_id=q.id where q.id=any(qids) and portal_private.question_eligible(q,k,p_track,true))<>5 then raise exception 'daily_content_under_review'; end if;

  select jsonb_agg(jsonb_build_object(
    'id',q.id,'stem',q.stem,'choices',q.choices,'topic',q.topic,'assets',q.assets,
    'answer',case when progress_.quiz_completed_at is null then null else
      jsonb_build_object('correct',k.correct,'explanation',k.explanation,
        'submitted',progress_.answers->q.id::text) end
  ) order by ord.n) into quiz_
  from unnest(qids) with ordinality ord(id,n)
  join public.questions q on q.id=ord.id join public.question_keys k on k.question_id=q.id;

  with ranked as (
    select e.user_id, p.full_name,
      coalesce(sum(dp.points),0)::integer as points,
      count(dp.quiz_completed_at)::integer as completed,
      row_number() over (order by coalesce(sum(dp.points),0) desc,
        count(dp.quiz_completed_at) desc, e.user_id) as rank
    from public.enrollments e join public.profiles p on p.id=e.user_id
    left join public.daily_progress dp on dp.user_id=e.user_id and dp.track_id=e.track_id and dp.quiz_group_id is not distinct from gid
    where e.track_id=p_track and public.is_enrolled(e.user_id,p_track) and (gid is null or exists(select 1 from public.group_members gm where gm.group_id=gid and gm.user_id=e.user_id))
    group by e.user_id,p.full_name
  ) select coalesce(jsonb_agg(jsonb_build_object(
      'rank',rank,'name',split_part(coalesce(full_name,'Student'),' ',1)
        || case when position(' ' in btrim(coalesce(full_name,'')))>0 then ' '
          || left(reverse(split_part(reverse(btrim(full_name)),' ',1)),1) || '.' else '' end,
      'points',points,'completed',completed
    ) order by rank) filter (where rank<=10),'[]'::jsonb),
    (max(rank) filter (where user_id=p_user))::integer,
    max(points) filter (where user_id=p_user)
    into leaders_,myrank_,mytotal_ from ranked;

  with days as (
    select day, day - (row_number() over(order by day))::int as island
    from public.daily_progress where user_id=p_user and track_id=p_track and quiz_group_id is not distinct from gid
      and quiz_completed_at is not null and day<=d
  ), runs as (
    select count(*)::int as length,max(day) as last_day from days group by island
  ) select coalesce(max(length) filter(where last_day>=d-1),0),
      coalesce(max(length),0) into current_,best_ from runs;
  if progress_.quiz_completed_at is null and (select count(*) from public.questions q join public.question_keys k on k.question_id=q.id where q.id=any(qids) and portal_private.question_eligible(q,k,p_track,true))<>5 then raise exception 'daily_content_under_review'; end if;

  select jsonb_agg(jsonb_build_object('date',d-offset_,
    'completed',exists(select 1 from public.daily_progress p where p.user_id=p_user
      and p.track_id=p_track and p.quiz_group_id is not distinct from gid and p.day=d-offset_ and p.quiz_completed_at is not null),
    'today',offset_=0) order by offset_ desc) into week_ from generate_series(0,6) offset_;

  return jsonb_build_object('date',d,'reset_at',((d+1)::timestamp at time zone 'Africa/Cairo'),
    'server_now',now(),'streak',jsonb_build_object('current',current_,'longest',best_,'week',week_),
    'group_id',gid,'scope_id',coalesce(gid,'00000000-0000-0000-0000-000000000000'::uuid),'group_name',coalesce((select name from public.groups where id=gid),'Earlier course quiz'),
    'groups',(select coalesce(jsonb_agg(x order by x->>'name',x->>'id'),'[]'::jsonb) from (
     select jsonb_build_object('id',g.id,'name',g.name) x from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=p_user and g.track_id=p_track and (g.course_starts_on is null or g.course_starts_on<=d) and (g.course_ends_on is null or g.course_ends_on>=d)
     union all select jsonb_build_object('id','00000000-0000-0000-0000-000000000000','name','Earlier course quiz') where exists(select 1 from public.daily_progress dp where dp.user_id=p_user and dp.track_id=p_track and dp.quiz_group_id is null)
    ) options),'selection_mode',case when gid is not null and exists(select 1 from public.groups where id=gid and cardinality(daily_lessons)>0) then 'group lessons' else (select daily_mode from public.portal_track_controls where track_id=p_track) end,'track',p_track,'quiz',quiz_,'score',progress_.quiz_score,
    'completed',progress_.quiz_completed_at is not null,
    'checklist',jsonb_build_object('quiz',progress_.quiz_completed_at is not null,
      'focus',progress_.focus_done,'review',progress_.review_done,
      'bonus',progress_.bonus_awarded),
    'points_today',progress_.points,'points_total',coalesce(mytotal_,0),
    'rank',myrank_,'leaderboard',leaders_);
end;
$function$
;
CREATE OR REPLACE FUNCTION public.daily_group_submit(p_user uuid, p_track text, p_answers jsonb, p_group uuid, p_day date default null)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  d date := (now() at time zone 'Africa/Cairo')::date;
  progress_ public.daily_progress%rowtype;
  qids uuid[];
  correct_ integer;
  streak_ integer; gid uuid;
begin
  -- Call daily_state first to validate enrollment and create today's frozen quiz.
  if p_day is not null and p_day<>d then raise exception 'daily_date_changed'; end if;
  gid:=public.daily_quiz_group(p_user,p_track,p_group);
  perform public.daily_group_state(p_user,p_track,coalesce(gid,'00000000-0000-0000-0000-000000000000'::uuid));
  if jsonb_typeof(p_answers) is distinct from 'object' or
    (select count(*) from jsonb_object_keys(p_answers))<>5 then
    raise exception 'invalid_answers'; end if;
  select * into progress_ from public.daily_progress where user_id=p_user and track_id=p_track and quiz_group_id is not distinct from gid and day=d for update;
  if progress_.quiz_group_id is null then select question_ids into qids from public.daily_quizzes where track_id=p_track and day=d;
  else select question_ids into qids from public.daily_group_quizzes where group_id=progress_.quiz_group_id and day=d;end if;
  if exists(select 1 from jsonb_object_keys(p_answers) key where not key=any(select unnest(qids)::text))
  then raise exception 'invalid_answers'; end if;
  if exists(select 1 from unnest(qids) qid join public.questions q on q.id=qid
    where not exists(select 1 from jsonb_array_elements(q.choices) choice
      where p_answers->q.id::text=to_jsonb(choice->>'key')))
  then raise exception 'invalid_answers'; end if;
  select * into progress_ from public.daily_progress
   where user_id=p_user and track_id=p_track and quiz_group_id is not distinct from gid and day=d for update;
  if progress_.quiz_completed_at is not null then return public.daily_group_state(p_user,p_track,coalesce(gid,'00000000-0000-0000-0000-000000000000'::uuid)); end if;
  select count(*)::integer into correct_
  from unnest(qids) qid join public.questions q on q.id=qid
  join public.question_keys k on k.question_id=q.id
  where public.answer_matches(q.type,p_answers->q.id::text,k.correct);
  select case when exists(select 1 from public.daily_progress
    where user_id=p_user and track_id=p_track and quiz_group_id is not distinct from gid and day=d-1 and quiz_completed_at is not null)
    then 5 else 0 end into streak_;
  update public.daily_progress set quiz_completed_at=now(),quiz_score=correct_,answers=p_answers,
    points=points + 10 + 10*correct_ + streak_
      + case when focus_done and review_done and not bonus_awarded then 5 else 0 end,
    bonus_awarded=bonus_awarded or (focus_done and review_done)
  where user_id=p_user and track_id=p_track and quiz_group_id is not distinct from gid and day=d;
  return public.daily_group_state(p_user,p_track,coalesce(gid,'00000000-0000-0000-0000-000000000000'::uuid));
end $function$
;
CREATE OR REPLACE FUNCTION public.daily_group_mark(p_user uuid, p_track text, p_task text, p_group uuid, p_day date default null)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare d date := (now() at time zone 'Africa/Cairo')::date; gid uuid;
begin
  if p_day is not null and p_day<>d then raise exception 'daily_date_changed'; end if;
  gid:=public.daily_quiz_group(p_user,p_track,p_group);
  perform public.daily_group_state(p_user,p_track,coalesce(gid,'00000000-0000-0000-0000-000000000000'::uuid));
  if p_task not in ('focus','review') then raise exception 'invalid_task'; end if;
  update public.daily_progress set
    focus_done=focus_done or p_task='focus',
    review_done=review_done or p_task='review'
  where user_id=p_user and track_id=p_track and quiz_group_id is not distinct from gid and day=d;
  update public.daily_progress set points=points+5,bonus_awarded=true
  where user_id=p_user and track_id=p_track and quiz_group_id is not distinct from gid and day=d
    and quiz_completed_at is not null and focus_done and review_done and not bonus_awarded;
  return public.daily_group_state(p_user,p_track,coalesce(gid,'00000000-0000-0000-0000-000000000000'::uuid));
end $function$
;
create or replace function public.daily_state(p_user uuid,p_track text) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select public.daily_group_state(p_user,p_track,null);$$;
create or replace function public.daily_submit(p_user uuid,p_track text,p_answers jsonb) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select public.daily_group_submit(p_user,p_track,p_answers,null);$$;
create or replace function public.daily_mark(p_user uuid,p_track text,p_task text) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select public.daily_group_mark(p_user,p_track,p_task,null);$$;
CREATE OR REPLACE FUNCTION public.portal_manage(p_actor uuid, p_action text, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare group_ uuid; scope_ uuid; groups_ jsonb; role_ text; track_ text:=p_data->>'track'; id_ uuid; ids_ uuid[]; c public.portal_track_controls%rowtype; data_ jsonb; n int; student_ uuid; mode_ text; day_ date; before_ jsonb; report_ public.portal_reports%rowtype;
begin
 select role into role_ from public.profiles where id=p_actor and status='active';
 if role_ is null or role_ not in ('admin','instructor') then raise exception 'staff_required';end if;
 if track_ is null or not exists(select 1 from public.tracks where id=track_ and is_active) then raise exception 'choose_track';end if;
 if role_='instructor' and not exists(select 1 from public.instructor_tracks where user_id=p_actor and track_id=track_) then raise exception 'forbidden_track';end if;
 select * into c from public.portal_track_controls where track_id=track_;
 if p_action in ('quiz.list','quiz.reset') then
  select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'name',g.name) order by lower(g.name),g.id),'[]'::jsonb) into groups_
   from public.groups g where g.track_id=track_ and (role_='admin' or g.instructor_id=p_actor);
  if p_action='quiz.reset' and not p_data ? 'group_id' then raise exception 'quiz_group_required'; end if;
  if p_data ? 'group_id' then scope_:=(p_data->>'group_id')::uuid;
  else scope_:=coalesce((groups_->0->>'id')::uuid,'00000000-0000-0000-0000-000000000000'::uuid); end if;
  if scope_ is null then raise exception 'quiz_group_required'; end if;
  group_:=nullif(scope_,'00000000-0000-0000-0000-000000000000'::uuid);
  if group_ is not null and not exists(select 1 from public.groups g where g.id=group_ and g.track_id=track_ and (role_='admin' or g.instructor_id=p_actor)) then raise exception 'group_scope_denied'; end if;
 end if;
 if p_action='revision.list' then
  select coalesce(jsonb_agg(jsonb_build_object('id',r.question_id,'lesson',r.lesson,'idea',r.idea,'difficulty',r.difficulty,'active',r.active,'source',coalesce(q.assets->>'source_code',q.assets->>'code',''),'stem',q.stem,'ready',r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation) and nullif(q.assets->>'release_hold_reason','') is null) order by r.lesson,r.idea,r.question_id),'[]') into data_
  from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where q.track_id=track_;
  return jsonb_build_object('visible',c.revision_visible,'items',data_);
 elsif p_action='quiz.list' then
  return jsonb_build_object('group_id',scope_,'groups',groups_,'group_name',coalesce((select name from public.groups where id=group_),'Earlier course quiz'),'settings',to_jsonb(c),'today_frozen',exists(select 1 from public.daily_progress where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date),
   'today',(select jsonb_build_object('day',day,'question_ids',question_ids) from public.daily_quizzes where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date),
   'questions',(select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'lesson',q.topic,'stem',q.stem,'source',coalesce(q.assets->>'source_code',q.assets->>'code','')) order by q.topic,q.id),'[]') from public.questions q join public.question_keys k on k.question_id=q.id where q.track_id=track_ and q.type='mcq' and nullif(q.assets->>'verified_release','') is not null and nullif(q.assets->>'release_hold_reason','') is null and length(btrim(k.explanation))>0 and jsonb_array_length(q.choices)>=4 and jsonb_typeof(k.correct)='string' and exists(select 1 from jsonb_array_elements(q.choices) ch where ch->>'key'=k.correct#>>'{}')),
   'students',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name,'completed',coalesce(d.completed,0),'points',coalesce(d.points,0),'score_today',d.score_today,'average_score',d.average_score) order by p.full_name),'[]') from public.profiles p join public.enrollments e on e.user_id=p.id and e.track_id=track_ left join lateral(select count(quiz_completed_at) completed,sum(points) points,max(quiz_score) filter(where day=(now() at time zone 'Africa/Cairo')::date) score_today,round(avg(quiz_score),2) average_score from public.daily_progress dp where dp.user_id=p.id and dp.track_id=track_ and dp.quiz_group_id is not distinct from group_) d on true where p.role='student' and (group_ is null or exists(select 1 from public.group_members gm where gm.group_id=group_ and gm.user_id=p.id) or exists(select 1 from public.daily_progress dp where dp.user_id=p.id and dp.track_id=track_ and dp.quiz_group_id=group_)) and (role_='admin' or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=p.id and g.instructor_id=p_actor and g.track_id=track_))));
 elsif p_action='reports.list' then
  select coalesce(jsonb_agg(x order by x->>'created_at' desc),'[]') into data_ from (
   select to_jsonb(r)||jsonb_build_object('student',p.full_name,'question_stem',q.stem,'source',q.assets->>'source_code') x from public.portal_reports r join public.profiles p on p.id=r.user_id left join public.questions q on q.id=r.question_id
   where r.track_id=track_ and (role_='admin' or r.user_id=p_actor or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=r.user_id and g.instructor_id=p_actor and g.track_id=track_)) and (coalesce(p_data->>'status','all')='all' or r.status=p_data->>'status') order by r.created_at desc limit 200) z;
  return jsonb_build_object('items',data_,'open_count',(select count(*) from public.portal_reports r where r.track_id=track_ and (role_='admin' or r.user_id=p_actor or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=r.user_id and g.instructor_id=p_actor and g.track_id=track_)) and r.status in ('open','in_review')));
 elsif p_action='revision.visibility' then
  if jsonb_typeof(p_data->'visible') is distinct from 'boolean' then raise exception 'invalid_visibility';end if;
  update public.portal_track_controls set revision_visible=(p_data->>'visible')::boolean,updated_at=now() where track_id=track_;
  data_:=jsonb_build_object('visible',(p_data->>'visible')::boolean);
 elsif p_action='revision.release' then
  if jsonb_typeof(p_data->'active') is distinct from 'boolean' then raise exception 'invalid_release';end if;
  select array_agg(x::uuid) into ids_ from jsonb_array_elements_text(p_data->'ids') x;
  if coalesce(cardinality(ids_),0) not between 1 and 1000 or (select count(distinct x) from unnest(ids_) x)<>cardinality(ids_) then raise exception 'select_questions';end if;
  if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where r.question_id=any(ids_) and q.track_id=track_)<>cardinality(ids_) then raise exception 'question_track_mismatch';end if;
  if (p_data->>'active')::boolean and exists(select 1 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where r.question_id=any(ids_) and (r.fingerprint<>public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation) or nullif(q.assets->>'release_hold_reason','') is not null)) then raise exception 'questions_need_review';end if;
  update public.revision_items set active=(p_data->>'active')::boolean where question_id=any(ids_);
  data_:=jsonb_build_object('count',cardinality(ids_),'active',(p_data->>'active')::boolean);
 elsif p_action='quiz.save' then
  mode_:=p_data->>'mode';if mode_ is null or mode_ not in ('random','lessons','selected') then raise exception 'invalid_quiz_mode';end if;
  select coalesce(array_agg(x::uuid),'{}') into ids_ from jsonb_array_elements_text(coalesce(p_data->'ids','[]')) x;
  if cardinality(ids_)>1000 or (select count(distinct x) from unnest(ids_) x)<>cardinality(ids_) then raise exception 'invalid_question_selection';end if;
  if mode_='selected' and cardinality(ids_)<5 then raise exception 'select_at_least_five_questions';end if;
  select count(*) into n from public.questions q join public.question_keys k on k.question_id=q.id where q.track_id=track_ and q.type='mcq' and nullif(q.assets->>'verified_release','') is not null and nullif(q.assets->>'release_hold_reason','') is null and length(btrim(k.explanation))>0 and jsonb_array_length(q.choices)>=4 and jsonb_typeof(k.correct)='string' and exists(select 1 from jsonb_array_elements(q.choices) ch where ch->>'key'=k.correct#>>'{}') and (mode_='random' or (mode_='selected' and q.id=any(ids_)) or (mode_='lessons' and coalesce(p_data->'lessons','[]') ? q.topic));
  if n<5 then raise exception 'quiz_pool_needs_five_valid_questions';end if;
  if mode_='selected' and n<>cardinality(ids_) then raise exception 'selected_question_unavailable';end if;
  -- Same lock as daily_state: selecting today's questions cannot race an edit.
  perform pg_advisory_xact_lock(hashtextextended('daily:'||track_||':'||(now() at time zone 'Africa/Cairo')::date::text,0));
  update public.portal_track_controls set daily_mode=mode_,daily_question_ids=case when mode_='selected' then ids_ else '{}'::uuid[] end,daily_lessons=case when mode_='lessons' then array(select jsonb_array_elements_text(p_data->'lessons')) else '{}'::text[] end,updated_at=now() where track_id=track_;
  if not exists(select 1 from public.daily_progress where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date) then delete from public.daily_quizzes where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date;end if;
  data_:=jsonb_build_object('mode',mode_,'eligible',n,'today_frozen',exists(select 1 from public.daily_progress where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date));
 elsif p_action='quiz.reset' then
  if role_<>'admin' then raise exception 'admin_required';end if;
  if p_data->>'confirm' is distinct from 'RESET' then raise exception 'reset_confirmation_required';end if;
  student_:=(p_data->>'user_id')::uuid; mode_:=p_data->>'mode';day_:=nullif(p_data->>'day','')::date;
  if mode_ is null or mode_ not in ('quiz','all') then raise exception 'invalid_reset_mode';end if;
  if not exists(select 1 from public.enrollments e join public.profiles p on p.id=e.user_id where e.user_id=student_ and e.track_id=track_ and p.role='student') then raise exception 'student_not_enrolled';end if;
  if day_ is null and p_data->>'range' is distinct from 'all' then raise exception 'reset_date_required';end if;
  perform pg_advisory_xact_lock(hashtextextended('daily:'||coalesce(group_::text,track_)||':'||(now() at time zone 'Africa/Cairo')::date::text,0));
  perform 1 from public.daily_progress where user_id=student_ and track_id=track_ and quiz_group_id is not distinct from group_ and (day_ is null or day=day_) for update;
  select coalesce(jsonb_agg(to_jsonb(dp)),'[]') into before_ from public.daily_progress dp where user_id=student_ and track_id=track_ and quiz_group_id is not distinct from group_ and (day_ is null or day=day_);
  insert into public.daily_reset_archive(actor_id,user_id,track_id,reset_mode,previous_progress) values(p_actor,student_,track_,mode_,before_) returning id into id_;
  if mode_='all' then delete from public.daily_progress where user_id=student_ and track_id=track_ and quiz_group_id is not distinct from group_ and (day_ is null or day=day_);
  else update public.daily_progress set quiz_completed_at=null,quiz_score=null,answers='{}',points=0,bonus_awarded=false where user_id=student_ and track_id=track_ and quiz_group_id is not distinct from group_ and (day_ is null or day=day_);end if;
  get diagnostics n=row_count;
  data_:=jsonb_build_object('count',n,'archive_id',id_);
 elsif p_action='reports.update' then
  id_:=(p_data->>'id')::uuid;
  if p_data->>'status' is null or p_data->>'status' not in ('open','in_review','resolved','dismissed') or length(coalesce(p_data->>'note',''))>2000 then raise exception 'invalid_report_status';end if;
  update public.portal_reports r set status=p_data->>'status',staff_note=coalesce(p_data->>'note',''),updated_at=now() where r.id=id_ and r.track_id=track_ and (role_='admin' or r.user_id=p_actor or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=r.user_id and g.instructor_id=p_actor and g.track_id=track_));
  if not found then raise exception 'report_not_found';end if;
  data_:=jsonb_build_object('id',id_,'status',p_data->>'status');
 else raise exception 'invalid_action';end if;
 insert into public.audit_log(actor_id,action,target_type,target_id,meta) values(p_actor,p_action,split_part(p_action,'.',1),coalesce(id_::text,track_),jsonb_build_object('track',track_,'result',data_));
 return data_;
end $function$
;
revoke all on function public.daily_quiz_group(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.daily_quiz_group(uuid,text,uuid) to service_role;
revoke all on function public.daily_group_state(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.daily_group_state(uuid,text,uuid) to service_role;
revoke all on function public.daily_group_submit(uuid,text,jsonb,uuid,date) from public,anon,authenticated;
grant execute on function public.daily_group_submit(uuid,text,jsonb,uuid,date) to service_role;
revoke all on function public.daily_group_mark(uuid,text,text,uuid,date) from public,anon,authenticated;
grant execute on function public.daily_group_mark(uuid,text,text,uuid,date) to service_role;
revoke all on function public.daily_state(uuid,text) from public,anon,authenticated;
grant execute on function public.daily_state(uuid,text) to service_role;
revoke all on function public.daily_submit(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.daily_submit(uuid,text,jsonb) to service_role;
revoke all on function public.daily_mark(uuid,text,text) from public,anon,authenticated;
grant execute on function public.daily_mark(uuid,text,text) to service_role;
do $$begin if current_setting('portal.daily_rows_before') is distinct from coalesce((select md5(string_agg((to_jsonb(p)-'group_scope')::text,'|' order by user_id,track_id,day,quiz_group_id)) from public.daily_progress p),md5('')) then raise exception 'daily_history_changed'; end if;end$$;
notify pgrst,'reload schema';
commit;
