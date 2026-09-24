-- =====================================================================
--  SAT & EST EXAM PORTAL  —  002  FUNCTIONS
--  All invariants that must never be bypassed live here, not in the API.
--  Abdelrahman Ghoneem | 01116004434
-- =====================================================================

-- ---------------------------------------------------------- role helpers
-- SECURITY DEFINER so they bypass RLS and cannot recurse into the policies
-- that call them. They prefer the JWT claim (set by the access-token hook)
-- and fall back to a direct profiles lookup if the hook is not installed.
create or replace function public.jwt_role()
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'user_role', ''),
    (select p.role from public.profiles p where p.id = auth.uid())
  );
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select public.jwt_role() = 'admin';
$$;

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select public.jwt_role() in ('instructor','admin');
$$;

-- An instructor is bounded by track; an admin is not.
create or replace function public.staff_can_touch_track(p_track text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin()
      or (public.jwt_role() = 'instructor'
          and exists (select 1 from public.instructor_tracks it
                       where it.user_id = auth.uid() and it.track_id = p_track));
$$;

create or replace function public.is_enrolled(p_user uuid, p_track text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.enrollments e
                  where e.user_id = p_user and e.track_id = p_track and e.status = 'active');
$$;

-- Optional: Supabase Custom Access Token Hook. Installing it puts the role in
-- the JWT so jwt_role() needs no table read. The design works without it.
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb language plpgsql stable set search_path = public as $$
declare v_role text;
begin
  select p.role into v_role from public.profiles p
   where p.id = (event ->> 'user_id')::uuid;
  return jsonb_set(event, '{claims,user_role}', to_jsonb(coalesce(v_role,'student')));
end $$;

-- ------------------------------------------------------- answer matching
-- Accepts "3/4", "0.75", ".75", "1 1/2", Unicode minus, Arabic-keyboard comma.
create or replace function public.norm_num(t text)
returns numeric language plpgsql immutable as $$
declare s text; parts text[]; n numeric;
begin
  if t is null then return null; end if;
  s := btrim(t);
  s := replace(replace(replace(s, u&'\2212', '-'), u&'\FF0D', '-'), ' ', '');
  s := replace(s, ',', '');
  if s = '' then return null; end if;
  if position('/' in s) > 0 then
    parts := string_to_array(s, '/');
    if array_length(parts,1) <> 2 then return null; end if;
    begin
      if parts[2]::numeric = 0 then return null; end if;
      return parts[1]::numeric / parts[2]::numeric;
    exception when others then return null; end;
  end if;
  begin n := s::numeric; exception when others then return null; end;
  return n;
end $$;

create or replace function public.answer_matches(p_type text, p_response jsonb, p_correct jsonb)
returns boolean language plpgsql immutable as $$
declare r text; rn numeric;
begin
  if p_response is null or p_correct is null then return false; end if;
  r := btrim(p_response #>> '{}');
  if r is null or r = '' then return false; end if;

  if p_type = 'mcq' then
    return upper(r) = upper(btrim(p_correct #>> '{}'));
  end if;

  rn := public.norm_num(r);
  return exists (
    select 1 from jsonb_array_elements_text(
             case when jsonb_typeof(p_correct) = 'array'
                  then p_correct else jsonb_build_array(p_correct #>> '{}') end) c
     where upper(btrim(c)) = upper(r)
        or (rn is not null and public.norm_num(c) is not null
            and abs(public.norm_num(c) - rn) < 0.000001));
end $$;

-- ------------------------------------------------------ assignment lookup
-- Returns the assignment that makes this exam available to this student
-- right now, or NULL. Enrollment in the exam's track is part of the test —
-- this is where SAT/EST isolation is enforced for delivery.
create or replace function public.student_assignment_for(p_exam uuid, p_user uuid)
returns uuid language sql stable security definer set search_path = public as $$
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
$$;

-- ------------------------------------------------------------ scaled score
create or replace function public.scale_score(p_track text, p_raw integer, p_total integer)
returns integer language plpgsql stable set search_path = public as $$
declare s jsonb; lo int; hi int; step int; v numeric;
begin
  if p_total is null or p_total = 0 then return null; end if;
  select scoring into s from public.tracks where id = p_track;
  if s is null or s ->> 'min' is null or s ->> 'max' is null then return null; end if;
  lo := (s ->> 'min')::int; hi := (s ->> 'max')::int;
  step := coalesce((s ->> 'step')::int, 1);
  v := lo + (hi - lo) * (p_raw::numeric / p_total::numeric);
  return (round(v / step) * step)::int;
end $$;

-- ---------------------------------------------------------------------
-- ERROR CONTRACT
-- Every business failure below is raised with the DEFAULT SQLSTATE P0001
-- and a stable, machine-readable MESSAGE. Do not "improve" these with
-- custom SQLSTATEs in the P0002-P0004 range: those are reserved by
-- PL/pgSQL, and P0004 (assert_failure) is one of the two conditions that
-- EXCEPTION WHEN OTHERS deliberately does not catch — an error raised
-- with it would escape every caller's handler. The Edge Functions map
-- these messages to HTTP status codes.
--
--   exam_not_found                 -> 404
--   exam_not_published             -> 403
--   not_enrolled_in_track          -> 403   (SAT/EST isolation)
--   account_suspended              -> 403
--   not_assigned_or_window_closed  -> 403
--   attempt_limit_reached          -> 403
--   attempt_not_found              -> 404
--   already_submitted              -> 409
--   attempt_still_live             -> 409
-- ---------------------------------------------------------------------

-- ============================ START ATTEMPT ===========================
-- Enforces, in one transaction: enrollment, publication, assignment window,
-- attempt count, retake grant consumption. Resumes a live attempt instead of
-- creating a duplicate. Raises with a machine-readable SQLSTATE + message.
create or replace function public.start_attempt(p_exam uuid, p_user uuid)
returns public.attempts language plpgsql security definer set search_path = public as $$
declare
  v_exam        public.exams%rowtype;
  v_attempt     public.attempts%rowtype;
  v_assignment  uuid;
  v_used        integer;
  v_limit       integer;
  v_grant       uuid;
  v_duration    integer;
begin
  select * into v_exam from public.exams where id = p_exam;
  if not found then
    raise exception 'exam_not_found';
  end if;
  if not v_exam.is_published then
    raise exception 'exam_not_published';
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
  v_limit := v_exam.max_attempts;

  if v_used >= v_limit then
    select id into v_grant from public.retake_grants
     where user_id = p_user and exam_id = p_exam
       and consumed_at is null
       and (expires_at is null or expires_at > now())
     order by granted_at limit 1;
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
          now() + make_interval(secs => v_duration),
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
end $$;

-- ============================ GRADE (internal) =========================
create or replace function public.grade_attempt(p_attempt uuid)
returns public.attempts language plpgsql security definer set search_path = public as $$
declare
  v_att   public.attempts%rowtype;
  v_exam  public.exams%rowtype;
  v_score integer;
  v_total integer;
  v_close timestamptz;
begin
  select * into v_att  from public.attempts where id = p_attempt;
  select * into v_exam from public.exams    where id = v_att.exam_id;

  delete from public.attempt_results where attempt_id = p_attempt;

  insert into public.attempt_results(attempt_id, question_id, is_correct, awarded)
  select p_attempt, q.id,
         public.answer_matches(q.type, aa.response, k.correct),
         case when public.answer_matches(q.type, aa.response, k.correct) then 1 else 0 end
    from unnest(v_exam.question_ids) as qid
    join public.questions      q  on q.id = qid
    join public.question_keys  k  on k.question_id = q.id
    left join public.attempt_answers aa
           on aa.attempt_id = p_attempt and aa.question_id = q.id;

  select count(*) filter (where is_correct), count(*)
    into v_score, v_total
    from public.attempt_results where attempt_id = p_attempt;

  select a.close_at into v_close from public.assignments a where a.id = v_att.assignment_id;

  update public.attempts
     set status            = 'graded',
         score             = v_score,
         total             = v_total,
         scaled_score      = public.scale_score(v_exam.track_id, v_score, v_total),
         time_used         = greatest(0, extract(epoch from
                               (coalesce(submitted_at, now()) - started_at))::int),
         review_unlocks_at = case
                               when v_exam.review_policy = 'instructor_release' then null
                               when v_close is not null and v_close > now() then v_close
                               else now()
                             end
   where id = p_attempt
  returning * into v_att;

  return v_att;
end $$;

-- =========================== SUBMIT ATTEMPT ============================
-- Layer 3: the state transition is a single UPDATE. Zero rows updated means
-- it was already submitted — the caller must return 409, never a new grade.
create or replace function public.submit_attempt(p_attempt uuid, p_user uuid)
returns public.attempts language plpgsql security definer set search_path = public as $$
declare v_att public.attempts%rowtype;
begin
  update public.attempts
     set status = 'submitted', submitted_at = now()
   where id = p_attempt and user_id = p_user and status = 'in_progress'
  returning * into v_att;

  if not found then
    select * into v_att from public.attempts where id = p_attempt and user_id = p_user;
    if not found then
      raise exception 'attempt_not_found';
    end if;
    raise exception 'already_submitted';
  end if;

  insert into public.audit_log(actor_id, action, target_type, target_id, meta)
  values (p_user, 'attempt.submitted', 'attempt', p_attempt::text,
          jsonb_build_object('exam_id', v_att.exam_id));

  return public.grade_attempt(p_attempt);
end $$;

-- ====================== EXPIRY: lazy + swept ===========================
create or replace function public.finalize_expired_for(p_user uuid, p_exam uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_n integer := 0;
begin
  for v_id in
    select id from public.attempts
     where user_id = p_user and exam_id = p_exam
       and status = 'in_progress' and now() > deadline_at
  loop
    update public.attempts
       set status = 'expired', submitted_at = deadline_at
     where id = v_id;
    perform public.grade_attempt(v_id);
    update public.attempts set status = 'expired' where id = v_id;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- Runs every minute under pg_cron. Mandatory: without it an abandoned attempt
-- would block the partial unique index forever.
create or replace function public.sweep_expired_attempts()
returns integer language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_n integer := 0;
begin
  for v_id in
    select id from public.attempts
     where status = 'in_progress' and now() > deadline_at
     limit 500
  loop
    update public.attempts set status = 'expired', submitted_at = deadline_at where id = v_id;
    perform public.grade_attempt(v_id);
    update public.attempts set status = 'expired' where id = v_id;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- ============================ RETAKE GRANT =============================
create or replace function public.grant_retake(p_user uuid, p_exam uuid,
                                               p_by uuid, p_reason text,
                                               p_expires timestamptz default null)
returns public.retake_grants language plpgsql security definer set search_path = public as $$
declare v_g public.retake_grants%rowtype; v_track text;
begin
  select track_id into v_track from public.exams where id = p_exam;
  if v_track is null then
    raise exception 'exam_not_found';
  end if;

  insert into public.retake_grants(user_id, exam_id, granted_by, reason, expires_at)
  values (p_user, p_exam, p_by, coalesce(p_reason,''), p_expires)
  returning * into v_g;

  insert into public.audit_log(actor_id, action, target_type, target_id, meta)
  values (p_by, 'retake.granted', 'exam', p_exam::text,
          jsonb_build_object('student', p_user, 'reason', p_reason, 'grant_id', v_g.id));

  return v_g;
end $$;

-- ===================== EXAM DELIVERY (keys stripped) ===================
-- The only path by which question text reaches a student. Called with the
-- service-role key from the Edge Function; never exposed to the client.
create or replace function public.attempt_payload(p_attempt uuid, p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_att public.attempts%rowtype; v_exam public.exams%rowtype; v_qs jsonb;
begin
  select * into v_att from public.attempts where id = p_attempt and user_id = p_user;
  if not found then raise exception 'attempt_not_found'; end if;
  select * into v_exam from public.exams where id = v_att.exam_id;

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
end $$;

-- ============================== REVIEW =================================
-- Correct answers and explanations are attached only when review is unlocked.
create or replace function public.attempt_review(p_attempt uuid, p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_att public.attempts%rowtype; v_exam public.exams%rowtype;
        v_open boolean; v_items jsonb;
begin
  select * into v_att from public.attempts where id = p_attempt and user_id = p_user;
  if not found then raise exception 'attempt_not_found'; end if;
  if v_att.status = 'in_progress' then
    raise exception 'attempt_still_live';
  end if;
  select * into v_exam from public.exams where id = v_att.exam_id;

  v_open := v_exam.review_policy = 'full_review'
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
    'items', case when v_open or v_exam.review_policy <> 'instructor_release'
                  then v_items else '[]'::jsonb end);
end $$;

-- =================== STUDENT HOME: tracks + exam list ==================
create or replace function public.my_tracks(p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', t.id, 'name', t.name, 'theme', t.theme,
           'exams_available', (
              select count(*) from public.exams e
               where e.track_id = t.id and e.is_published
                 and public.student_assignment_for(e.id, p_user) is not null),
           'attempts_done', (
              select count(*) from public.attempts a
                join public.exams e2 on e2.id = a.exam_id
               where a.user_id = p_user and e2.track_id = t.id
                 and a.status in ('graded','expired'))
         ) order by t.id), '[]'::jsonb)
    from public.tracks t
    join public.enrollments en
      on en.track_id = t.id and en.user_id = p_user and en.status = 'active'
   where t.is_active;
$$;

create or replace function public.my_exams(p_user uuid, p_track text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', e.id, 'title', e.title, 'duration_seconds', e.duration_seconds,
           'questions', coalesce(array_length(e.question_ids,1), 0),
           'open', public.student_assignment_for(e.id, p_user) is not null,
           'attempts', (select count(*) from public.attempts a
                         where a.user_id = p_user and a.exam_id = e.id),
           'max_attempts', e.max_attempts,
           'last', (select jsonb_build_object('id', a.id, 'status', a.status,
                                              'score', a.score, 'total', a.total,
                                              'scaled_score', a.scaled_score)
                      from public.attempts a
                     where a.user_id = p_user and a.exam_id = e.id
                     order by a.attempt_no desc limit 1)
         ) order by e.created_at), '[]'::jsonb)
    from public.exams e
   where e.track_id = p_track
     and e.is_published
     and public.is_enrolled(p_user, p_track)
     and exists (select 1 from public.assignments a
                  where a.exam_id = e.id
                    and (a.user_id = p_user
                         or exists (select 1 from public.group_members gm
                                     where gm.group_id = a.group_id and gm.user_id = p_user)));
$$;

-- ================= POLICY HELPERS (SECURITY DEFINER) ==================
-- Every cross-table lookup used inside an RLS policy goes through one of
-- these. A policy that queries another RLS-protected table directly causes
-- "infinite recursion detected in policy" as soon as the two tables
-- reference each other; SECURITY DEFINER breaks that cycle and is faster.

create or replace function public.exam_track(p_exam uuid)
returns text language sql stable security definer set search_path = public as $$
  select track_id from public.exams where id = p_exam;
$$;

create or replace function public.group_track(p_group uuid)
returns text language sql stable security definer set search_path = public as $$
  select track_id from public.groups where id = p_group;
$$;

create or replace function public.question_track(p_question uuid)
returns text language sql stable security definer set search_path = public as $$
  select track_id from public.questions where id = p_question;
$$;

create or replace function public.attempt_track(p_attempt uuid)
returns text language sql stable security definer set search_path = public as $$
  select e.track_id from public.attempts a join public.exams e on e.id = a.exam_id
   where a.id = p_attempt;
$$;

create or replace function public.in_group(p_group uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.group_members gm
                  where gm.group_id = p_group and gm.user_id = p_user);
$$;

-- Assignment existence only. The open/close window is enforced at start,
-- so a student can still see an upcoming exam in their list.
create or replace function public.exam_assigned_to(p_exam uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.assignments a
     where a.exam_id = p_exam
       and (a.user_id = p_user
            or exists (select 1 from public.group_members gm
                        where gm.group_id = a.group_id and gm.user_id = p_user)));
$$;

create or replace function public.attempt_is_mine(p_attempt uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.attempts a
                  where a.id = p_attempt and a.user_id = p_user);
$$;

-- Lane A gate: the student's own attempt, still in progress, still in time.
create or replace function public.attempt_live_for(p_attempt uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.attempts a
                  where a.id = p_attempt and a.user_id = p_user
                    and a.status = 'in_progress' and now() < a.deadline_at);
$$;

create or replace function public.attempt_review_open(p_attempt uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.attempts a
                  where a.id = p_attempt and a.user_id = p_user
                    and a.status in ('submitted','graded','expired')
                    and a.review_unlocks_at is not null
                    and now() >= a.review_unlocks_at);
$$;
