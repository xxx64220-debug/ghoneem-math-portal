-- Use only in an outer transaction ending in ROLLBACK, after the test key load.
do $$
declare u uuid:=gen_random_uuid(); e uuid:=gen_random_uuid(); a attempts%rowtype; j jsonb; q23 uuid; n int;
begin
 assert public.answer_matches('mcq','"b"','["B","D"]');
 assert public.answer_matches('mcq','"D"','["B","D"]');
 assert not public.answer_matches('mcq','"C"','["B","D"]');
 assert not public.answer_matches('mcq',null,'["B","D"]');
 assert not public.answer_matches('mcq','"A"','{"void":true}');
 assert public.answer_matches('grid_in','"0.75"','["3/4"]');
 assert public.answer_matches('mcq','"A"','"A"');
 insert into auth.users(id,email) values(u,u::text||'@qa.invalid');
 insert into profiles(id,role) values(u,'student');
 insert into enrollments(user_id,track_id) values(u,'est');
 insert into exams(id,track_id,title,duration_seconds,question_ids,shuffle,is_published,is_full_length,review_policy)
 select e,'est','QA worked key',4500,question_ids,false,true,true,'full_review' from exams where id='67a68471-59b3-5bf1-8a80-21ce851bef5f';
 insert into assignments(exam_id,user_id) values(e,u);
 a=public.start_attempt(e,u);
 j=public.attempt_payload(a.id,u);
 assert jsonb_array_length(j->'questions')=50;
 assert extract(epoch from(a.deadline_at-a.started_at))=4500;
 assert j::text not like '%"correct"%' and j::text not like '%"explanation"%' and j::text not like '%"void"%';
 insert into attempt_answers(attempt_id,question_id,response)
 select a.id,qid,case when jsonb_typeof(k.correct)='array' then k.correct->0 else k.correct end
 from exams ex cross join lateral unnest(ex.question_ids) u(qid) join question_keys k on k.question_id=qid
 where ex.id=e and not(k.correct @> '{"void":true}');
 a=public.submit_attempt(a.id,u);
 assert a.score=48 and a.total=48 and a.status='graded' and a.scaled_score is null;
 assert (select count(*) from attempt_results where attempt_id=a.id)=48;
 j=public.attempt_review(a.id,u);
 assert (j->>'review_open')::boolean and jsonb_array_length(j->'items')=50;
 assert (select count(*) from jsonb_array_elements(j->'items') q where q->'correct' @> '{"void":true}')=2;
 j=public.student_dashboard(u,'est');
 assert (select sum((q->>'seen')::int) from jsonb_array_elements(j->'lessons') q)=48;
 select q.id into q23 from questions q join exams ex on q.id=any(ex.question_ids) where ex.id=e and (q.assets->>'source_question')::int=23;
 update attempts set status='in_progress' where id=a.id;
 update attempt_answers set response='"D"' where attempt_id=a.id and question_id=q23;
 a=public.submit_attempt(a.id,u);
 assert a.score=48 and a.total=48;
 update attempts set status='in_progress' where id=a.id;
 update attempt_answers set response='"C"' where attempt_id=a.id and question_id=q23;
 a=public.submit_attempt(a.id,u);
 assert a.score=47 and a.total=48;
 update attempts set status='in_progress' where id=a.id;
 update attempt_answers set response='null'::jsonb where attempt_id=a.id;
 a=public.submit_attempt(a.id,u);
 assert a.score=0 and a.total=48;
 update attempts set status='expired' where id=a.id;
 a=public.grade_attempt(a.id);
 assert a.status='expired';
 assert not has_function_privilege('authenticated','public.grade_attempt(uuid)','execute');
 assert not has_function_privilege('anon','public.answer_matches(text,jsonb,jsonb)','execute');
end $$;
select 'PASS: actual 50-question key, 48-point scores, both Q23 choices, exclusions absent from accuracy, blank answers, review, expiry and key secrecy' as result;
