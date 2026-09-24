-- =====================================================================
--  ADVERSARIAL SUITE — a signed-in student trying to escalate.
--  Run AFTER tests/rls_test.sql (it reuses that script's fixtures).
--  Every check must report PASS = the attack was refused.
--  Abdelrahman Ghoneem | 01116004434
-- =====================================================================
-- Self-sufficient: rls_test.sql tears down its own helpers, so re-declare
-- the fixture lookup here rather than depending on load order.
create or replace function public.tid(p_k text) returns uuid
language sql stable as $$ select v from public.test_ids where k = p_k $$;

create table if not exists public.adv_results(
  n serial, label text, result text, detail text);
truncate public.adv_results;

create or replace function public.adv(p_label text, p_blocked boolean, p_detail text default '')
returns void language plpgsql as $$
begin
  insert into public.adv_results(label, result, detail)
  values (p_label, case when p_blocked then 'PASS' else '*** FAIL ***' end, p_detail);
end $$;

-- The victim: a student enrolled in EST only.
do $$
declare
  me      uuid := public.tid('est_only');
  other   uuid := public.tid('sat_only');
  v_exam  uuid := public.tid('e_sat');
  v_q     uuid := public.tid('qa');
  blocked boolean;
  msg     text;
  n       integer;
begin
  -- ---------- 1. self-enrol into the SAT track ----------
  perform public.test_login(me);
  begin
    insert into public.enrollments(user_id, track_id, status)
    values (me, 'sat', 'active');
    blocked := false; msg := 'INSERT SUCCEEDED';
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student self-enrols into SAT', blocked, msg);

  -- ---------- 2. promote self to admin ----------
  perform public.test_login(me);
  begin
    update public.profiles set role = 'admin' where id = me;
    get diagnostics n = row_count;
    blocked := (n = 0); msg := 'rows_updated=' || n;
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student promotes self to admin', blocked, msg);

  -- ---------- 3. write an answer key ----------
  perform public.test_login(me);
  begin
    insert into public.question_keys(question_id, correct, explanation)
    values (public.tid('qd'), '"A"', 'injected');
    blocked := false; msg := 'INSERT SUCCEEDED';
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student writes an answer key', blocked, msg);

  -- ---------- 4. overwrite an existing key ----------
  perform public.test_login(me);
  begin
    update public.question_keys set correct = '"A"' where question_id = v_q;
    get diagnostics n = row_count;
    blocked := (n = 0); msg := 'rows_updated=' || n;
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student overwrites an answer key', blocked, msg);

  -- ---------- 5. edit a question ----------
  perform public.test_login(me);
  begin
    update public.questions set stem = 'hacked' where id = v_q;
    get diagnostics n = row_count;
    blocked := (n = 0); msg := 'rows_updated=' || n;
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student edits a question', blocked, msg);

  -- ---------- 6. make self an instructor on SAT ----------
  perform public.test_login(me);
  begin
    insert into public.instructor_tracks(user_id, track_id) values (me, 'sat');
    blocked := false; msg := 'INSERT SUCCEEDED';
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student grants self instructor rights', blocked, msg);

  -- ---------- 7. self-assign a SAT exam ----------
  perform public.test_login(me);
  begin
    insert into public.assignments(exam_id, user_id) values (v_exam, me);
    blocked := false; msg := 'INSERT SUCCEEDED';
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student self-assigns a SAT exam', blocked, msg);

  -- ---------- 8. grant self a retake ----------
  perform public.test_login(me);
  begin
    insert into public.retake_grants(user_id, exam_id, granted_by, reason)
    values (me, public.tid('e_est'), me, 'self');
    blocked := false; msg := 'INSERT SUCCEEDED';
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student grants self a retake', blocked, msg);

  -- ---------- 9. publish an unpublished exam ----------
  perform public.test_login(me);
  begin
    update public.exams set is_published = true where id = v_exam;
    get diagnostics n = row_count;
    blocked := (n = 0); msg := 'rows_updated=' || n;
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student republishes an exam', blocked, msg);

  -- ---------- 10. rewrite the scoring scale ----------
  perform public.test_login(me);
  begin
    update public.tracks set scoring = '{"type":"linear","min":800,"max":800}' where id = 'est';
    get diagnostics n = row_count;
    blocked := (n = 0); msg := 'rows_updated=' || n;
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student rewrites the scoring scale', blocked, msg);

  -- ---------- 11. write a grade directly ----------
  perform public.test_login(me);
  begin
    insert into public.attempt_results(attempt_id, question_id, is_correct, awarded)
    select a.id, v_q, true, 1 from public.attempts a where a.user_id = me limit 1;
    blocked := false; msg := 'INSERT SUCCEEDED';
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student writes their own grade', blocked, msg);

  -- ---------- 12. read another student''s attempts ----------
  perform public.test_login(me);
  select count(*) into n from public.attempts where user_id = other;
  reset role;
  perform public.adv('student reads another student''s attempts', n = 0, 'rows=' || n);

  -- ---------- 13. answer into another student''s attempt ----------
  perform public.test_login(me);
  begin
    insert into public.attempt_answers(attempt_id, question_id, response)
    select a.id, v_q, '"A"' from public.attempts a
     where a.user_id = other and a.status = 'in_progress' limit 1;
    get diagnostics n = row_count;
    blocked := (n = 0); msg := 'rows_inserted=' || n;
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student answers into another''s attempt', blocked, msg);

  -- ---------- 14. delete an attempt to reset the limit ----------
  perform public.test_login(me);
  begin
    delete from public.attempts where user_id = me;
    get diagnostics n = row_count;
    blocked := (n = 0); msg := 'rows_deleted=' || n;
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student deletes an attempt to reset the limit', blocked, msg);

  -- ---------- 15. reach a key by joining through questions ----------
  perform public.test_login(me);
  select count(*) into n
    from public.questions q join public.question_keys k on k.question_id = q.id;
  reset role;
  perform public.adv('student reaches keys via a join', n = 0, 'rows=' || n);

  -- ---------- 16. call the privileged RPC directly ----------
  perform public.test_login(me);
  begin
    perform public.grant_retake(me, public.tid('e_est'), me, 'self-service');
    blocked := false; msg := 'RPC SUCCEEDED';
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student calls grant_retake() directly', blocked, msg);

  -- ---------- 17. start an attempt as somebody else ----------
  perform public.test_login(me);
  begin
    perform public.start_attempt(public.tid('e_est'), other);
    blocked := false; msg := 'RPC SUCCEEDED';
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student starts an attempt as another user', blocked, msg);

  -- ---------- 18. read the audit log ----------
  perform public.test_login(me);
  select count(*) into n from public.audit_log;
  reset role;
  perform public.adv('student reads the audit log', n = 0, 'rows=' || n);

  -- ---------- 19. burn another student's attempt ----------
  perform public.test_login(me);
  begin
    perform public.start_attempt(public.tid('e_est'), public.tid('both'));
    blocked := false; msg := 'RPC SUCCEEDED';
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student burns another student''s attempt', blocked, msg);

  -- ---------- 20. read another student's exam list and scores ----------
  perform public.test_login(me);
  begin
    perform public.my_exams(public.tid('both'), 'sat');
    blocked := false; msg := 'RPC SUCCEEDED';
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student reads another student''s exam list', blocked, msg);

  -- ---------- 21a. read the staff roster ----------
  perform public.test_login(me);
  select count(*) into n from public.roster;
  reset role;
  perform public.adv('student reads the staff roster', n = 0, 'rows=' || n);

  -- ---------- 21b. read every student's results ----------
  perform public.test_login(me);
  select count(*) into n from public.results_feed;
  reset role;
  perform public.adv('student reads the results feed', n = 0, 'rows=' || n);

  -- ---------- 21c. read cohort question analytics ----------
  perform public.test_login(me);
  select count(*) into n from public.question_difficulty;
  reset role;
  perform public.adv('student reads question analytics', n = 0, 'rows=' || n);

  -- ---------- 21d. read every student's weak lessons ----------
  perform public.test_login(me);
  select count(*) into n from public.student_by_lesson;
  reset role;
  perform public.adv('student reads per-student lesson analytics', n = 0, 'rows=' || n);

  -- ---------- 22. grade an attempt on demand ----------
  perform public.test_login(me);
  begin
    perform public.sweep_expired_attempts();
    blocked := false; msg := 'RPC SUCCEEDED';
  exception when others then blocked := true; msg := sqlerrm; end;
  reset role;
  perform public.adv('student runs the sweeper', blocked, msg);
end $$;

select n, result, label, detail from public.adv_results order by n;

do $$
declare bad integer;
begin
  select count(*) into bad from public.adv_results where result <> 'PASS';
  if bad = 0 then
    raise notice 'ALL % ESCALATION ATTEMPTS WERE REFUSED', (select count(*) from public.adv_results);
  else
    raise exception '% ATTACKS SUCCEEDED - DO NOT DEPLOY', bad;
  end if;
end $$;

drop function if exists public.adv(text, boolean, text);
drop function if exists public.tid(text);