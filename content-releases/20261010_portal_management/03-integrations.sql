begin;
do $guard$ begin
if md5(pg_get_functiondef('public.daily_state(uuid,text)'::regprocedure))<>'e048a5f94884add3c06c24ab4deddaa8' then raise exception 'management preflight: daily_state changed; refresh release';end if;
if md5(pg_get_functiondef('public.daily_submit(uuid,text,jsonb)'::regprocedure))<>'d8ab4aaa2af0e63e61aefceb575cf0cf' then raise exception 'management preflight: daily_submit changed; refresh release';end if;
if md5(pg_get_functiondef('public.final_revision(uuid,text,text,jsonb)'::regprocedure))<>'9152fe78ea9ba38bdd6618f2975b4e96' then raise exception 'management preflight: final_revision changed; refresh release';end if;
if md5(pg_get_functiondef('public.practice_drill_start(uuid,text)'::regprocedure))<>'3a411026c7262e2b550759744bdfa3fd' then raise exception 'management preflight: practice_drill_start changed; refresh release';end if;
if md5(pg_get_functiondef('public.new_exam(text,text,integer,integer,text,boolean,boolean,text,boolean)'::regprocedure))<>'bb2429c0407b46076a16d43c1fdb3722' then raise exception 'management preflight: new_exam changed; refresh release';end if;
if md5(pg_get_functiondef('public.student_daily_quiz_mistakes(uuid,text)'::regprocedure))<>'c4e60eaf91dce3c13f9a02afa89a7ffc' then raise exception 'management preflight: student_daily_quiz_mistakes changed; refresh release';end if;
if md5(pg_get_functiondef('public.my_exams(uuid,text)'::regprocedure))<>'22a7814cad3f359fc4cfcbcfc96f8131' then raise exception 'management preflight: my_exams changed; refresh release';end if;
if md5(pg_get_functiondef('public.portal_push_collect()'::regprocedure))<>'e9a41529ec2f7106831c1b65104e449f' then raise exception 'management preflight: portal_push_collect changed; refresh release';end if;
if md5(pg_get_functiondef('public.portal_push_announce(uuid,uuid,text,text,text)'::regprocedure))<>'368b2caf8c125ce8a10198c509191924' then raise exception 'management preflight: portal_push_announce changed; refresh release';end if;
end $guard$;
CREATE OR REPLACE FUNCTION public.daily_state(p_user uuid, p_track text)
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

  perform pg_advisory_xact_lock(hashtextextended('daily-user:'||p_user::text||':'||p_track||':'||d::text,0));
  select * into progress_ from public.daily_progress where user_id=p_user and track_id=p_track and day=d;
  existing_progress:=found;
  if existing_progress then gid:=progress_.quiz_group_id;
  else select g.id into gid from public.groups g join public.group_members gm on gm.group_id=g.id
   where gm.user_id=p_user and g.track_id=p_track and g.instructor_id is not null
   and (g.course_starts_on is null or g.course_starts_on<=(now() at time zone 'Africa/Cairo')::date)
   and (g.course_ends_on is null or g.course_ends_on>=(now() at time zone 'Africa/Cairo')::date)
   order by g.created_at desc,g.id limit 1;end if;
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
    order by md5(d::text || q.id::text) limit 5
  ) into qids;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;
  if gid is null then insert into public.daily_quizzes(track_id,day,question_ids) values(p_track,d,qids);
  else insert into public.daily_group_quizzes(group_id,day,question_ids) values(gid,d,qids);end if;
  end if;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;

  insert into public.daily_progress(user_id,track_id,day,quiz_group_id) values(p_user,p_track,d,gid)
  on conflict (user_id,track_id,day) do nothing;
  select * into progress_ from public.daily_progress
  where user_id=p_user and track_id=p_track and day=d;

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
    left join public.daily_progress dp on dp.user_id=e.user_id and dp.track_id=e.track_id
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
    from public.daily_progress where user_id=p_user and track_id=p_track
      and quiz_completed_at is not null and day<=d
  ), runs as (
    select count(*)::int as length,max(day) as last_day from days group by island
  ) select coalesce(max(length) filter(where last_day>=d-1),0),
      coalesce(max(length),0) into current_,best_ from runs;
  if progress_.quiz_completed_at is null and (select count(*) from public.questions q join public.question_keys k on k.question_id=q.id where q.id=any(qids) and portal_private.question_eligible(q,k,p_track,true))<>5 then raise exception 'daily_content_under_review'; end if;

  select jsonb_agg(jsonb_build_object('date',d-offset_,
    'completed',exists(select 1 from public.daily_progress p where p.user_id=p_user
      and p.track_id=p_track and p.day=d-offset_ and p.quiz_completed_at is not null),
    'today',offset_=0) order by offset_ desc) into week_ from generate_series(0,6) offset_;

  return jsonb_build_object('date',d,'reset_at',((d+1)::timestamp at time zone 'Africa/Cairo'),
    'server_now',now(),'streak',jsonb_build_object('current',current_,'longest',best_,'week',week_),
    'group_id',gid,'group_name',(select name from public.groups where id=gid),'selection_mode',case when gid is not null and exists(select 1 from public.groups where id=gid and cardinality(daily_lessons)>0) then 'group lessons' else (select daily_mode from public.portal_track_controls where track_id=p_track) end,'track',p_track,'quiz',quiz_,'score',progress_.quiz_score,
    'completed',progress_.quiz_completed_at is not null,
    'checklist',jsonb_build_object('quiz',progress_.quiz_completed_at is not null,
      'focus',progress_.focus_done,'review',progress_.review_done,
      'bonus',progress_.bonus_awarded),
    'points_today',progress_.points,'points_total',coalesce(mytotal_,0),
    'rank',myrank_,'leaderboard',leaders_);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.daily_submit(p_user uuid, p_track text, p_answers jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  d date := (now() at time zone 'Africa/Cairo')::date;
  progress_ public.daily_progress%rowtype;
  qids uuid[];
  correct_ integer;
  streak_ integer;
begin
  -- Call daily_state first to validate enrollment and create today's frozen quiz.
  perform public.daily_state(p_user,p_track);
  if jsonb_typeof(p_answers) is distinct from 'object' or
    (select count(*) from jsonb_object_keys(p_answers))<>5 then
    raise exception 'invalid_answers'; end if;
  select * into progress_ from public.daily_progress where user_id=p_user and track_id=p_track and day=d for update;
  if progress_.quiz_group_id is null then select question_ids into qids from public.daily_quizzes where track_id=p_track and day=d;
  else select question_ids into qids from public.daily_group_quizzes where group_id=progress_.quiz_group_id and day=d;end if;
  if exists(select 1 from jsonb_object_keys(p_answers) key where not key=any(select unnest(qids)::text))
  then raise exception 'invalid_answers'; end if;
  if exists(select 1 from unnest(qids) qid join public.questions q on q.id=qid
    where not exists(select 1 from jsonb_array_elements(q.choices) choice
      where p_answers->q.id::text=to_jsonb(choice->>'key')))
  then raise exception 'invalid_answers'; end if;
  select * into progress_ from public.daily_progress
   where user_id=p_user and track_id=p_track and day=d for update;
  if progress_.quiz_completed_at is not null then return public.daily_state(p_user,p_track); end if;
  select count(*)::integer into correct_
  from unnest(qids) qid join public.questions q on q.id=qid
  join public.question_keys k on k.question_id=q.id
  where public.answer_matches(q.type,p_answers->q.id::text,k.correct);
  select case when exists(select 1 from public.daily_progress
    where user_id=p_user and track_id=p_track and day=d-1 and quiz_completed_at is not null)
    then 5 else 0 end into streak_;
  update public.daily_progress set quiz_completed_at=now(),quiz_score=correct_,answers=p_answers,
    points=points + 10 + 10*correct_ + streak_
      + case when focus_done and review_done and not bonus_awarded then 5 else 0 end,
    bonus_awarded=bonus_awarded or (focus_done and review_done)
  where user_id=p_user and track_id=p_track and day=d;
  return public.daily_state(p_user,p_track);
end $function$
;

CREATE OR REPLACE FUNCTION public.final_revision(p_user uuid, p_track text, p_action text, p_options jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  'type',q.type)),'[]') into candidates
 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
 where r.active and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve) and portal_private.question_eligible(q,k,q.track_id,false) and (q.track_id=p_track or (p_track='sat' and q.track_id='est')) and jsonb_typeof(k.correct) in ('string','array') and nullif(q.assets->>'release_hold_reason','') is null
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
 -- Hydrate only the selected questions. Catalogue and candidate selection do not build image payloads.
 select coalesce(jsonb_agg(p.item || jsonb_build_object('stem',q.stem,'choices',q.choices,
  'assets',(select coalesce(jsonb_object_agg(a.key,a.value),'{}') from jsonb_each(coalesce(q.assets,'{}')) a
    where a.key=any(array['figure','figure_caption','figspec','html','svg','image','image_alt','source_code','source_document','source_question','instructions','reference'])),
  'correct',k.correct,'explanation',k.explanation) order by p.n),'[]') into picked
 from jsonb_array_elements(picked) with ordinality p(item,n)
 join public.questions q on q.id=(p.item->>'id')::uuid
 join public.question_keys k on k.question_id=q.id
 join public.revision_items r on r.question_id=q.id
 where r.active and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve) and portal_private.question_eligible(q,k,q.track_id,false)
  and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation);
 if jsonb_array_length(picked)<>total_ then raise exception 'question_content_under_review'; end if;
 insert into public.revision_sessions(user_id,access_track,lesson,collection,snapshot) values(p_user,p_track,lesson_,collection_,picked) returning id into sid;
 return public.final_revision_state(p_user,p_track,sid);
end $function$
;

CREATE OR REPLACE FUNCTION public.practice_drill_start(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_topics text[]; v_ids uuid[]; v_id uuid;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  select id into v_id from public.practice_drills where user_id=p_user and track_id=p_track
    and completed_at is null and created_at>now()-interval '1 day'
    and portal_private.exam_content_ready(question_ids,p_track) order by created_at desc limit 1;
  if found then return public.practice_drill_state(p_user,p_track,v_id); end if;
  select array_agg(lesson) into v_topics from (
    select lesson from jsonb_to_recordset(public.student_dashboard(p_user,p_track)->'lessons')
      as l(lesson text,seen int,percent numeric)
    where seen>=3 order by percent asc nulls last,lesson limit 3
  ) ranked;
  if cardinality(v_topics) is null then raise exception 'not_enough_topic_history'; end if;
  select array_agg(id) into v_ids from (
    select q.id from public.questions q join public.question_keys k on k.question_id=q.id
    where q.track_id=p_track and q.topic=any(v_topics) and portal_private.question_eligible(q,k,p_track,false) and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve)
      and (nullif(q.assets->>'verified_release','') is not null or exists (
        select 1 from public.exams e where e.track_id=p_track and e.is_published and q.id=any(e.question_ids)))
      and nullif(q.assets->>'release_hold_reason','') is null
      and jsonb_typeof(k.correct) in ('string','array') and length(btrim(k.explanation))>0
    order by random() limit 18
  ) picked;
  if coalesce(cardinality(v_ids),0)<15 then raise exception 'not_enough_drill_questions'; end if;
  insert into public.practice_drills(user_id,track_id,topics,question_ids)
    values(p_user,p_track,v_topics,v_ids) returning id into v_id;
  return public.practice_drill_state(p_user,p_track,v_id);
end $function$
;

CREATE OR REPLACE FUNCTION public.new_exam(p_track text, p_title text, p_count integer DEFAULT 20, p_minutes integer DEFAULT 35, p_topic text DEFAULT NULL::text, p_publish boolean DEFAULT true, p_assign boolean DEFAULT true, p_if_exists text DEFAULT 'skip'::text, p_full_length boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare ids uuid[]; v_id uuid; n integer;
begin
  if not exists (select 1 from public.tracks where id = p_track) then
    raise exception 'unknown_track: %', p_track;
  end if;

  select id into v_id from public.exams
   where track_id = p_track and title = p_title order by created_at limit 1;
  if v_id is not null then
    if p_if_exists = 'error' then
      raise exception 'exam_already_exists: % / %', p_track, p_title;
    elsif p_if_exists <> 'duplicate' then
      raise notice 'exists, left alone: "%"', p_title;
      return v_id;
    end if;
  end if;

  select array_agg(q.id order by
           case q.difficulty when 'easy' then 1 when 'medium' then 2 else 3 end, q.id)
    into ids
    from (select q.id, q.difficulty from public.questions q join public.question_keys k on k.question_id=q.id
           where q.track_id = p_track and portal_private.question_eligible(q,k,p_track,false) and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve)
             and (p_topic is null or q.topic=p_topic)
           order by case q.difficulty when 'easy' then 1 when 'medium' then 2 else 3 end, q.id
           limit p_count) q;

  n := coalesce(array_length(ids, 1), 0);
  if n = 0 then
    raise exception 'no_questions_matched: track=% topic=%', p_track, coalesce(p_topic,'(any)');
  end if;

  insert into public.exams(track_id, title, duration_seconds, question_ids,
                           is_published, is_full_length)
  values (p_track, p_title, p_minutes * 60, ids, p_publish, p_full_length)
  returning id into v_id;

  if p_assign then
    insert into public.assignments(exam_id, group_id)
    values (v_id, public.default_group(p_track));
  end if;

  raise notice 'created "%": % question(s), % min, full_length=%', p_title, n, p_minutes, p_full_length;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.student_daily_quiz_mistakes(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  items_ jsonb;
begin
  if not exists (
    select 1
    from public.profiles p
    join public.enrollments e on e.user_id = p.id
    join public.tracks t on t.id = e.track_id
    where p.id = p_user
      and p.role = 'student'
      and p.status = 'active'
      and e.track_id = p_track
      and public.course_history_access(p_user,p_track)
  ) then
    raise exception 'not_enrolled_in_track';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'date', dp.day,
    'question_id', q.id,
    'topic', q.topic,
    'stem', q.stem,
    'choices', q.choices,
    'assets', q.assets,
    'submitted', dp.answers ->> q.id::text,
    'correct', k.correct,
    'explanation', k.explanation
  ) order by dp.day desc, q.id), '[]'::jsonb)
  into items_
  from public.daily_progress dp
  cross join lateral jsonb_object_keys(dp.answers) answer_key(question_id)
  join public.questions q on q.id = answer_key.question_id::uuid
  join public.question_keys k on k.question_id = q.id
  where dp.user_id = p_user
    and dp.track_id = p_track
    and dp.quiz_completed_at is not null
    and not public.answer_matches(q.type, dp.answers -> q.id::text, k.correct);

  return jsonb_build_object(
    'track', p_track,
    'count', jsonb_array_length(items_),
    'items', items_
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.my_exams(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', e.id, 'title', e.title, 'assessment_type', e.assessment_type, 'duration_seconds', e.duration_seconds,
           'questions', coalesce(array_length(e.question_ids,1), 0),
           'exam_set_code',e.exam_set_code,'module_number',e.module_number,'module_count',e.module_count,
           'content_ready',portal_private.exam_content_ready(e.question_ids,e.track_id),
           'open', public.student_assignment_for(e.id, p_user) is not null and portal_private.exam_content_ready(e.question_ids,e.track_id),
           'attempts', (select count(*) from public.attempts a where a.user_id=p_user and a.exam_id=e.id),
           'max_attempts', case when e.assessment_type='lesson_exam' then null else 1 end,
           'repeatable', e.assessment_type='lesson_exam',
           'allow_untimed', e.assessment_type='lesson_exam',
           'retake_available', public.is_enrolled(p_user,p_track) and (e.assessment_type='lesson_exam' or exists(select 1 from retake_grants g where g.user_id=p_user and g.exam_id=e.id and g.consumed_at is null and (g.expires_at is null or g.expires_at>now()))),
           'last', (select jsonb_build_object('id',a.id,'status',a.status,'untimed',a.deadline_at='infinity'::timestamptz,'score',a.score,'total',a.total,'scaled_score',a.scaled_score)
                      from public.attempts a where a.user_id=p_user and a.exam_id=e.id order by a.attempt_no desc limit 1)
         ) order by e.created_at), '[]'::jsonb)
    from public.exams e
   where e.track_id=p_track and e.is_published and (public.is_enrolled(p_user,p_track) or exists(select 1 from public.attempts a where a.exam_id=e.id and a.user_id=p_user and a.status='in_progress' and portal_private.attempt_course_access(a.id,p_user,false)))
     and exists (select 1 from public.assignments a where a.exam_id=e.id and
       (a.user_id=p_user or exists(select 1 from public.group_members gm where gm.group_id=a.group_id and gm.user_id=p_user)));
$function$
;

CREATE OR REPLACE FUNCTION public.portal_push_collect()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
 insert into portal_push_releases(exam_id) select id from exams where is_published on conflict do nothing;
 insert into portal_push_queue(subscription_id,event_key,kind,title,body,exam_id)
 select s.id,'exam:'||e.id,'exam','New practice is available',left(e.title,180),e.id
 from portal_push_subscriptions s join profiles p on p.id=s.user_id and p.status='active' and p.role='student'
 join enrollments en on en.user_id=s.user_id and public.is_enrolled(s.user_id,en.track_id)
 join exams e on e.track_id=en.track_id and e.is_published
 join portal_push_releases r on r.exam_id=e.id
 where s.exams and student_assignment_for(e.id,s.user_id) is not null
 and greatest(r.seen_at,coalesce((select max(greatest(a.created_at,a.open_at)) from assignments a where a.exam_id=e.id and (a.user_id=s.user_id or exists(select 1 from group_members gm where gm.group_id=a.group_id and gm.user_id=s.user_id))),r.seen_at))>=s.created_at
 and not exists(select 1 from attempts a where a.user_id=s.user_id and a.exam_id=e.id)
 on conflict do nothing;
 insert into portal_push_queue(subscription_id,event_key,kind,title,body,exam_id)
 select s.id,'result:'||a.id,'result','Your results are ready','Open the portal to view your results.',a.exam_id
 from portal_push_subscriptions s join profiles p on p.id=s.user_id and p.status='active'
 join attempts a on a.user_id=s.user_id join exams e on e.id=a.exam_id
 where s.results and a.status='graded' and a.submitted_at>=s.created_at
 and (a.review_unlocks_at is null or a.review_unlocks_at<=now())
 on conflict do nothing;
 -- Optional reminder, at 18:00 Cairo; one per device/day, never a backlog.
 if extract(hour from now() at time zone 'Africa/Cairo')=18 and extract(minute from now() at time zone 'Africa/Cairo')<10 then
 insert into portal_push_queue(subscription_id,event_key,kind,title,body)
 select s.id,'daily:'||(now() at time zone 'Africa/Cairo')::date,'reminder','Time for your daily practice','Open Ghoneem Math and complete your daily quiz.'
 from portal_push_subscriptions s join profiles p on p.id=s.user_id and p.status='active' and p.role='student'
 where s.reminders and exists(select 1 from enrollments e where e.user_id=s.user_id and is_enrolled(s.user_id,e.track_id))
 on conflict do nothing;
 end if;
 update portal_push_queue set status='failed',error='delivery_expired' where status in ('pending','sending') and created_at<now()-interval '24 hours';
end $function$
;

CREATE OR REPLACE FUNCTION public.portal_push_announce(p_actor uuid, p_id uuid, p_title text, p_body text, p_track text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare n int;
begin
 if not exists(select 1 from profiles where id=p_actor and role='admin' and status='active') then raise exception 'forbidden'; end if;
 if length(trim(p_title)) not between 1 and 80 or length(trim(p_body)) not between 1 and 240 then raise exception 'invalid_message'; end if;
 if exists(select 1 from portal_push_campaigns where id=p_id) then return (select count(*) from portal_push_queue where campaign_id=p_id); end if;
 if exists(select 1 from portal_push_campaigns where created_by=p_actor and created_at>now()-interval '30 seconds') then raise exception 'Please wait 30 seconds before another announcement'; end if;
 insert into portal_push_campaigns(id,created_by,title,body,track_id) values(p_id,p_actor,p_title,p_body,p_track);
 insert into portal_push_queue(subscription_id,event_key,kind,title,body,campaign_id)
 select s.id,'announcement:'||p_id,'announcement',p_title,p_body,p_id from portal_push_subscriptions s
 join profiles p on p.id=s.user_id and p.status='active' and p.role='student'
 where exists(select 1 from enrollments e where e.user_id=s.user_id and is_enrolled(s.user_id,e.track_id) and (p_track is null or e.track_id=p_track));
 get diagnostics n=row_count; return n;
end $function$
;
-- History SELECT never opens fresh practice or another student's rows.
alter policy attempts_read on public.attempts using(
 case when (select public.is_admin()) then true else
 ((user_id=auth.uid() and public.course_history_access(auth.uid(),public.exam_track(exam_id)))
 or (public.staff_can_touch_track(public.exam_track(exam_id)) and public.staff_can_read_student(user_id))) end);
alter policy tracks_read on public.tracks using(public.staff_can_touch_track(id) or public.course_history_access(auth.uid(),id));

commit;
