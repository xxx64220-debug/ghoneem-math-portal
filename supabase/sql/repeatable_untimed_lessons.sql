-- Preserve every attempt; infinity is an explicit unbounded deadline compatible with existing expiry and answer policies.
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

REVOKE ALL ON FUNCTION public.portal_start_attempt(uuid,uuid,boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.portal_start_attempt(uuid,uuid,boolean) TO service_role;
CREATE OR REPLACE FUNCTION public.start_attempt(p_exam uuid,p_user uuid)
RETURNS public.attempts LANGUAGE sql SECURITY DEFINER SET search_path=public AS $$
 SELECT public.portal_start_attempt(p_exam,p_user,false);
$$;

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
           'open', public.student_assignment_for(e.id, p_user) is not null,
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
$function$;
