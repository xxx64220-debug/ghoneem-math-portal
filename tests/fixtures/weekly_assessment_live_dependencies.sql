-- Captured read-only from production on 2026-10-30. Used only in isolated regression tests.
CREATE OR REPLACE FUNCTION portal_private.question_eligible(p_q questions, p_k question_keys, p_track text, p_daily boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;


CREATE OR REPLACE FUNCTION portal_private.exam_content_ready(p_ids uuid[], p_track text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
 select coalesce(cardinality(p_ids),0) between 1 and 200
 and (select count(distinct id) from unnest(p_ids) id)=cardinality(p_ids)
 and (select count(*) from questions q join question_keys k on k.question_id=q.id
  where q.id=any(p_ids) and portal_private.question_eligible(q,k,p_track,false))=cardinality(p_ids)
$function$;


CREATE OR REPLACE FUNCTION public.student_assignment_for(p_exam uuid, p_user uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select a.id
    from public.assignments a
    join public.exams e on e.id = a.exam_id
   where a.exam_id = p_exam
     and e.is_published
     and public.is_enrolled(p_user, e.track_id)
     and (a.user_id = p_user
          or exists (select 1 from public.group_members gm
                      where gm.group_id = a.group_id and gm.user_id = p_user))
     and (a.open_at  is null or now() >= a.open_at)
     and (a.close_at is null or now() <= a.close_at)
   order by a.close_at nulls last
   limit 1;
$function$;


CREATE OR REPLACE FUNCTION public.is_enrolled(p_user uuid, p_track text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
 select exists(select 1 from public.enrollments e join public.profiles p on p.id=e.user_id join public.tracks t on t.id=e.track_id
 where e.user_id=p_user and e.track_id=p_track and e.status='active' and p.status='active' and p.role='student' and t.is_active
 and (e.starts_at is null or e.starts_at<=now()) and (e.ends_at is null or now()<e.ends_at));
$function$;


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
end $function$;
