begin;
do $guard$ begin
 if md5(pg_get_functiondef(('public.new_exam(text,text,integer,integer,text,boolean,boolean,text,boolean)')::regprocedure)) <> '20289f818a88099312bd7eca90f78437' then raise exception 'Function changed since reviewed: new_exam(text,text,integer,integer,text,boolean,boolean,text,boolean)'; end if;
 if md5(pg_get_functiondef(('public.portal_start_attempt(uuid,uuid,boolean)')::regprocedure)) <> '9589d488896bbc11c2eb7ed47ada80b3' then raise exception 'Function changed since reviewed: portal_start_attempt(uuid,uuid,boolean)'; end if;
 if md5(pg_get_functiondef(('public.attempt_payload(uuid,uuid)')::regprocedure)) <> '4f2daaed7f160cf3571a465e27ab94f7' then raise exception 'Function changed since reviewed: attempt_payload(uuid,uuid)'; end if;
 if md5(pg_get_functiondef(('public.my_exams(uuid,text)')::regprocedure)) <> '8f179cd7eb535afea8222d0b00c61951' then raise exception 'Function changed since reviewed: my_exams(uuid,text)'; end if;
 if md5(pg_get_functiondef(('public.daily_state(uuid,text)')::regprocedure)) <> 'c0941cfb93e1fbd757bd09f82975e974' then raise exception 'Function changed since reviewed: daily_state(uuid,text)'; end if;
 if md5(pg_get_functiondef(('public.practice_notebook_state(uuid,text,integer)')::regprocedure)) <> 'ccc23832cf870afb72bb85e797858951' then raise exception 'Function changed since reviewed: practice_notebook_state(uuid,text,integer)'; end if;
 if md5(pg_get_functiondef(('public.practice_notebook_answer(uuid,text,uuid,text)')::regprocedure)) <> '29ef7d2e03822b834fc513880c276c33' then raise exception 'Function changed since reviewed: practice_notebook_answer(uuid,text,uuid,text)'; end if;
 if md5(pg_get_functiondef(('public.practice_drill_start(uuid,text)')::regprocedure)) <> 'f1613d8cd68965f67bfd3a67148a366d' then raise exception 'Function changed since reviewed: practice_drill_start(uuid,text)'; end if;
 if md5(pg_get_functiondef(('public.practice_drill_state(uuid,text,uuid)')::regprocedure)) <> 'e49476cfedbe065bd5575c918a3ab81e' then raise exception 'Function changed since reviewed: practice_drill_state(uuid,text,uuid)'; end if;
 if md5(pg_get_functiondef(('public.practice_drill_submit(uuid,text,uuid,jsonb)')::regprocedure)) <> '8d7960b3988c4d05fe82b087b8c7aa2e' then raise exception 'Function changed since reviewed: practice_drill_submit(uuid,text,uuid,jsonb)'; end if;
 if md5(pg_get_functiondef(('public.final_revision(uuid,text,text,jsonb)')::regprocedure)) <> 'e992a2ea7fcfc4a2cd78ecb9116ca9b4' then raise exception 'Function changed since reviewed: final_revision(uuid,text,text,jsonb)'; end if;
end $guard$;
-- A structural eligibility check, not mathematical certification.
create schema if not exists portal_private;
create or replace function portal_private.question_eligible(
 p_q public.questions,p_k public.question_keys,p_track text,p_daily boolean default false
) returns boolean language plpgsql immutable security invoker set search_path=public,pg_temp as $$
declare visual_ boolean; figures_ jsonb;
begin
 if p_q.id is null or p_q.track_id is distinct from p_track or p_k.question_id is distinct from p_q.id
  or nullif(btrim(p_q.stem),'') is null or nullif(btrim(p_k.explanation),'') is null
  or nullif(btrim(p_q.assets->>'release_hold_reason'),'') is not null
  or lower(coalesce(p_q.assets->>'bank_removed','false'))='true'
  or coalesce(p_k.correct->>'void','false')='true'
 then return false; end if;
 figures_:=case jsonb_typeof(p_q.assets->'figure') when 'array' then p_q.assets->'figure'
  when 'string' then jsonb_build_array(p_q.assets->'figure') else '[]'::jsonb end;
 visual_:=exists(select 1 from jsonb_array_elements_text(figures_) f where
  f ~ '^https://' or f ~ '^data:image/(png|jpeg|jpg|webp|gif|svg\+xml);base64,[A-Za-z0-9+/=[:space:]]+$')
  or coalesce(p_q.assets->>'image','') ~ '^https://'
  or nullif(btrim(p_q.assets->>'svg'),'') is not null
  or nullif(btrim(p_q.assets->>'html'),'') is not null
  or (jsonb_typeof(p_q.assets->'figspec')='object' and p_q.assets->'figspec'<>'{}'::jsonb);
 visual_:=coalesce(visual_,false);
 if lower(coalesce(p_q.assets->>'figure_required','false'))='true' and not visual_ then return false; end if;
 if p_q.type='mcq' then
  if jsonb_typeof(p_q.choices) is distinct from 'array' then return false; end if;
  if jsonb_array_length(p_q.choices) not between 2 and 8
   or exists(select 1 from jsonb_array_elements(p_q.choices) c where nullif(btrim(c->>'key'),'') is null)
   or (select count(distinct c->>'key') from jsonb_array_elements(p_q.choices) c)<>jsonb_array_length(p_q.choices)
  then return false; end if;
  if jsonb_typeof(p_k.correct)='string' then
   if not exists(select 1 from jsonb_array_elements(p_q.choices) c where c->>'key'=p_k.correct#>>'{}') then return false; end if;
  elsif jsonb_typeof(p_k.correct)='array' then
   if jsonb_array_length(p_k.correct)=0 or exists(select 1 from jsonb_array_elements(p_k.correct) a
    where jsonb_typeof(a)<>'string' or not exists(select 1 from jsonb_array_elements(p_q.choices) c where c->>'key'=a#>>'{}')) then return false; end if;
  else return false; end if;
  if not visual_ and exists(select 1 from jsonb_array_elements(p_q.choices) c where
   nullif(btrim(c->>'text'),'') is null or c->>'text' ilike '%in the original question%') then return false; end if;
 elsif p_q.type='grid_in' then
  if jsonb_typeof(p_k.correct) in ('string','number') then
   if nullif(btrim(p_k.correct#>>'{}'),'') is null then return false; end if;
  elsif jsonb_typeof(p_k.correct)='array' then
   if jsonb_array_length(p_k.correct)=0 or exists(select 1 from jsonb_array_elements(p_k.correct) a
    where jsonb_typeof(a) not in ('string','number') or nullif(btrim(a#>>'{}'),'') is null) then return false; end if;
  else return false; end if;
 else return false; end if;
 if p_daily then
  if p_q.type<>'mcq' or jsonb_typeof(p_k.correct)<>'string' or jsonb_array_length(p_q.choices)<4
   or nullif(p_q.assets->>'verified_release','') is null
   or exists(select 1 from jsonb_array_elements(p_q.choices) c where nullif(btrim(c->>'text'),'') is null
    or c->>'text' ilike '%in the original question%') then return false; end if;
 end if;
 return true;
end $$;
revoke all on function portal_private.question_eligible(public.questions,public.question_keys,text,boolean) from public,anon,authenticated;
grant usage on schema portal_private to service_role;
grant execute on function portal_private.question_eligible(public.questions,public.question_keys,text,boolean) to service_role;

create or replace function portal_private.exam_content_ready(p_ids uuid[],p_track text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(cardinality(p_ids),0) between 1 and 200
 and (select count(distinct id) from unnest(p_ids) id)=cardinality(p_ids)
 and (select count(*) from questions q join question_keys k on k.question_id=q.id
  where q.id=any(p_ids) and portal_private.question_eligible(q,k,p_track,false))=cardinality(p_ids)
$$;
revoke all on function portal_private.exam_content_ready(uuid[],text) from public,anon,authenticated;
grant execute on function portal_private.exam_content_ready(uuid[],text) to service_role;

create or replace function portal_private.guard_exam_content() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.is_published and not portal_private.exam_content_ready(new.question_ids,new.track_id)
 then raise exception 'exam_content_under_review'; end if;
 return new;
end $$;
revoke all on function portal_private.guard_exam_content() from public,anon,authenticated;
drop trigger if exists guard_published_exam_content on public.exams;
create trigger guard_published_exam_content before insert or update of question_ids,track_id,is_published
 on public.exams for each row execute function portal_private.guard_exam_content();

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
           where q.track_id = p_track and portal_private.question_eligible(q,k,p_track,false)
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
CREATE OR REPLACE FUNCTION public.portal_start_attempt(p_exam uuid, p_user uuid, p_untimed boolean DEFAULT false)
 RETURNS attempts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_exam        public.exams%rowtype;
  v_attempt     public.attempts%rowtype;
  v_assignment  uuid;
  v_used        integer;
  v_limit       integer;
  v_grant       uuid;
  v_duration    integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text||p_exam::text,0));
  if not exists(select 1 from profiles where id=p_user and role='student' and status='active') then raise exception 'student_account_required'; end if;
  select * into v_exam from public.exams where id = p_exam;
  if not found then
    raise exception 'exam_not_found';
  end if;
  if not v_exam.is_published then
    raise exception 'exam_not_published';
  end if;

  if p_untimed and v_exam.assessment_type <> 'lesson_exam' then
    raise exception 'untimed_lessons_only';
  end if;

  -- SAT/EST isolation. The track comes from the exam, never from the client.
  if not public.is_enrolled(p_user, v_exam.track_id) then
    raise exception 'not_enrolled_in_track';
  end if;

  if (select status from public.profiles where id = p_user) <> 'active' then
    raise exception 'account_suspended';
  end if;

  -- Finalise this student's own stale attempt on this exam before anything
  -- else, so an abandoned session never blocks the partial unique index.
  perform public.finalize_expired_for(p_user, p_exam);

  if not portal_private.exam_content_ready(v_exam.question_ids,v_exam.track_id) then raise exception 'exam_content_under_review'; end if;

  -- Resume a live attempt rather than creating a second one.
  select * into v_attempt from public.attempts
   where user_id = p_user and exam_id = p_exam and status = 'in_progress';
  if found then
    return v_attempt;
  end if;

  v_assignment := public.student_assignment_for(p_exam, p_user);
  if v_assignment is null then
    raise exception 'not_assigned_or_window_closed';
  end if;

  select count(*) into v_used from public.attempts
   where user_id = p_user and exam_id = p_exam;
  v_limit := 1;

  if v_used >= v_limit and v_exam.assessment_type <> 'lesson_exam' then
    select id into v_grant from public.retake_grants
     where user_id = p_user and exam_id = p_exam
       and consumed_at is null
       and (expires_at is null or expires_at > now())
     order by granted_at limit 1 for update;
    if v_grant is null then
      raise exception 'attempt_limit_reached';
    end if;
    update public.retake_grants set consumed_at = now() where id = v_grant;
    insert into public.audit_log(actor_id, action, target_type, target_id, meta)
    values (p_user, 'retake.consumed', 'exam', p_exam::text,
            jsonb_build_object('grant_id', v_grant));
  end if;

  v_duration := coalesce(nullif(v_exam.duration_seconds, 0),
                         (select default_duration_seconds from public.tracks where id = v_exam.track_id));

  insert into public.attempts(user_id, exam_id, assignment_id, attempt_no,
                              shuffle_seed, deadline_at, total)
  values (p_user, p_exam, v_assignment, v_used + 1,
          (floor(random() * 2147483646) + 1)::bigint,
          case when p_untimed then 'infinity'::timestamptz else now() + make_interval(secs => v_duration) end,
          coalesce(array_length(v_exam.question_ids, 1), 0))
  returning * into v_attempt;

  insert into public.audit_log(actor_id, action, target_type, target_id, meta)
  values (p_user, 'attempt.started', 'attempt', v_attempt.id::text,
          jsonb_build_object('exam_id', p_exam, 'attempt_no', v_attempt.attempt_no));

  return v_attempt;

exception when unique_violation then
  -- Two starts raced. The index kept one; return the survivor.
  select * into v_attempt from public.attempts
   where user_id = p_user and exam_id = p_exam and status = 'in_progress';
  if found then return v_attempt; end if;
  raise;
end $function$

;
CREATE OR REPLACE FUNCTION public.attempt_payload(p_attempt uuid, p_user uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_att public.attempts%rowtype; v_exam public.exams%rowtype; v_qs jsonb;
begin
  select * into v_att from public.attempts where id = p_attempt and user_id = p_user;
  if not found then raise exception 'attempt_not_found'; end if;
  select * into v_exam from public.exams where id = v_att.exam_id;
  if v_att.status='in_progress' and not portal_private.exam_content_ready(v_exam.question_ids,v_exam.track_id) then raise exception 'exam_content_under_review'; end if;

  select coalesce(jsonb_agg(x order by x ->> 'ord'), '[]'::jsonb) into v_qs
    from (
      select jsonb_build_object(
               'id', q.id, 'ord', lpad(ord::text, 4, '0'),
               'type', q.type, 'topic', q.topic, 'difficulty', q.difficulty,
               'stem', q.stem, 'choices', q.choices, 'assets', q.assets,
               'response', aa.response) as x
        from unnest(v_exam.question_ids) with ordinality as u(qid, ord)
        join public.questions q on q.id = u.qid
        left join public.attempt_answers aa
               on aa.attempt_id = p_attempt and aa.question_id = q.id
    ) s;

  return jsonb_build_object(
    'attempt', jsonb_build_object(
        'id', v_att.id, 'exam_id', v_att.exam_id, 'attempt_no', v_att.attempt_no,
        'status', v_att.status, 'started_at', v_att.started_at,
        'deadline_at', v_att.deadline_at, 'shuffle_seed', v_att.shuffle_seed,
        'server_now', now()),
    'exam', jsonb_build_object(
        'id', v_exam.id, 'title', v_exam.title, 'track_id', v_exam.track_id,
        'duration_seconds', v_exam.duration_seconds, 'shuffle', v_exam.shuffle),
    'questions', v_qs);
end $function$

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
           'retake_available', e.assessment_type='lesson_exam' or exists(select 1 from retake_grants g where g.user_id=p_user and g.exam_id=e.id and g.consumed_at is null and (g.expires_at is null or g.expires_at>now())),
           'last', (select jsonb_build_object('id',a.id,'status',a.status,'untimed',a.deadline_at='infinity'::timestamptz,'score',a.score,'total',a.total,'scaled_score',a.scaled_score)
                      from public.attempts a where a.user_id=p_user and a.exam_id=e.id order by a.attempt_no desc limit 1)
         ) order by e.created_at), '[]'::jsonb)
    from public.exams e
   where e.track_id=p_track and e.is_published and public.is_enrolled(p_user,p_track)
     and exists (select 1 from public.assignments a where a.exam_id=e.id and
       (a.user_id=p_user or exists(select 1 from public.group_members gm where gm.group_id=a.group_id and gm.user_id=p_user)));
$function$

;
CREATE OR REPLACE FUNCTION public.daily_state(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
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
    where q.track_id=p_track and q.type='mcq' and portal_private.question_eligible(q,k,p_track,true)
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
  if progress_.quiz_completed_at is null and (select count(*) from public.questions q join public.question_keys k on k.question_id=q.id where q.id=any(qids) and portal_private.question_eligible(q,k,p_track,true))<>5 then raise exception 'daily_content_under_review'; end if;

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
CREATE OR REPLACE FUNCTION public.practice_notebook_state(p_user uuid, p_track text, p_offset integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_items jsonb; v_count int; v_done int;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  if p_offset<0 or p_offset>10000 then raise exception 'invalid_page'; end if;
  insert into public.practice_notebook(user_id,question_id)
  select distinct p_user,r.question_id from public.attempt_results r
  join public.attempts a on a.id=r.attempt_id join public.exams e on e.id=a.exam_id
  join public.questions q on q.id=r.question_id and q.track_id=e.track_id
  join public.question_keys k on k.question_id=q.id
  where a.user_id=p_user and e.track_id=p_track and r.is_correct=false
    and a.status in ('graded','expired') and a.score is not null
    and e.review_policy='full_review' and a.review_unlocks_at<=now()
    and jsonb_typeof(k.correct) in ('string','array') and portal_private.question_eligible(q,k,p_track,false) on conflict do nothing;
  insert into public.practice_notebook(user_id,question_id)
  select distinct p_user,q.id from public.daily_progress dp
  cross join lateral jsonb_each(dp.answers) answer_(qid,response)
  join public.questions q on q.id=answer_.qid::uuid and q.track_id=dp.track_id
  join public.question_keys k on k.question_id=q.id
  where dp.user_id=p_user and dp.track_id=p_track and dp.quiz_completed_at is not null
    and not public.answer_matches(q.type,answer_.response,k.correct)
    and jsonb_typeof(k.correct) in ('string','array') and portal_private.question_eligible(q,k,p_track,false) on conflict do nothing;
  select count(*) filter(where n.correct_streak<2),count(*) filter(where n.correct_streak=2)
    into v_count,v_done from public.practice_notebook n join public.questions q on q.id=n.question_id
    join public.question_keys k on k.question_id=q.id
    where n.user_id=p_user and q.track_id=p_track and portal_private.question_eligible(q,k,p_track,false);
  select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'stem',q.stem,'topic',q.topic,
    'type',q.type,'choices',q.choices,'assets',q.assets,'streak',n.correct_streak,'tries',n.tries)
    order by q.topic,q.id),'[]'::jsonb) into v_items
  from (select n.question_id,n.correct_streak,n.tries,n.updated_at
    from public.practice_notebook n join public.questions page_q on page_q.id=n.question_id
    join public.question_keys page_k on page_k.question_id=page_q.id
    where n.user_id=p_user and page_q.track_id=p_track and n.correct_streak<2
      and portal_private.question_eligible(page_q,page_k,p_track,false)
    order by page_q.topic,n.question_id limit 25 offset p_offset) n
  join public.questions q on q.id=n.question_id;
  return jsonb_build_object('track',p_track,'remaining',v_count,'mastered',v_done,'items',v_items,'offset',p_offset);
end $function$

;
CREATE OR REPLACE FUNCTION public.practice_notebook_answer(p_user uuid, p_track text, p_question uuid, p_answer text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_q public.questions%rowtype; v_key public.question_keys%rowtype; v_ok boolean; v_streak int;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  select * into v_q from public.questions where id=p_question and track_id=p_track;
  if not found then raise exception 'question_not_found'; end if;
  if length(p_answer)>250 or length(p_answer)=0 then raise exception 'invalid_answer'; end if;
  if v_q.type='mcq' and not exists(select 1 from jsonb_array_elements(v_q.choices) c where c->>'key'=p_answer) then raise exception 'invalid_answer'; end if;
  select * into v_key from public.question_keys where question_id=p_question;
  if not found then raise exception 'question_not_found'; end if;
  if not portal_private.question_eligible(v_q,v_key,p_track,false) then raise exception 'question_content_under_review'; end if;
  -- Serialize repeat taps and prevent grading an unearned or already mastered item.
  perform 1 from public.practice_notebook where user_id=p_user and question_id=p_question and correct_streak<2 for update;
  if not found then raise exception 'notebook_item_unavailable'; end if;
  v_ok:=public.answer_matches(v_q.type,to_jsonb(p_answer),v_key.correct);
  update public.practice_notebook set correct_streak=case when v_ok then least(correct_streak+1,2) else 0 end,
    tries=tries+1,updated_at=now() where user_id=p_user and question_id=p_question returning correct_streak into v_streak;
  return jsonb_build_object('correct',v_ok,'streak',v_streak,'mastered',v_streak=2,
    'answer',v_key.correct,'explanation',v_key.explanation);
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
    where q.track_id=p_track and q.topic=any(v_topics) and portal_private.question_eligible(q,k,p_track,false)
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
CREATE OR REPLACE FUNCTION public.practice_drill_state(p_user uuid, p_track text, p_drill uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_drill public.practice_drills%rowtype; v_items jsonb;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  if p_drill is null then
    select * into v_drill from public.practice_drills where user_id=p_user and track_id=p_track
      and completed_at is null and created_at>now()-interval '1 day' order by created_at desc limit 1;
  else
    select * into v_drill from public.practice_drills where id=p_drill and user_id=p_user and track_id=p_track;
  end if;
  if not found then return jsonb_build_object('drill_id',null,'questions','[]'::jsonb,'completed',false); end if;
  if v_drill.completed_at is null and not portal_private.exam_content_ready(v_drill.question_ids,p_track) then return jsonb_build_object('drill_id',null,'questions','[]'::jsonb,'completed',false,'under_review',true); end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'stem',q.stem,'topic',q.topic,
    'type',q.type,'choices',q.choices,'assets',q.assets,
    'answer',case when v_drill.completed_at is not null then k.correct else null end,
    'explanation',case when v_drill.completed_at is not null then k.explanation else null end,
    'submitted',case when v_drill.completed_at is not null then v_drill.answers->q.id::text else null end)
    order by ord.n),'[]'::jsonb) into v_items
  from unnest(v_drill.question_ids) with ordinality ord(id,n)
  join public.questions q on q.id=ord.id join public.question_keys k on k.question_id=q.id;
  return jsonb_build_object('drill_id',v_drill.id,'topics',v_drill.topics,'questions',v_items,
    'completed',v_drill.completed_at is not null,'score',v_drill.score);
end $function$

;
CREATE OR REPLACE FUNCTION public.practice_drill_submit(p_user uuid, p_track text, p_drill uuid, p_answers jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_drill public.practice_drills%rowtype; v_score int;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  select * into v_drill from public.practice_drills
    where id=p_drill and user_id=p_user and track_id=p_track for update;
  if not found then raise exception 'drill_not_found'; end if;
  if v_drill.completed_at is not null then return public.practice_drill_state(p_user,p_track,p_drill); end if;
  if not portal_private.exam_content_ready(v_drill.question_ids,p_track) then raise exception 'question_content_under_review'; end if;
  if jsonb_typeof(p_answers) is distinct from 'object'
    or (select count(*) from jsonb_object_keys(p_answers))<>cardinality(v_drill.question_ids)
    or exists(select 1 from jsonb_object_keys(p_answers) as answer_key(qid)
      where not answer_key.qid=any(select unnest(v_drill.question_ids)::text))
    or exists(select 1 from unnest(v_drill.question_ids) as selected(qid)
      join public.questions q on q.id=selected.qid
      where jsonb_typeof(p_answers->selected.qid::text) is distinct from 'string'
      or length(p_answers->>selected.qid::text)>250 or length(p_answers->>selected.qid::text)=0
      or (q.type='mcq' and not exists(select 1 from jsonb_array_elements(q.choices) c
        where c->>'key'=p_answers->>selected.qid::text)))
  then raise exception 'invalid_answers'; end if;
  select count(*) into v_score from unnest(v_drill.question_ids) as selected(qid)
    join public.questions q on q.id=selected.qid join public.question_keys k on k.question_id=q.id
    where public.answer_matches(q.type,p_answers->selected.qid::text,k.correct);
  update public.practice_drills set answers=p_answers,score=v_score,completed_at=now() where id=p_drill;
  return public.practice_drill_state(p_user,p_track,p_drill);
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
 where r.active and portal_private.question_eligible(q,k,q.track_id,false) and (q.track_id=p_track or (p_track='sat' and q.track_id='est')) and jsonb_typeof(k.correct) in ('string','array') and nullif(q.assets->>'release_hold_reason','') is null
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
 where r.active and portal_private.question_eligible(q,k,q.track_id,false)
  and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation);
 if jsonb_array_length(picked)<>total_ then raise exception 'question_content_under_review'; end if;
 insert into public.revision_sessions(user_id,access_track,lesson,collection,snapshot) values(p_user,p_track,lesson_,collection_,picked) returning id into sid;
 return public.final_revision_state(p_user,p_track,sid);
end $function$

;
commit;
