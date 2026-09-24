begin;
do $$
declare u uuid:=gen_random_uuid(); e uuid; a attempts%rowtype; paper record; j jsonb; n int:=0; staff uuid:=gen_random_uuid();
begin
 assert (select count(*)=119 from questions where assets->>'source_bank'='est-september-2026');
 assert (select count(*)=949 from est_source_review);
 assert (select count(*)=390 from est_source_review where question_id is not null);
 assert not exists(select 1 from questions q left join question_keys k on k.question_id=q.id where q.assets->>'source_bank'='est-september-2026' and(k.question_id is null or btrim(k.explanation)=''));
 assert not exists(select 1 from questions where assets->>'source_bank'='est-september-2026' and assets->>'source_code' in ('PSD 202','MIX 024','MIX 025'));
 insert into auth.users(id,email) values(u,u::text||'@qa.invalid'),(staff,staff::text||'@qa.invalid');
 insert into profiles(id,role) values(u,'student'),(staff,'admin');
 insert into enrollments(user_id,track_id) values(u,'est');
 perform set_config('test.est_student',u::text,true);perform set_config('test.est_staff',staff::text,true);
 for paper in select * from exams where title in('EST Math 1 — Question Bank Practice 06','EST Math 1 — Question Bank Practice 07') loop
  n:=n+1;e:=gen_random_uuid();
  assert paper.duration_seconds=4500 and cardinality(paper.question_ids)=50;
  assert (select count(distinct id)=50 from unnest(paper.question_ids) ids(id));
  assert (select count(*)=15 from questions where id=any(paper.question_ids) and assets->>'domain'='FA');
  assert (select count(*)=15 from questions where id=any(paper.question_ids) and assets->>'domain'='DAP');
  assert (select count(*)=15 from questions where id=any(paper.question_ids) and assets->>'domain'='AAF');
  assert (select count(*)=5 from questions where id=any(paper.question_ids) and assets->>'domain'='GT');
  insert into exams(id,track_id,title,duration_seconds,question_ids,shuffle,is_published,is_full_length,review_policy,assessment_type)
   values(e,'est','QA September bank',4500,paper.question_ids,false,true,true,'full_review','full_exam');
  insert into assignments(exam_id,user_id) values(e,u);
  a=public.start_attempt(e,u);
  assert extract(epoch from(a.deadline_at-a.started_at))=4500;
  j=public.attempt_payload(a.id,u);
  assert jsonb_array_length(j->'questions')=50;
  assert j::text not like '%"correct"%' and j::text not like '%"explanation"%' and j::text not like '%image_key_base64%';
  begin
   perform public.attempt_review(a.id,u);raise exception 'live review unexpectedly allowed';
  exception when raise_exception then if sqlerrm<>'attempt_still_live' then raise;end if;end;
  insert into attempt_answers(attempt_id,question_id,response) select a.id,k.question_id,k.correct from question_keys k where k.question_id=any(paper.question_ids);
  a=public.submit_attempt(a.id,u);
  assert a.score=50 and a.total=50 and a.status='graded' and a.scaled_score is null;
  j=public.attempt_review(a.id,u);assert(j->>'review_open')::boolean and jsonb_array_length(j->'items')=50;
 end loop;
 assert n=2;
 assert not has_table_privilege('anon','public.est_source_review','SELECT');
 assert not has_table_privilege('authenticated','public.est_source_review','UPDATE');
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.est_student'),true);
set local role authenticated;
do $$ begin assert(select count(*)=0 from public.est_source_review);end $$;
reset role;
select set_config('request.jwt.claim.sub',current_setting('test.est_staff'),true);
set local role authenticated;
do $$ begin assert(select count(*)=949 from public.est_source_review);end $$;
reset role;
select 'PASS:two complete graded75-minute papers;949 instructor records;student and anonymous archive access blocked;keys private;all fixtures rolled back.' as result;
rollback;
