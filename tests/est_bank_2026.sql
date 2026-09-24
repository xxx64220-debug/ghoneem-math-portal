-- Every fixture and temporary publication below is rolled back.
begin;
do $$
declare u uuid:=gen_random_uuid(); e uuid; a attempts%rowtype; paper record; j jsonb; n int;
begin
 assert (select count(*)=271 from questions where assets->>'source_bank'='est-reviewed-banks-2026');
 assert not exists(select 1 from questions q left join question_keys k on k.question_id=q.id
   where q.assets->>'source_bank'='est-reviewed-banks-2026' and (k.question_id is null or btrim(k.explanation)=''));
 assert (select k.correct='"B"' from question_keys k join questions q on q.id=k.question_id
   where q.assets->>'source_bank'='est-reviewed-banks-2026' and q.assets->>'source_code'='AAF 041');
 assert (select k.correct='"A"' from question_keys k join questions q on q.id=k.question_id
   where q.assets->>'source_bank'='est-reviewed-banks-2026' and q.assets->>'source_code'='GT 021');
 assert not exists(select 1 from questions where assets->>'source_bank'='est-reviewed-banks-2026'
   and assets->>'source_code' in ('FA 045','DAP 011','DAP 015','AAF 056','AAF 057','AAF 065','AAF 067','AAF 072','GT 022'));
 assert public.answer_matches('grid_in','"3.125"','"25/8"');
 assert public.answer_matches('grid_in','"0.5"','"1/2"');
 assert not public.answer_matches('grid_in','"3.12"','"25/8"');
 insert into auth.users(id,email) values(u,u::text||'@qa.invalid');
 insert into profiles(id,role) values(u,'student');
 insert into enrollments(user_id,track_id) values(u,'est');
 n:=0;
 for paper in select * from exams where track_id='est' and title like 'EST Math 1 — Question Bank Practice %' loop
  n:=n+1;e:=gen_random_uuid();
  assert not paper.is_published;
  assert paper.duration_seconds=4500 and cardinality(paper.question_ids)=50;
  assert (select count(distinct id)=50 from unnest(paper.question_ids) ids(id));
  assert (select count(*)=15 from questions where id=any(paper.question_ids) and assets->>'domain'='FA');
  assert (select count(*)=15 from questions where id=any(paper.question_ids) and assets->>'domain'='DAP');
  assert (select count(*)=15 from questions where id=any(paper.question_ids) and assets->>'domain'='AAF');
  assert (select count(*)=5 from questions where id=any(paper.question_ids) and assets->>'domain'='GT');
  insert into exams(id,track_id,title,duration_seconds,question_ids,shuffle,is_published,is_full_length,review_policy,assessment_type)
   values(e,'est','QA EST bank paper',4500,paper.question_ids,false,true,true,'full_review','full_exam');
  insert into assignments(exam_id,user_id) values(e,u);
  a=public.start_attempt(e,u);
  assert extract(epoch from(a.deadline_at-a.started_at))=4500;
  j=public.attempt_payload(a.id,u);
  assert jsonb_array_length(j->'questions')=50;
  assert j::text not like '%"correct"%' and j::text not like '%"explanation"%';
  begin
   perform public.attempt_review(a.id,u);
   raise exception 'live review unexpectedly allowed';
  exception when raise_exception then
   if sqlerrm <> 'attempt_still_live' then raise; end if;
  end;
  insert into attempt_answers(attempt_id,question_id,response)
   select a.id,k.question_id,k.correct from question_keys k where k.question_id=any(paper.question_ids);
  a=public.submit_attempt(a.id,u);
  assert a.score=50 and a.total=50 and a.status='graded' and a.scaled_score is null;
  j=public.attempt_review(a.id,u);
  assert (j->>'review_open')::boolean and jsonb_array_length(j->'items')=50;
  assert not exists(select 1 from jsonb_array_elements(j->'items') item
    where item->'correct' is null or btrim(item->>'explanation')='');
 end loop;
 assert n=5;
 begin
  perform public.student_dashboard(u,'sat');
  raise exception 'unenrolled SAT dashboard unexpectedly allowed';
 exception when raise_exception then
  if sqlerrm <> 'not_enrolled_in_track' then raise; end if;
 end;
 assert not has_function_privilege('authenticated','public.grade_attempt(uuid)','execute');
end $$;
select 'PASS: five 50-question papers, 4500-second server deadlines, exact 15/15/15/5 balance, corrected keys, full-score grading, locked in-progress review, released explanations, fraction answers and track isolation' as result;
rollback;
