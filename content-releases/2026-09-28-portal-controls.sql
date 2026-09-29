begin;
create table if not exists public.portal_track_controls(
 track_id text primary key references public.tracks(id),
 revision_visible boolean not null default true,
 daily_mode text not null default 'random' check(daily_mode in ('random','lessons','selected')),
 daily_lessons text[] not null default '{}',
 daily_question_ids uuid[] not null default '{}',
 updated_at timestamptz not null default now()
);
insert into public.portal_track_controls(track_id) select id from public.tracks on conflict do nothing;
create table if not exists public.portal_reports(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 track_id text not null references public.tracks(id),
 request_id uuid not null,
 kind text not null check(kind in ('question','functionality')),
 question_id uuid references public.questions(id),
 screen text not null default '',
 message text not null check(length(message) between 10 and 3000),
 status text not null default 'open' check(status in ('open','in_review','resolved','dismissed')),
 staff_note text not null default '',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(user_id,request_id),
 check((kind='question')=(question_id is not null))
);
create index if not exists portal_reports_track_status_idx on public.portal_reports(track_id,status,created_at desc);
create index if not exists portal_reports_question_idx on public.portal_reports(question_id);
create table if not exists public.daily_reset_archive(
 id uuid primary key default gen_random_uuid(),
 actor_id uuid references public.profiles(id) on delete set null,
 user_id uuid references public.profiles(id) on delete set null,
 track_id text not null references public.tracks(id),
 reset_mode text not null,
 previous_progress jsonb not null,
 created_at timestamptz not null default now()
);
create index if not exists daily_reset_archive_actor_idx on public.daily_reset_archive(actor_id);
create index if not exists daily_reset_archive_user_idx on public.daily_reset_archive(user_id);
create index if not exists daily_reset_archive_track_idx on public.daily_reset_archive(track_id);
alter table public.portal_track_controls enable row level security;
alter table public.portal_reports enable row level security;
alter table public.daily_reset_archive enable row level security;
revoke all on public.portal_track_controls,public.portal_reports,public.daily_reset_archive from public,anon,authenticated;
grant all on public.portal_track_controls,public.portal_reports,public.daily_reset_archive to service_role;

create or replace function public.portal_student_controls(p_user uuid,p_action text,p_data jsonb default '{}')
returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare track_ text:=p_data->>'track'; role_ text; id_ uuid; request_ uuid; qid uuid;
begin
 select role into role_ from public.profiles where id=p_user and status='active';
 if role_ is null or not exists(select 1 from public.tracks where id=track_ and is_active) then raise exception 'forbidden';end if;
 if role_='student' and not public.is_enrolled(p_user,track_) then raise exception 'not_enrolled_in_track';end if;
 if role_='instructor' and not exists(select 1 from public.instructor_tracks where user_id=p_user and track_id=track_) then raise exception 'forbidden_track';end if;
 if p_action='settings' then
  return jsonb_build_object('track',track_,'revision_visible',track_ in ('sat','est','est2') and coalesce((select revision_visible from public.portal_track_controls where track_id=track_),false));
 end if;
 if p_action<>'report' then raise exception 'invalid_action';end if;
 request_:=(p_data->>'request_id')::uuid;
 if request_ is null then raise exception 'request_id_required';end if;
 select id into id_ from public.portal_reports where user_id=p_user and request_id=request_;
 if id_ is not null then return jsonb_build_object('id',id_,'status','received');end if;
 if p_data->>'kind' not in ('question','functionality') or p_data->>'kind' is null or length(btrim(coalesce(p_data->>'message',''))) not between 10 and 3000 then raise exception 'describe_report_10_to_3000_characters';end if;
 qid:=nullif(p_data->>'question_id','')::uuid;
 if (p_data->>'kind'='question')<>(qid is not null) then raise exception 'question_required';end if;
 if qid is not null and not exists(select 1 from public.questions q where q.id=qid and (q.track_id=track_ or (track_='sat' and exists(select 1 from public.revision_items r where r.question_id=q.id and r.programmes @> array[track_])))) then raise exception 'question_track_mismatch';end if;
 perform pg_advisory_xact_lock(hashtextextended('report:'||p_user::text,0));
 select id into id_ from public.portal_reports where user_id=p_user and request_id=request_;
 if id_ is not null then return jsonb_build_object('id',id_,'status','received');end if;
 if (select count(*) from public.portal_reports where user_id=p_user and created_at>now()-interval '1 hour')>=10 then raise exception 'report_limit_try_later';end if;
 insert into public.portal_reports(user_id,track_id,request_id,kind,question_id,screen,message)
 values(p_user,track_,request_,p_data->>'kind',qid,left(coalesce(p_data->>'screen',''),100),btrim(p_data->>'message'))
 on conflict(user_id,request_id) do update set request_id=excluded.request_id returning id into id_;
 return jsonb_build_object('id',id_,'status','received');
end $$;

create or replace function public.portal_manage(p_actor uuid,p_action text,p_data jsonb default '{}')
returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare role_ text; track_ text:=p_data->>'track'; id_ uuid; ids_ uuid[]; c public.portal_track_controls%rowtype; data_ jsonb; n int; student_ uuid; mode_ text; day_ date; before_ jsonb; report_ public.portal_reports%rowtype;
begin
 select role into role_ from public.profiles where id=p_actor and status='active';
 if role_ is null or role_ not in ('admin','instructor') then raise exception 'staff_required';end if;
 if track_ is null or not exists(select 1 from public.tracks where id=track_ and is_active) then raise exception 'choose_track';end if;
 if role_='instructor' and not exists(select 1 from public.instructor_tracks where user_id=p_actor and track_id=track_) then raise exception 'forbidden_track';end if;
 select * into c from public.portal_track_controls where track_id=track_;
 if p_action='revision.list' then
  select coalesce(jsonb_agg(jsonb_build_object('id',r.question_id,'lesson',r.lesson,'idea',r.idea,'difficulty',r.difficulty,'active',r.active,'source',coalesce(q.assets->>'source_code',q.assets->>'code',''),'stem',q.stem,'ready',r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation) and nullif(q.assets->>'release_hold_reason','') is null) order by r.lesson,r.idea,r.question_id),'[]') into data_
  from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where q.track_id=track_;
  return jsonb_build_object('visible',c.revision_visible,'items',data_);
 elsif p_action='quiz.list' then
  return jsonb_build_object('settings',to_jsonb(c),'today_frozen',exists(select 1 from public.daily_progress where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date),
   'today',(select jsonb_build_object('day',day,'question_ids',question_ids) from public.daily_quizzes where track_id=track_ and day=(now() at time zone 'Africa/Cairo')::date),
   'questions',(select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'lesson',q.topic,'stem',q.stem,'source',coalesce(q.assets->>'source_code',q.assets->>'code','')) order by q.topic,q.id),'[]') from public.questions q join public.question_keys k on k.question_id=q.id where q.track_id=track_ and q.type='mcq' and nullif(q.assets->>'verified_release','') is not null and nullif(q.assets->>'release_hold_reason','') is null and length(btrim(k.explanation))>0 and jsonb_array_length(q.choices)>=4 and jsonb_typeof(k.correct)='string' and exists(select 1 from jsonb_array_elements(q.choices) ch where ch->>'key'=k.correct#>>'{}')),
   'students',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.full_name,'completed',coalesce(d.completed,0),'points',coalesce(d.points,0)) order by p.full_name),'[]') from public.profiles p join public.enrollments e on e.user_id=p.id and e.track_id=track_ left join lateral(select count(quiz_completed_at) completed,sum(points) points from public.daily_progress dp where dp.user_id=p.id and dp.track_id=track_) d on true where p.role='student' and (role_='admin' or exists(select 1 from public.groups g join public.group_members gm on gm.group_id=g.id where gm.user_id=p.id and g.instructor_id=p_actor and g.track_id=track_))));
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
  perform pg_advisory_xact_lock(hashtextextended('daily:'||track_||':'||(now() at time zone 'Africa/Cairo')::date::text,0));
  perform 1 from public.daily_progress where user_id=student_ and track_id=track_ and (day_ is null or day=day_) for update;
  select coalesce(jsonb_agg(to_jsonb(dp)),'[]') into before_ from public.daily_progress dp where user_id=student_ and track_id=track_ and (day_ is null or day=day_);
  insert into public.daily_reset_archive(actor_id,user_id,track_id,reset_mode,previous_progress) values(p_actor,student_,track_,mode_,before_) returning id into id_;
  if mode_='all' then delete from public.daily_progress where user_id=student_ and track_id=track_ and (day_ is null or day=day_);
  else update public.daily_progress set quiz_completed_at=null,quiz_score=null,answers='{}',points=0,bonus_awarded=false where user_id=student_ and track_id=track_ and (day_ is null or day=day_);end if;
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
end $$;
revoke all on function public.portal_manage(uuid,text,jsonb),public.portal_student_controls(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.portal_manage(uuid,text,jsonb),public.portal_student_controls(uuid,text,jsonb) to service_role;
alter table public.revision_items drop constraint revision_items_programmes_check;
alter table public.revision_items add constraint revision_items_programmes_check check(cardinality(programmes)>0 and programmes <@ array['sat','est','est2']::text[]);
CREATE OR REPLACE FUNCTION public.daily_state(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  d date := (now() at time zone 'Africa/Cairo')::date;
  qids uuid[];
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
      and e.track_id=p_track and e.status='active' and t.is_active
  ) then raise exception 'not_enrolled_in_track'; end if;

  perform pg_advisory_xact_lock(hashtextextended('daily:'||p_track||':'||d::text,0));
  select question_ids into qids from public.daily_quizzes where track_id=p_track and day=d;
  if qids is null then
  select array(
    select q.id from public.questions q join public.question_keys k on k.question_id=q.id
    where q.track_id=p_track and q.type='mcq'
      and nullif(q.assets->>'verified_release','') is not null
      and nullif(q.assets->>'release_hold_reason','') is null
      and length(btrim(k.explanation))>0
      and jsonb_array_length(q.choices)>=4
      and jsonb_typeof(k.correct)='string'
      and exists(select 1 from jsonb_array_elements(q.choices) ch where ch->>'key'=k.correct#>>'{}')
      and exists(select 1 from public.portal_track_controls c where c.track_id=p_track and
       (c.daily_mode='random' or (c.daily_mode='lessons' and q.topic=any(c.daily_lessons)) or (c.daily_mode='selected' and q.id=any(c.daily_question_ids))))
    order by md5(d::text || q.id::text) limit 5
  ) into qids;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;
  insert into public.daily_quizzes(track_id,day,question_ids) values(p_track,d,qids);
  end if;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;

  insert into public.daily_progress(user_id,track_id,day) values(p_user,p_track,d)
  on conflict (user_id,track_id,day) do nothing;
  select * into progress_ from public.daily_progress
  where user_id=p_user and track_id=p_track and day=d;

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
    left join public.daily_progress dp on dp.user_id=e.user_id and dp.track_id=e.track_id
    where e.track_id=p_track and e.status='active' and p.status='active' and p.role='student'
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
    from public.daily_progress where user_id=p_user and track_id=p_track
      and quiz_completed_at is not null and day<=d
  ), runs as (
    select count(*)::int as length,max(day) as last_day from days group by island
  ) select coalesce(max(length) filter(where last_day>=d-1),0),
      coalesce(max(length),0) into current_,best_ from runs;
  select jsonb_agg(jsonb_build_object('date',d-offset_,
    'completed',exists(select 1 from public.daily_progress p where p.user_id=p_user
      and p.track_id=p_track and p.day=d-offset_ and p.quiz_completed_at is not null),
    'today',offset_=0) order by offset_ desc) into week_ from generate_series(0,6) offset_;

  return jsonb_build_object('date',d,'reset_at',((d+1)::timestamp at time zone 'Africa/Cairo'),
    'server_now',now(),'streak',jsonb_build_object('current',current_,'longest',best_,'week',week_),
    'selection_mode',(select daily_mode from public.portal_track_controls where track_id=p_track),'track',p_track,'quiz',quiz_,'score',progress_.quiz_score,
    'completed',progress_.quiz_completed_at is not null,
    'checklist',jsonb_build_object('quiz',progress_.quiz_completed_at is not null,
      'focus',progress_.focus_done,'review',progress_.review_done,
      'bonus',progress_.bonus_awarded),
    'points_today',progress_.points,'points_total',coalesce(mytotal_,0),
    'rank',myrank_,'leaderboard',leaders_);
end;
$function$
;
revoke all on function public.daily_state(uuid,text) from public,anon,authenticated;
grant execute on function public.daily_state(uuid,text) to service_role;

create or replace function public.final_revision_state(p_user uuid,p_track text,p_session uuid)
returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare s public.revision_sessions%rowtype; qs jsonb;
begin
 if p_track not in ('sat','est','est2') or not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
 if not exists(select 1 from public.portal_track_controls where track_id=p_track and revision_visible) then raise exception 'revision_hidden';end if;
 select * into s from public.revision_sessions where id=p_session and user_id=p_user and access_track=p_track;
 if not found then raise exception 'revision_session_not_found'; end if;
 select jsonb_agg(((q - 'correct' - 'explanation' - 'fingerprint') #- '{focus,takeaway}') || jsonb_build_object(
  'response',s.answers->(q->>'id'),
  'feedback',case when s.answers ? (q->>'id') then jsonb_build_object(
   'correct',public.answer_matches(q->>'type',s.answers->(q->>'id'),q->'correct'),
   'answer',q->'correct','explanation',q->>'explanation','takeaway',q#>>'{focus,takeaway}') else null end) order by n)
 into qs from jsonb_array_elements(s.snapshot) with ordinality e(q,n) where q->>'source'=p_track or (p_track='sat' and q->>'source'='est');
 if qs is null then raise exception 'revision_session_not_found'; end if;
 return jsonb_build_object('id',s.id,'lesson',s.lesson,'collection',s.collection,'questions',qs,'completed',not exists(select 1 from jsonb_array_elements(qs) q where q->'feedback'='null'::jsonb));
end $$;

create or replace function public.final_revision(p_user uuid,p_track text,p_action text,p_options jsonb default '{}')
returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare
 items jsonb; candidates jsonb; picked jsonb:='[]'; chosen jsonb; seen jsonb;
 s public.revision_sessions%rowtype; sid uuid; qid text; response text;
 scope_ text:=coalesce(p_options->>'scope',p_track);
 source_ text:=coalesce(p_options->>'source','both');
 collection_ text:=coalesce(p_options->>'collection','all');
 level_ text:=coalesce(p_options->>'difficulty','mixed');
 lesson_ text:=coalesce(p_options->>'lesson','');
 total_ int; n int; easy_ int; medium_ int; need_ text; retry_ uuid;
begin
 if p_track not in ('sat','est','est2') or not public.is_enrolled(p_user,p_track)
  or not exists(select 1 from public.profiles where id=p_user and role='student' and status='active')
 then raise exception 'not_enrolled_in_track'; end if;
 if not exists(select 1 from public.portal_track_controls where track_id=p_track and revision_visible) then raise exception 'revision_hidden';end if;
 if p_track in ('est','est2') then scope_:=p_track;source_:=p_track;end if;
 if p_action='state' then return public.final_revision_state(p_user,p_track,(p_options->>'session')::uuid); end if;
 if p_action='answer' then
  select * into s from public.revision_sessions where id=(p_options->>'session')::uuid and user_id=p_user and access_track=p_track for update;
  if not found then raise exception 'revision_session_not_found'; end if;
  qid:=p_options->>'question'; response:=btrim(p_options->>'answer');
  select q into chosen from jsonb_array_elements(s.snapshot) q where q->>'id'=qid and (q->>'source'=p_track or (p_track='sat' and q->>'source'='est'));
  if chosen is null or response is null or length(response) not between 1 and 250
    or jsonb_typeof(p_options->'answer') is distinct from 'string'
    or (chosen->>'type'='mcq' and not exists(select 1 from jsonb_array_elements(chosen->'choices') c where c->>'key'=response))
  then raise exception 'invalid_answer'; end if;
  -- A checked answer is immutable. Network retries return the first result.
  if not s.answers ? qid then
   s.answers:=s.answers||jsonb_build_object(qid,response);
   update public.revision_sessions set answers=s.answers,
    completed_at=case when not exists(select 1 from jsonb_array_elements(s.snapshot) q where (q->>'source'=p_track or (p_track='sat' and q->>'source'='est')) and not s.answers ? (q->>'id')) then now() else null end
    where id=s.id;
  end if;
  return public.final_revision_state(p_user,p_track,s.id);
 end if;
 if p_action not in ('catalogue','start') then raise exception 'invalid_action'; end if;
 -- Hide source edits until reviewed again; holds also take effect immediately.
 select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'lesson',r.lesson,'idea',r.idea,
  'difficulty',r.difficulty,'focus',r.focus,'programmes',r.programmes,'source',q.track_id,
  'stem',q.stem,'type',q.type,'choices',q.choices,
  'assets',(select coalesce(jsonb_object_agg(a.key,a.value),'{}') from jsonb_each(coalesce(q.assets,'{}')) a
     where a.key=any(array['figure','figure_caption','figspec','html','svg','image','image_alt','source_code','source_document','source_question','instructions','reference'])),
  'correct',k.correct,'explanation',k.explanation)),'[]') into candidates
 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
 where r.active and (q.track_id=p_track or (p_track='sat' and q.track_id='est')) and jsonb_typeof(k.correct) in ('string','array') and nullif(q.assets->>'release_hold_reason','') is null
 and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation);
 select coalesce(jsonb_object_agg(a.key,true),'{}') into seen
 from (select distinct a.key from public.revision_sessions rs cross join lateral jsonb_each(rs.answers) a
       where rs.user_id=p_user) a;
 if p_action='catalogue' then
  select coalesce(jsonb_agg(((q-'stem'-'type'-'choices'-'assets'-'correct'-'explanation') #- '{focus,takeaway}')||jsonb_build_object('practised',seen ? (q->>'id'))),'[]') into items from jsonb_array_elements(candidates) q;
  select id into sid from public.revision_sessions where user_id=p_user and access_track=p_track and completed_at is null and exists(select 1 from jsonb_array_elements(snapshot) q where (q->>'source'=p_track or (p_track='sat' and q->>'source'='est')) and not answers ? (q->>'id')) order by created_at desc limit 1;
  return jsonb_build_object('items',items,'session',case when sid is not null then public.final_revision_state(p_user,p_track,sid) else null end);
 end if;
 if collection_ not in ('all','priority','must_know','repeated','unique') or scope_ not in ('sat','est','est2','both') or source_ not in ('sat','est','est2','both') or level_ not in ('easy','medium','hard','mixed')
   or coalesce(p_options->>'count','10') not in ('10','20') then raise exception 'invalid_revision_filter'; end if;
 total_:=coalesce(p_options->>'count','10')::int;
 retry_:=(p_options->>'retry')::uuid;
 if retry_ is not null then
  select * into s from public.revision_sessions where id=retry_ and user_id=p_user and access_track=p_track and not exists(select 1 from jsonb_array_elements(snapshot) q where (q->>'source'=p_track or (p_track='sat' and q->>'source'='est')) and not answers ? (q->>'id'));
  if not found then raise exception 'revision_session_not_found'; end if;
  select coalesce(jsonb_agg(q),'[]') into candidates from jsonb_array_elements(candidates) q
  where exists(select 1 from jsonb_array_elements(s.snapshot) old where old->>'id'=q->>'id'
   and not public.answer_matches(old->>'type',s.answers->(old->>'id'),old->'correct'));
  lesson_:='Retry mistakes';level_:='mixed';collection_:='all';
 else
  select coalesce(jsonb_agg(q),'[]') into candidates from jsonb_array_elements(candidates) q
  where (scope_='both' or q->'programmes' ? scope_) and (source_='both' or q->>'source'=source_)
    and (level_='mixed' or q->>'difficulty'=level_) and (lesson_='' or q->>'lesson'=lesson_)
    and (collection_='all' or (collection_='priority' and jsonb_array_length(coalesce(q#>'{focus,collections}','[]'))>0) or (q#>'{focus,collections}') ? collection_);
 end if;
 total_:=least(total_,jsonb_array_length(candidates));
 if collection_<>'all' then
  select count(distinct (q->>'lesson',q->>'idea')) into n from jsonb_array_elements(candidates) q;
  total_:=least(total_,n);
 end if;
 if total_=0 then raise exception 'no_revision_questions'; end if;
 easy_:=round(total_*0.3);medium_:=round(total_*0.4);
 for n in 1..total_ loop
  need_:=case when n<=easy_ then 'easy' when n<=easy_+medium_ then 'medium' else 'hard' end;
  select q into chosen from jsonb_array_elements(candidates) q
   where not exists(select 1 from jsonb_array_elements(picked) p where p->>'id'=q->>'id')
    and (collection_='all' or not exists(select 1 from jsonb_array_elements(picked) p where p->>'lesson'=q->>'lesson' and p->>'idea'=q->>'idea'))
   order by case when level_='mixed' and q->>'difficulty'=need_ then 0 else 1 end,
    (select count(*) from jsonb_array_elements(picked) p where p->>'lesson'=q->>'lesson'),
    (select count(*) from jsonb_array_elements(picked) p where p->>'idea'=q->>'idea'),
    case when seen ? (q->>'id') then 1 else 0 end,
    (select count(*) from jsonb_array_elements(picked) p where p->>'source'=q->>'source'),random() limit 1;
  picked:=picked||jsonb_build_array(chosen);
 end loop;
 -- Mix the chosen levels so the answer position never hints at difficulty.
 select jsonb_agg(q order by random()) into picked from jsonb_array_elements(picked) q;
 insert into public.revision_sessions(user_id,access_track,lesson,collection,snapshot) values(p_user,p_track,lesson_,collection_,picked) returning id into sid;
 return public.final_revision_state(p_user,p_track,sid);
end $$;
revoke all on function public.final_revision(uuid,text,text,jsonb),public.final_revision_state(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.final_revision(uuid,text,text,jsonb),public.final_revision_state(uuid,text,uuid) to service_role;

commit;
