-- Portal upgrade: server-only administration and race-safe exam lifecycle.
-- Apply atomically; preserves all existing questions, accounts and results.
begin;
create schema if not exists portal_private;
revoke all on schema portal_private from public,anon,authenticated;
create table if not exists portal_private.rate_limits(user_id uuid, action text, bucket timestamptz, hits int not null, primary key(user_id,action,bucket));
create table if not exists portal_private.submissions(attempt_id uuid primary key references public.attempts(id) on delete cascade,user_id uuid not null,idempotency_key text not null,response jsonb not null);
alter table portal_private.rate_limits enable row level security;
alter table portal_private.submissions enable row level security;
alter table public.device_sessions add column if not exists revoked_at timestamptz;
alter table public.device_sessions add column if not exists session_id uuid;
create unique index if not exists devices_session_unique on public.device_sessions(session_id) where session_id is not null;
alter table public.exams add column if not exists scoring_map jsonb;
alter table public.exams add constraint exams_one_attempt check(max_attempts=1);
create index if not exists instructor_groups_idx on public.groups(instructor_id,track_id);
create index if not exists group_members_user_idx on public.group_members(user_id,group_id);

create or replace function public.jwt_role() returns text language sql stable security definer set search_path=public as $$
 select role from profiles where id=auth.uid() and status='active';
$$;
create or replace function public.is_enrolled(p_user uuid,p_track text) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from enrollments e join profiles p on p.id=e.user_id join tracks t on t.id=e.track_id where e.user_id=p_user and e.track_id=p_track and e.status='active' and p.status='active' and t.is_active);
$$;
create or replace function public.attempt_live_for(p_attempt uuid,p_user uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from attempts a join exams e on e.id=a.exam_id where a.id=p_attempt and a.user_id=p_user and a.status='in_progress' and clock_timestamp()<a.deadline_at and public.is_enrolled(p_user,e.track_id))
 and not exists(select 1 from device_sessions d where d.user_id=p_user and d.session_id=nullif(current_setting('request.jwt.claims',true)::jsonb->>'session_id','')::uuid and d.revoked_at is not null);
$$;

-- Same row lock as submit: a save cannot commit after grading has begun.
create or replace function portal_private.guard_answer() returns trigger language plpgsql security definer set search_path=public as $$
declare a public.attempts; e public.exams;
begin
 if TG_OP='UPDATE' and (new.attempt_id<>old.attempt_id or new.question_id<>old.question_id) then raise exception 'answer_identity_immutable'; end if;
 select * into a from attempts where id=new.attempt_id for update;
 if a.status<>'in_progress' or clock_timestamp()>=a.deadline_at then raise exception 'attempt_not_live'; end if;
 select * into e from exams where id=a.exam_id;
 if not(new.question_id=any(e.question_ids)) then raise exception 'question_outside_exam'; end if;
 if not is_enrolled(a.user_id,e.track_id) then raise exception 'not_enrolled_in_track'; end if;
 if new.response is not null and jsonb_typeof(new.response) not in ('string','null') then raise exception 'invalid_response'; end if;
 if length(new.response::text)>1000 then raise exception 'response_too_long'; end if;
 new.answered_at=clock_timestamp(); return new;
end $$;
create trigger guard_answer before insert or update on public.attempt_answers for each row execute function portal_private.guard_answer();

create or replace function public.portal_rate_limit(p_user uuid,p_action text) returns void language plpgsql security definer set search_path=public as $$
declare n int;
begin
 insert into portal_private.rate_limits values(p_user,p_action,date_trunc('minute',clock_timestamp()),1)
 on conflict(user_id,action,bucket) do update set hits=portal_private.rate_limits.hits+1 returning hits into n;
 if n>30 then raise exception 'rate_limit_exceeded'; end if;
 delete from portal_private.rate_limits where bucket<now()-interval '1 hour';
end $$;

-- Validate Auth session, and enforce three concurrent sign-ins. Revoked sessions stay revoked.
create or replace function public.portal_session(p_user uuid,p_session uuid,p_agent text) returns void language plpgsql security definer set search_path=public as $$
declare d public.device_sessions;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,0));
 if not exists(select 1 from auth.sessions where id=p_session and user_id=p_user) then raise exception 'invalid_session'; end if;
 select * into d from device_sessions where session_id=p_session;
 if found then
  if d.revoked_at is not null then raise exception 'device_revoked'; end if;
  update device_sessions set last_seen=now() where id=d.id; return;
 end if;
 if (select count(*) from device_sessions ds join auth.sessions s on s.id=ds.session_id where ds.user_id=p_user and ds.revoked_at is null and ds.last_seen>now()-interval '30 days')>=3 then raise exception 'device_limit_reached'; end if;
 insert into device_sessions(user_id,device_hash,session_id,user_agent) values(p_user,p_session::text,p_session,left(p_agent,500));
 insert into audit_log(actor_id,action,target_type,target_id) values(p_user,'device.registered','session',p_session::text);
end $$;
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
  perform pg_advisory_xact_lock(hashtextextended(p_user::text||p_exam::text,0));
  if not exists(select 1 from profiles where id=p_user and role='student' and status='active') then raise exception 'student_account_required'; end if;
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
  v_limit := 1;

  if v_used >= v_limit then
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
create or replace function public.submit_attempt(p_attempt uuid, p_user uuid)
returns public.attempts language plpgsql security definer set search_path = public as $$
declare v_att public.attempts%rowtype;
begin
  update public.attempts
     set status = 'submitted', submitted_at = least(clock_timestamp(),deadline_at)
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

  perform public.grade_attempt(p_attempt);
  if clock_timestamp() >= v_att.deadline_at then update attempts set status='expired' where id=p_attempt; end if;
  select * into v_att from attempts where id=p_attempt;
  return v_att;
end $$;
create or replace function public.finalize_expired_for(p_user uuid, p_exam uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_n integer := 0;
begin
  for v_id in
    select id from public.attempts
     where user_id = p_user and exam_id = p_exam
       and status = 'in_progress' and clock_timestamp() >= deadline_at for update skip locked
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
create or replace function public.sweep_expired_attempts()
returns integer language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_n integer := 0;
begin
  for v_id in
    select id from public.attempts
     where status = 'in_progress' and clock_timestamp() >= deadline_at
     limit 500 for update skip locked
  loop
    update public.attempts set status = 'expired', submitted_at = deadline_at where id = v_id;
    perform public.grade_attempt(v_id);
    update public.attempts set status = 'expired' where id = v_id;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;
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
  if not public.is_enrolled(p_user,v_exam.track_id) then raise exception 'not_enrolled_in_track'; end if;

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
    'items', case when v_open then v_items else '[]'::jsonb end);
end $$;
create or replace function public.my_exams(p_user uuid, p_track text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', e.id, 'title', e.title, 'duration_seconds', e.duration_seconds,
           'questions', coalesce(array_length(e.question_ids,1), 0),
           'open', public.student_assignment_for(e.id, p_user) is not null,
           'attempts', (select count(*) from public.attempts a
                         where a.user_id = p_user and a.exam_id = e.id),
           'max_attempts', 1,
           'retake_available', exists(select 1 from retake_grants g where g.user_id=p_user and g.exam_id=e.id and g.consumed_at is null and (g.expires_at is null or g.expires_at>now())),
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

-- Exact per-paper conversion only. No fabricated linear SAT/EST scores.
create or replace function public.scale_score(p_track text,p_raw int,p_total int) returns int language sql stable set search_path=public as $$ select null::int $$;
create or replace function public.grade_attempt(p_attempt uuid)
returns public.attempts
language plpgsql security definer set search_path = public as $$
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
         -- CHANGED: a scaled score is only meaningful on a full-length paper.
         scaled_score      = case when v_exam.is_full_length
                                  then (v_exam.scoring_map ->> v_score::text)::int
                                  else null end,
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

create or replace function public.portal_submit(p_attempt uuid,p_user uuid,p_key text default null) returns jsonb language plpgsql security definer set search_path=public as $$
declare cached portal_private.submissions; payload jsonb;
begin
 perform 1 from attempts a join exams e on e.id=a.exam_id where a.id=p_attempt and a.user_id=p_user and is_enrolled(p_user,e.track_id) for update of a;
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
end $$;

-- All privileged writes pass through authenticated Edge Functions.
revoke insert,update,delete on profiles,tracks,enrollments,instructor_tracks,groups,group_members,questions,question_keys,exams,assignments,retake_grants,device_sessions from authenticated;
grant select on device_sessions to authenticated;
revoke all on all tables in schema portal_private from public,anon,authenticated;
revoke execute on all functions in schema portal_private from public,anon,authenticated;
revoke execute on function public.portal_rate_limit(uuid,text),public.portal_session(uuid,uuid,text),public.portal_submit(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.portal_rate_limit(uuid,text),public.portal_session(uuid,uuid,text),public.portal_submit(uuid,uuid,text) to service_role;
commit;
