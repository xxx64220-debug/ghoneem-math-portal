begin;
do $guard$ begin
if md5(pg_get_functiondef('public.attempt_is_mine(uuid,uuid)'::regprocedure))<>'9bffc3cbae64e8972a69a7b9db7b1082' then raise exception 'management preflight: attempt_is_mine changed; refresh release';end if;
if md5(pg_get_functiondef('public.attempt_review(uuid,uuid)'::regprocedure))<>'e303f416d7121df42f4a3628760b61cb' then raise exception 'management preflight: attempt_review changed; refresh release';end if;
if md5(pg_get_functiondef('public.student_dashboard(uuid,text)'::regprocedure))<>'498f3d79293b135fc9e7a26866fb53d8' then raise exception 'management preflight: student_dashboard changed; refresh release';end if;
if md5(pg_get_functiondef('public.my_tracks(uuid)'::regprocedure))<>'7b8bc5b2c6a2b8c19056861bcc84e439' then raise exception 'management preflight: my_tracks changed; refresh release';end if;
if md5(pg_get_functiondef('public.portal_student_controls(uuid,text,jsonb)'::regprocedure))<>'f122333baf6e5d0a1d492af03bac3e65' then raise exception 'management preflight: portal_student_controls changed; refresh release';end if;
if md5(pg_get_functiondef('public.attempt_live_for(uuid,uuid)'::regprocedure))<>'6ab02d9ef14431d7dd5dda2a55629ca7' then raise exception 'management preflight: attempt_live_for changed; refresh release';end if;
if md5(pg_get_functiondef('portal_private.guard_answer()'::regprocedure))<>'3e11510f84f6d812a172c2b38ea52c96' then raise exception 'management preflight: guard_answer changed; refresh release';end if;
if md5(pg_get_functiondef('public.portal_submit(uuid,uuid,text)'::regprocedure))<>'8e9d14ec633afeb65274b05dea89bb99' then raise exception 'management preflight: portal_submit changed; refresh release';end if;
if md5(pg_get_functiondef('public.portal_start_attempt(uuid,uuid,boolean)'::regprocedure))<>'bb75e509e4c8233f0709911a43acdcef' then raise exception 'management preflight: portal_start_attempt changed; refresh release';end if;
end $guard$;
CREATE OR REPLACE FUNCTION public.attempt_is_mine(p_attempt uuid, p_user uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
 select exists(select 1 from attempts a join exams e on e.id=a.exam_id where a.id=p_attempt and a.user_id=p_user and course_history_access(p_user,e.track_id));
$function$
;

CREATE OR REPLACE FUNCTION public.attempt_review(p_attempt uuid, p_user uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_att public.attempts%rowtype; v_exam public.exams%rowtype;
        v_open boolean; v_items jsonb;
begin
  select * into v_att from public.attempts where id = p_attempt and user_id = p_user;
  if not found then raise exception 'attempt_not_found'; end if;
  if v_att.status = 'in_progress' then
    raise exception 'attempt_still_live';
  end if;
  select * into v_exam from public.exams where id = v_att.exam_id;
  if not public.course_history_access(p_user,v_exam.track_id) then raise exception 'not_enrolled_in_track'; end if;

  v_open := v_att.score is not null and v_exam.review_policy = 'full_review'
            and v_att.review_unlocks_at is not null
            and now() >= v_att.review_unlocks_at;

  select coalesce(jsonb_agg(x order by x ->> 'ord'), '[]'::jsonb) into v_items
    from (
      select jsonb_build_object(
               'id', q.id, 'ord', lpad(u.ord::text, 4, '0'),
               'type', q.type, 'stem', q.stem, 'choices', q.choices, 'assets', q.assets,
               'response', aa.response,
               'is_correct', r.is_correct,
               'correct',     case when v_open then k.correct     else null end,
               'explanation', case when v_open then k.explanation else null end) as x
        from unnest(v_exam.question_ids) with ordinality as u(qid, ord)
        join public.questions      q on q.id = u.qid
        join public.question_keys  k on k.question_id = q.id
        left join public.attempt_results r on r.attempt_id = p_attempt and r.question_id = q.id
        left join public.attempt_answers aa on aa.attempt_id = p_attempt and aa.question_id = q.id
    ) s;

  return jsonb_build_object(
    'attempt', jsonb_build_object(
        'id', v_att.id, 'status', v_att.status, 'score', v_att.score,
        'scaled_score', v_att.scaled_score, 'total', v_att.total,
        'time_used', v_att.time_used, 'submitted_at', v_att.submitted_at,
        'review_unlocks_at', v_att.review_unlocks_at),
    'exam', jsonb_build_object('title', v_exam.title, 'track_id', v_exam.track_id,
                               'review_policy', v_exam.review_policy),
    'review_open', v_open,
    'items', case when v_open then v_items else '[]'::jsonb end);
end $function$
;

CREATE OR REPLACE FUNCTION public.student_dashboard(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare history_ jsonb; lessons_ jsonb; summary_ jsonb;
begin
 if not public.course_history_access(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',a.id,'exam_id',e.id,'title',e.title,'assessment_type',e.assessment_type,
  'attempt_no',a.attempt_no,'status',a.status,'score',a.score,'total',a.total,
  'percent',round(100.0*a.score/nullif(a.total,0)),'scaled_score',a.scaled_score,
  'submitted_at',a.submitted_at,'time_used',a.time_used,
  'review_open',e.review_policy='full_review' and a.review_unlocks_at is not null and a.review_unlocks_at<=now(),
  'review_unlocks_at',a.review_unlocks_at
 ) order by a.submitted_at desc,a.id),'[]'::jsonb) into history_
 from attempts a join exams e on e.id=a.exam_id
 where a.user_id=p_user and e.track_id=p_track and a.status in ('submitted','graded','expired');

 with eligible as (
  select a.* from attempts a join exams e on e.id=a.exam_id
  where a.user_id=p_user and e.track_id=p_track and a.status in ('submitted','graded','expired')
   and e.review_policy='full_review' and a.review_unlocks_at is not null and a.review_unlocks_at<=now()
 ), latest as (
  select distinct on (r.question_id) r.question_id,r.is_correct,a.submitted_at
  from eligible a join attempt_results r on r.attempt_id=a.id
  order by r.question_id,a.submitted_at desc,a.attempt_no desc,a.id
 ), coverage as (
  select coalesce(nullif(btrim(q.topic),''),'Mixed / untagged') as lesson,
  count(*) as seen,count(*) filter(where l.is_correct) as correct,
  max(l.submitted_at) as last_practiced
  from latest l join questions q on q.id=l.question_id
  where q.track_id=p_track
  group by 1
 ), catalog as (
  select distinct coalesce(nullif(btrim(q.topic),''),'Mixed / untagged') as lesson
  from exams e cross join lateral unnest(e.question_ids) as eq(question_id) join questions q on q.id=eq.question_id
  where e.track_id=p_track and q.track_id=p_track
   and ((e.is_published and exam_assigned_to(e.id,p_user)) or exists(select 1 from attempts a where a.exam_id=e.id and a.user_id=p_user and a.status in ('submitted','graded','expired')))
 ), ranked as (
  select c.lesson,coalesce(v.seen,0) as seen,coalesce(v.correct,0) as correct,
   round(100.0*v.correct/nullif(v.seen,0)) as percent,v.last_practiced,
   case when coalesce(v.seen,0)=0 then 'not_started' when v.seen<3 then 'more_evidence'
    when 100.0*v.correct/v.seen<60 then 'focus' when 100.0*v.correct/v.seen<80 then 'practice' else 'strong' end as priority
  from catalog c left join coverage v on v.lesson=c.lesson
 ) select coalesce(jsonb_agg(to_jsonb(r) order by
  case priority when 'focus' then 1 when 'practice' then 2 when 'more_evidence' then 3 when 'not_started' then 4 else 5 end,
  percent nulls last,lesson),'[]'::jsonb) into lessons_ from ranked r;

 select jsonb_build_object('completed',count(*),'average_percent',round(avg(100.0*a.score/nullif(a.total,0))),
 'best_percent',round(max(100.0*a.score/nullif(a.total,0))),
 'questions_answered',coalesce(sum(a.total),0),
 'lessons_to_focus',(select count(*) from jsonb_array_elements(lessons_) l where l->>'priority'='focus'),
 'review_pending',count(*) filter(where not(e.review_policy='full_review' and a.review_unlocks_at is not null and a.review_unlocks_at<=now())))
 into summary_ from attempts a join exams e on e.id=a.exam_id where a.user_id=p_user and e.track_id=p_track and a.status in ('submitted','graded','expired');
 return jsonb_build_object('summary',summary_,'history',history_,'lessons',lessons_);
end $function$
;

CREATE OR REPLACE FUNCTION public.my_tracks(p_user uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', t.id, 'name', t.name, 'theme', t.theme, 'practice_open',public.is_enrolled(p_user,t.id), 'ends_at',en.ends_at, 'starts_at',en.starts_at, 'course_label',en.course_label,
           'exams_available', (
              select count(*) from public.exams e
               where e.track_id = t.id and e.is_published and public.is_enrolled(p_user,t.id)
                 and public.student_assignment_for(e.id, p_user) is not null),
           'attempts_done', (
              select count(*) from public.attempts a
                join public.exams e2 on e2.id = a.exam_id
               where a.user_id = p_user and e2.track_id = t.id
                 and a.status in ('graded','expired'))
         ) order by t.id), '[]'::jsonb)
    from public.tracks t
    join public.enrollments en
      on en.track_id = t.id and en.user_id = p_user and public.course_history_access(p_user,t.id)
   where t.is_active or exists(select 1 from public.attempts a join public.exams x on x.id=a.exam_id where a.user_id=p_user and x.track_id=t.id);
$function$
;

CREATE OR REPLACE FUNCTION public.portal_student_controls(p_user uuid, p_action text, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare track_ text:=p_data->>'track'; role_ text; id_ uuid; request_ uuid; qid uuid;
begin
 select role into role_ from public.profiles where id=p_user and status='active';
 if role_ is null or not exists(select 1 from public.tracks where id=track_ and (is_active or (p_action='settings' and public.course_history_access(p_user,track_)))) then raise exception 'forbidden';end if;
 if role_='student' and not (public.is_enrolled(p_user,track_) or (p_action='settings' and public.course_history_access(p_user,track_))) then raise exception 'not_enrolled_in_track';end if;
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
end $function$
;

CREATE OR REPLACE FUNCTION public.attempt_live_for(p_attempt uuid, p_user uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
 select exists(select 1 from attempts a join exams e on e.id=a.exam_id where a.id=p_attempt and a.user_id=p_user and a.status='in_progress' and clock_timestamp()<a.deadline_at and portal_private.attempt_course_access(p_attempt,p_user,false))
 and not exists(select 1 from device_sessions d where d.user_id=p_user and d.session_id=nullif(current_setting('request.jwt.claims',true)::jsonb->>'session_id','')::uuid and d.revoked_at is not null);
$function$
;

CREATE OR REPLACE FUNCTION portal_private.guard_answer()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a public.attempts; e public.exams;
begin
 if TG_OP='UPDATE' and (new.attempt_id<>old.attempt_id or new.question_id<>old.question_id) then raise exception 'answer_identity_immutable'; end if;
 select * into a from attempts where id=new.attempt_id for update;
 if a.status<>'in_progress' or clock_timestamp()>=a.deadline_at then raise exception 'attempt_not_live'; end if;
 select * into e from exams where id=a.exam_id;
 if not(new.question_id=any(e.question_ids)) then raise exception 'question_outside_exam'; end if;
 if not portal_private.attempt_course_access(a.id,a.user_id,false) then raise exception 'not_enrolled_in_track'; end if;
 if new.response is not null and jsonb_typeof(new.response) not in ('string','null') then raise exception 'invalid_response'; end if;
 if length(new.response::text)>1000 then raise exception 'response_too_long'; end if;
 new.answered_at=clock_timestamp(); return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.portal_submit(p_attempt uuid, p_user uuid, p_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare cached portal_private.submissions; payload jsonb;
begin
 perform 1 from attempts a join exams e on e.id=a.exam_id where a.id=p_attempt and a.user_id=p_user and (course_history_access(p_user,e.track_id) and (a.status<>'in_progress' or portal_private.attempt_course_access(a.id,p_user,true))) for update of a;
 if not found then raise exception 'attempt_not_found'; end if;
 select * into cached from portal_private.submissions where attempt_id=p_attempt and user_id=p_user;
 if p_key is not null and cached.idempotency_key=p_key then return jsonb_build_object('status',200,'body',cached.response); end if;
 if (select status from attempts where id=p_attempt)<>'in_progress' then
  return jsonb_build_object('status',409,'body',jsonb_build_object('error','already_submitted','result',attempt_review(p_attempt,p_user)));
 end if;
 perform submit_attempt(p_attempt,p_user);
 payload=attempt_review(p_attempt,p_user);
 if p_key is not null then
  if length(p_key)>128 then raise exception 'invalid_idempotency_key'; end if;
  insert into portal_private.submissions values(p_attempt,p_user,p_key,payload);
 end if;
 return jsonb_build_object('status',200,'body',payload);
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
  if not (public.is_enrolled(p_user, v_exam.track_id) or exists(select 1 from public.attempts a where a.user_id=p_user and a.exam_id=p_exam and a.status='in_progress' and portal_private.attempt_course_access(a.id,p_user,false))) then
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
commit;
