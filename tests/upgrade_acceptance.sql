-- Execute only inside an outer transaction that is ALWAYS rolled back.
-- Does not replace Supabase auth functions or grant access to auth.users.
create or replace function public.test_login(p_user uuid,p_role text default 'authenticated') returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claims',json_build_object('sub',p_user::text)::text,true);
 execute format('set local role %I',p_role);
end $$;
grant execute on function public.test_login(uuid,text) to authenticated;
-- =====================================================================
--  SAT & EST EXAM PORTAL  —  ACCEPTANCE TESTS
--  Proves, against a real database, the guarantees claimed in the design:
--  track isolation, answer-key secrecy, single-submission enforcement.
--
--  Run after 001–004. Re-runnable: it deletes its own fixtures first.
--  Every test owns its own student, so each one commits and the results
--  table survives. (An earlier version wrapped tests in ROLLBACK, which
--  also rolled back the recorded results — a passing suite that reported
--  almost nothing.)
--  Abdelrahman Ghoneem | 01116004434
-- =====================================================================

drop table if exists public.test_results;
create table public.test_results(n serial, label text, ok boolean, detail text);
grant all on public.test_results to public;
grant all on sequence public.test_results_n_seq to public;

create or replace function public.t_ok(p_label text, p_ok boolean, p_detail text default '')
returns void language sql security definer as $$
  insert into public.test_results(label, ok, detail) values (p_label, coalesce(p_ok,false), p_detail);
$$;
grant execute on function public.t_ok(text, boolean, text) to public;

create table if not exists public.test_ids(k text primary key, v uuid);
grant select on public.test_ids to public;

-- =====================================================================
--  FIXTURES
-- =====================================================================
do $$
declare
  ids  text[] := array['admin','sat_only','est_only','both',
                       's6','s7','s8','s9','s10','s11','s13','s15'];
  u    uuid;
  g_sat uuid; g_est uuid;
  qa uuid; qb uuid; qc uuid; qd uuid;
  e_sat uuid; e_est uuid; e_short uuid;
begin
  -- clean previous run
  delete from public.attempts   where user_id in (select v from public.test_ids);
  delete from public.audit_log  where actor_id in (select v from public.test_ids);
  delete from public.profiles   where id      in (select v from public.test_ids);
  delete from auth.users        where id      in (select v from public.test_ids);
  delete from public.exams      where title like 'PORTAL_UPGRADE_QA %';
  delete from public.questions  where topic = 'PORTAL_UPGRADE_QA';
  delete from public.groups     where name like 'PORTAL_UPGRADE_QA %';
  delete from public.test_ids;

  insert into public.test_ids(k, v)
    select x, gen_random_uuid() from unnest(ids) as x;

  insert into auth.users(id, email)
    select ti.v, ti.k || '@test.local' from public.test_ids ti;

  insert into public.profiles(id, full_name, role)
    select ti.v, ti.k, case when ti.k = 'admin' then 'admin' else 'student' end
      from public.test_ids ti;

  select ti.v into u from public.test_ids ti where ti.k = 'admin';

  -- Everyone is SAT-enrolled except est_only; both + est_only get EST.
  insert into public.enrollments(user_id, track_id, enrolled_by)
    select ti.v, 'sat', u from public.test_ids ti where ti.k not in ('est_only');
  insert into public.enrollments(user_id, track_id, enrolled_by)
    select ti.v, 'est', u from public.test_ids ti where ti.k in ('est_only','both');

  insert into public.groups(track_id, name) values ('sat','PORTAL_UPGRADE_QA SAT group') returning id into g_sat;
  insert into public.groups(track_id, name) values ('est','PORTAL_UPGRADE_QA EST group') returning id into g_est;

  insert into public.group_members(group_id, user_id)
    select g_sat, ti.v from public.test_ids ti where ti.k not in ('est_only');
  insert into public.group_members(group_id, user_id)
    select g_est, ti.v from public.test_ids ti where ti.k in ('est_only','both');

  -- SAT questions
  insert into public.questions(track_id, topic, type, stem, choices)
    values ('sat','PORTAL_UPGRADE_QA','mcq','2 + 2 = ?',
            '[{"key":"A","text":"3"},{"key":"B","text":"4"}]') returning id into qa;
  insert into public.question_keys values (qa, '"B"', 'Two plus two is four.');

  insert into public.questions(track_id, topic, type, stem)
    values ('sat','PORTAL_UPGRADE_QA','grid_in','Write three quarters as a decimal.') returning id into qb;
  insert into public.question_keys values (qb, '["3/4","0.75",".75"]', 'Three quarters is 0.75.');

  insert into public.questions(track_id, topic, type, stem, choices)
    values ('sat','PORTAL_UPGRADE_QA','mcq','Unassigned question','[{"key":"A","text":"x"}]') returning id into qd;
  insert into public.question_keys values (qd, '"A"', 'Belongs to no exam.');

  -- EST question
  insert into public.questions(track_id, topic, type, stem, choices)
    values ('est','PORTAL_UPGRADE_QA','mcq','10% of 50 = ?',
            '[{"key":"A","text":"5"},{"key":"B","text":"10"}]') returning id into qc;
  insert into public.question_keys values (qc, '"A"', 'Ten percent of fifty is five.');

  insert into public.exams(track_id, title, duration_seconds, question_ids, is_published)
    values ('sat','PORTAL_UPGRADE_QA SAT exam', 3600, array[qa,qb], true) returning id into e_sat;
  insert into public.exams(track_id, title, duration_seconds, question_ids, is_published)
    values ('est','PORTAL_UPGRADE_QA EST exam', 3600, array[qc],    true) returning id into e_est;
  insert into public.exams(track_id, title, duration_seconds, question_ids, is_published)
    values ('sat','PORTAL_UPGRADE_QA SAT short', 60, array[qa],     true) returning id into e_short;

  insert into public.assignments(exam_id, group_id) values
    (e_sat, g_sat), (e_est, g_est), (e_short, g_sat);

  insert into public.test_ids(k, v) values
    ('qa',qa),('qb',qb),('qc',qc),('qd',qd),
    ('e_sat',e_sat),('e_est',e_est),('e_short',e_short),
    ('g_sat',g_sat),('g_est',g_est);
end $$;

create or replace function public.tid(p_k text) returns uuid
language sql stable as $$ select v from public.test_ids where k = p_k $$;
grant execute on function public.tid(text) to public;

-- =====================================================================
-- 1  A student session cannot read question_keys.
-- =====================================================================
do $$ declare n int; begin
  perform public.test_login(public.tid('sat_only'));
  begin
    select count(*) into n from public.question_keys;
  exception when insufficient_privilege then n := -1;
  end;
  execute 'reset role';
  perform public.t_ok('1  student reading question_keys gets nothing',
                      n <= 0, case when n < 0 then 'denied at grant level'
                                   else format('rows=%s', n) end);
end $$;

-- 1b  ...and cannot read the question bank either.
do $$ declare n int; begin
  perform public.test_login(public.tid('sat_only'));
  select count(*) into n from public.questions;
  execute 'reset role';
  perform public.t_ok('1b student reading questions gets nothing', n = 0, format('rows=%s', n));
end $$;

-- =====================================================================
-- 2  A student cannot insert into attempts.
-- =====================================================================
do $$ declare ok boolean := false; msg text := ''; begin
  perform public.test_login(public.tid('sat_only'));
  begin
    insert into public.attempts(user_id, exam_id, attempt_no, shuffle_seed, deadline_at)
    values (public.tid('sat_only'), public.tid('e_sat'), 99, 1, now() + interval '1 hour');
  exception when others then ok := true; msg := sqlerrm;
  end;
  execute 'reset role';
  perform public.t_ok('2  student inserting into attempts is denied', ok, msg);
end $$;

-- 2b  ...and cannot update a submitted attempt.
do $$ declare a public.attempts%rowtype; n int; msg text := ''; begin
  a := public.start_attempt(public.tid('e_sat'), public.tid('s15'));
  perform public.submit_attempt(a.id, public.tid('s15'));
  perform public.test_login(public.tid('s15'));
  begin
    update public.attempts set score = 999 where id = a.id;
    get diagnostics n = row_count;
  exception when others then n := -1; msg := sqlerrm;
  end;
  execute 'reset role';
  perform public.t_ok('2b student updating a submitted attempt changes nothing',
                      n <= 0 and (select score from public.attempts where id = a.id) <> 999,
                      case when n < 0 then 'denied: ' || msg else format('rows_updated=%s', n) end);
end $$;

-- =====================================================================
-- 3  An EST-only student sees zero SAT rows.
-- =====================================================================
do $$ declare ne int; nq int; na int; nt int; begin
  perform public.test_login(public.tid('est_only'));
  select count(*) into ne from public.exams       where track_id = 'sat';
  select count(*) into nq from public.questions   where track_id = 'sat';
  select count(*) into nt from public.tracks      where id       = 'sat';
  select count(*) into na from public.assignments a
    where a.exam_id in (select id from public.exams where track_id = 'sat');
  execute 'reset role';
  perform public.t_ok('3  EST-only student sees no SAT exams, questions, tracks or assignments',
                      ne = 0 and nq = 0 and na = 0 and nt = 0,
                      format('exams=%s questions=%s tracks=%s assignments=%s', ne, nq, nt, na));
end $$;

-- 3b  ...and does see their own EST exam.
do $$ declare ne int; begin
  perform public.test_login(public.tid('est_only'));
  select count(*) into ne from public.exams where track_id = 'est';
  execute 'reset role';
  perform public.t_ok('3b EST-only student does see EST exams', ne >= 1, format('exams=%s', ne));
end $$;

-- =====================================================================
-- 4  That student calling start_attempt on a SAT exam is refused.
-- =====================================================================
do $$ declare msg text := '(no error raised)'; begin
  begin
    perform public.start_attempt(public.tid('e_sat'), public.tid('est_only'));
  exception when others then msg := sqlerrm;
  end;
  perform public.t_ok('4  EST-only student starting a SAT attempt is refused',
                      msg = 'not_enrolled_in_track', msg);
end $$;

-- =====================================================================
-- 5  A dual-enrolled student holds one live SAT and one live EST attempt.
-- =====================================================================
do $$ declare a1 uuid; a2 uuid; n int; begin
  a1 := (public.start_attempt(public.tid('e_sat'), public.tid('both'))).id;
  a2 := (public.start_attempt(public.tid('e_est'), public.tid('both'))).id;
  select count(*) into n from public.attempts
   where user_id = public.tid('both') and status = 'in_progress' and id in (a1, a2);
  perform public.t_ok('5  concurrent SAT + EST live attempts are allowed', n = 2, format('live=%s', n));
end $$;

-- =====================================================================
-- 6  Two submits produce one grade and one refusal.
-- =====================================================================
do $$ declare u uuid := public.tid('s6'); a public.attempts%rowtype;
           g public.attempts%rowtype; msg text := '(no error)'; begin
  a := public.start_attempt(public.tid('e_sat'), u);
  insert into public.attempt_answers(attempt_id, question_id, response)
    values (a.id, public.tid('qa'), '"B"'), (a.id, public.tid('qb'), '"0.75"');
  g := public.submit_attempt(a.id, u);
  begin
    perform public.submit_attempt(a.id, u);
  exception when others then msg := sqlerrm;
  end;
  perform public.t_ok('6  second submit is refused, first grade stands',
                      msg = 'already_submitted' and g.score = 2 and g.total = 2,
                      format('second=%s score=%s/%s', msg, g.score, g.total));
  perform public.t_ok('6b grid-in accepts an equivalent form (0.75 for 3/4)',
                      (select is_correct from public.attempt_results
                        where attempt_id = a.id and question_id = public.tid('qb')));
  -- A lesson drill must NOT carry a scaled 200-800 score. Scaling a short
  -- quiz to an SAT number tells a student something untrue, so scaled_score
  -- is reserved for exams flagged is_full_length (see migration 008).
  perform public.t_ok('6c a drill carries NO scaled score',
                      g.scaled_score is null, format('scaled=%s', coalesce(g.scaled_score::text,'null')));
end $$;

-- =====================================================================
-- 6d A full-length paper DOES carry a scaled score, on the track's scale.
-- =====================================================================
do $$
declare u uuid := public.tid('s15'); e uuid; a public.attempts%rowtype; g public.attempts%rowtype;
begin
  e := public.new_exam('sat', 'PORTAL_UPGRADE_QA full length', 2, 60, null, true, true, 'skip', true);
  update exams set scoring_map='{"0":200,"1":500,"2":800}' where id=e;
  insert into public.assignments(exam_id, user_id) values (e, u);
  a := public.start_attempt(e, u);
  insert into public.attempt_answers(attempt_id, question_id, response)
    select a.id, x, to_jsonb(k.correct #>> '{}')
      from unnest((select question_ids from public.exams where id = e)) x
      join public.question_keys k on k.question_id = x;
  perform public.submit_attempt(a.id, u);
  select * into g from public.attempts where id = a.id;
  perform public.t_ok('6d a full-length paper IS scaled 200-800',
                      g.scaled_score between 200 and 800,
                      format('scaled=%s raw=%s/%s', coalesce(g.scaled_score::text,'null'), g.score, g.total));
end $$;

-- =====================================================================
-- 7  A post-deadline attempt grades saved answers and is marked expired.
-- =====================================================================
do $$ declare u uuid := public.tid('s7'); a public.attempts%rowtype;
           st text; sc int; begin
  a := public.start_attempt(public.tid('e_short'), u);
  insert into public.attempt_answers(attempt_id, question_id, response)
    values (a.id, public.tid('qa'), '"B"');
  update public.attempts set deadline_at = now() - interval '1 minute' where id = a.id;
  perform public.finalize_expired_for(u, public.tid('e_short'));
  select status, score into st, sc from public.attempts where id = a.id;
  perform public.t_ok('7  post-deadline attempt is expired and graded on saved answers',
                      st = 'expired' and sc = 1, format('status=%s score=%s', st, sc));
end $$;

-- 7b  Lane A refuses a write after the deadline.
do $$ declare u uuid := public.tid('s7'); a public.attempts%rowtype;
           ok boolean := false; msg text := ''; begin
  a := public.start_attempt(public.tid('e_sat'), u);
  update public.attempts set deadline_at = now() - interval '1 minute' where id = a.id;
  perform public.test_login(u);
  begin
    insert into public.attempt_answers(attempt_id, question_id, response)
      values (a.id, public.tid('qa'), '"B"');
  exception when others then ok := true; msg := sqlerrm;
  end;
  execute 'reset role';
  perform public.t_ok('7b autosave after the deadline is refused by RLS', ok, msg);
end $$;

-- =====================================================================
-- 8  An abandoned attempt is swept and does not become a free retake.
-- =====================================================================
do $$ declare u uuid := public.tid('s8'); a public.attempts%rowtype;
           n int; msg text := '(no error)'; begin
  a := public.start_attempt(public.tid('e_sat'), u);
  update public.attempts set deadline_at = now() - interval '1 hour' where id = a.id;
  n := public.sweep_expired_attempts();
  perform public.t_ok('8  sweeper finalises abandoned attempts', n >= 1, format('swept=%s', n));
  begin
    perform public.start_attempt(public.tid('e_sat'), u);
  exception when others then msg := sqlerrm;
  end;
  perform public.t_ok('8b a swept attempt still counts against the limit',
                      msg = 'attempt_limit_reached', msg);
end $$;

-- =====================================================================
-- 9  Retakes: refused without a grant, exactly one extra with a grant.
-- =====================================================================
do $$ declare u uuid := public.tid('s9'); e uuid := public.tid('e_sat');
           adm uuid := public.tid('admin'); a public.attempts%rowtype;
           b public.attempts%rowtype; msg text := '(no error)'; msg2 text := '(no error)';
           consumed timestamptz; begin
  a := public.start_attempt(e, u);
  perform public.submit_attempt(a.id, u);
  begin perform public.start_attempt(e, u); exception when others then msg := sqlerrm; end;
  perform public.t_ok('9  a second start without a grant is refused',
                      msg = 'attempt_limit_reached', msg);

  perform public.grant_retake(u, e, adm, 'internet cut out');
  b := public.start_attempt(e, u);
  select consumed_at into consumed from public.retake_grants
   where user_id = u and exam_id = e order by granted_at desc limit 1;
  perform public.t_ok('9b one extra attempt after a grant, and the grant is consumed',
                      b.attempt_no = 2 and consumed is not null,
                      format('attempt_no=%s consumed=%s', b.attempt_no, consumed is not null));

  perform public.submit_attempt(b.id, u);
  begin perform public.start_attempt(e, u); exception when others then msg2 := sqlerrm; end;
  perform public.t_ok('9c the same grant cannot be reused',
                      msg2 = 'attempt_limit_reached', msg2);
end $$;

-- =====================================================================
-- 10  A response for a question outside the exam is rejected.
-- =====================================================================
do $$ declare u uuid := public.tid('s10'); a public.attempts%rowtype;
           g public.attempts%rowtype; n int; begin
  a := public.start_attempt(public.tid('e_sat'), u);
  begin
    insert into public.attempt_answers(attempt_id,question_id,response) values(a.id,public.tid('qd'),'"A"');
    raise exception 'outside_exam_was_not_rejected';
  exception when others then
    if sqlerrm<>'question_outside_exam' then raise; end if;
  end;
  g := public.submit_attempt(a.id, u);
  select count(*) into n from public.attempt_results
   where attempt_id = a.id and question_id = public.tid('qd');
  perform public.t_ok('10 an out-of-exam response is not graded',
                      g.total = 2 and n = 0,
                      format('total=%s stray_results=%s', g.total, n));
end $$;

-- =====================================================================
-- 11  Review is withheld until review_unlocks_at.
-- =====================================================================
do $$ declare u uuid := public.tid('s11'); a public.attempts%rowtype;
           r jsonb; n int; begin
  a := public.start_attempt(public.tid('e_sat'), u);
  perform public.submit_attempt(a.id, u);

  update public.attempts set review_unlocks_at = now() + interval '4 hours' where id = a.id;
  r := public.attempt_review(a.id, u);
  perform public.t_ok('11 locked review hides correct answers and explanations',
                      (r ->> 'review_open')::boolean = false
                      and (r -> 'items' -> 0 ->> 'correct') is null
                      and (r -> 'items' -> 0 ->> 'explanation') is null,
                      format('review_open=%s correct=%s',
                             r ->> 'review_open', r -> 'items' -> 0 ->> 'correct'));

  perform public.test_login(u);
  select count(*) into n from public.attempt_results where attempt_id = a.id;
  execute 'reset role';
  perform public.t_ok('11b RLS also hides attempt_results while review is locked',
                      n = 0, format('rows=%s', n));

  update public.attempts set review_unlocks_at = now() - interval '1 minute' where id = a.id;
  r := public.attempt_review(a.id, u);
  perform public.t_ok('11c unlocked review reveals answers and explanations',
                      (r ->> 'review_open')::boolean = true
                      and (r -> 'items' -> 0 ->> 'correct') is not null
                      and (r -> 'items' -> 0 ->> 'explanation') <> '',
                      format('correct=%s', r -> 'items' -> 0 ->> 'correct'));

  perform public.test_login(u);
  select count(*) into n from public.attempt_results where attempt_id = a.id;
  execute 'reset role';
  perform public.t_ok('11d RLS releases attempt_results once review is unlocked',
                      n = 2, format('rows=%s', n));
end $$;

-- =====================================================================
-- 12  Scaled scores use the right track's scale.
-- =====================================================================
do $$ declare sat_full int; sat_half int; est_full int; est_half int; begin
  sat_full := public.scale_score('sat', 10, 10);
  sat_half := public.scale_score('sat',  5, 10);
  est_full := public.scale_score('est',  4,  4);
  est_half := public.scale_score('est',  2,  4);
  perform public.t_ok('12 SAT has no fabricated fallback conversion',
                      sat_full is null and sat_half is null,
                      format('full=%s half=%s', sat_full, sat_half));
  perform public.t_ok('12b EST has no fabricated fallback conversion',
                      est_full is null and est_half is null,
                      format('full=%s half=%s', est_full, est_half));
end $$;

-- =====================================================================
-- 13  Privileged actions are audited.
-- =====================================================================
do $$ declare u uuid := public.tid('s13'); e uuid := public.tid('e_sat');
           adm uuid := public.tid('admin'); a public.attempts%rowtype; n int; begin
  a := public.start_attempt(e, u);
  perform public.submit_attempt(a.id, u);
  perform public.grant_retake(u, e, adm, 'audited');
  select count(*) into n from public.audit_log
   where actor_id in (u, adm)
     and action in ('attempt.started','attempt.submitted','retake.granted');
  perform public.t_ok('13 audit log records start, submit and grant', n >= 3, format('rows=%s', n));
end $$;

-- 13b  A student cannot read the audit log.
do $$ declare n int; begin
  perform public.test_login(public.tid('s13'));
  select count(*) into n from public.audit_log;
  execute 'reset role';
  perform public.t_ok('13b student reading the audit log gets nothing', n = 0, format('rows=%s', n));
end $$;

-- =====================================================================
-- 14  Answer normalisation edge cases.
-- =====================================================================
do $$ begin
  perform public.t_ok('14 grid-in: 0.75 matches a 3/4 key',
     public.answer_matches('grid_in','"0.75"','["3/4"]'));
  perform public.t_ok('14b grid-in: a Unicode minus is accepted',
     public.answer_matches('grid_in', to_jsonb(u&'\2212' || '5'), '["-5"]'));
  perform public.t_ok('14c mcq matching is case-insensitive',
     public.answer_matches('mcq','"b"','"B"'));
  perform public.t_ok('14d a blank or missing response is never correct',
     not public.answer_matches('mcq','""','"B"')
     and not public.answer_matches('grid_in', null, '["3"]'));
  perform public.t_ok('14e a wrong grid-in value is rejected',
     not public.answer_matches('grid_in','"0.8"','["3/4"]'));
  perform public.t_ok('14f division by zero in a response does not error',
     not public.answer_matches('grid_in','"1/0"','["3/4"]'));
end $$;

-- =====================================================================
-- 15  The delivery payload never contains an answer key.
-- =====================================================================
do $$ declare u uuid := public.tid('s15'); p jsonb; txt text; begin
  p := public.attempt_payload(
         (select id from public.attempts where user_id = u order by started_at desc limit 1), u);
  txt := p::text;
  perform public.t_ok('15 attempt_payload carries no correct answer or explanation',
                      txt not like '%"correct"%' and txt not like '%"explanation"%'
                      and txt like '%"questions"%',
                      format('bytes=%s', length(txt)));
end $$;

-- ---------------------------------------------------------------------
select n,
       case when ok then 'PASS' else '**FAIL**' end as result,
       label, detail
  from public.test_results order by n;

do $$ declare f int; t int; begin
  select count(*) filter (where not ok), count(*) into f, t from public.test_results;
  if f > 0 then
    raise exception '% of % ACCEPTANCE TESTS FAILED: %', f, t, (select string_agg(label||': '||detail,'; ') from test_results where not ok);
  end if;
  raise notice 'ALL % ACCEPTANCE TESTS PASSED', t;
end $$;

-- Teardown: leave no test scaffolding behind, even if this was run on the
-- wrong database by mistake. Comment out if you want to inspect fixtures.

