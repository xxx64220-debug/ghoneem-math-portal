-- Run inside a transaction ending in ROLLBACK. No real student attempts.
do $$
declare u uuid:=gen_random_uuid(); q uuid:=gen_random_uuid(); e uuid:=gen_random_uuid();
 a public.attempts%rowtype; j jsonb; r jsonb;
begin
 insert into auth.users(id,email) values(u,u::text||'@qa.invalid');
 insert into profiles(id,role) values(u,'student');
 insert into enrollments(user_id,track_id) values(u,'est');
 insert into questions(id,track_id,type,stem,choices,topic) values(q,'est','mcq','QA pending key','[{"key":"A","text":"1"},{"key":"B","text":"2"}]','QA pending');
 insert into question_keys values(q,'null'::jsonb,'Pending');
 insert into exams(id,track_id,title,duration_seconds,question_ids,shuffle,is_published,is_full_length,review_policy)
 values(e,'est','QA pending',4500,array[q],false,true,true,'instructor_release');
 insert into assignments(exam_id,user_id) values(e,u);
 a=public.start_attempt(e,u);
 if extract(epoch from(a.deadline_at-a.started_at))<>4500 then raise exception 'wrong_duration'; end if;
 j=public.attempt_payload(a.id,u);
 if j::text like '%"correct"%' or j::text like '%"explanation"%' then raise exception 'answer_key_leak'; end if;
 if (j->'exam'->>'shuffle')::boolean then raise exception 'unexpected_shuffle'; end if;
 insert into attempt_answers(attempt_id,question_id,response) values(a.id,q,'"A"'::jsonb);
 a=public.submit_attempt(a.id,u);
 if a.status<>'submitted' or a.score is not null or a.scaled_score is not null or a.total<>1 then raise exception 'pending_score_incorrect'; end if;
 if exists(select 1 from attempt_results where attempt_id=a.id) then raise exception 'false_question_marks'; end if;
 if not exists(select 1 from attempt_answers where attempt_id=a.id and response='"A"'::jsonb) then raise exception 'response_lost'; end if;
 j=public.attempt_review(a.id,u);
 if (j->>'review_open')::boolean or jsonb_array_length(j->'items')<>0 then raise exception 'pending_review_leak'; end if;
 j=public.student_dashboard(u,'est');
 if jsonb_array_length(j->'history')<>1 or j->'summary'->>'average_percent' is not null then raise exception 'pending_dashboard_incorrect'; end if;
 if exists(select 1 from jsonb_array_elements(j->'lessons') l where (l->>'seen')::int<>0) then raise exception 'pending_lesson_contamination'; end if;
 -- A verified key can grade a retained submission without a retake.
 update question_keys set correct='"A"'::jsonb where question_id=q;
 a=public.grade_attempt(a.id);
 if a.score<>1 or a.total<>1 or a.status<>'graded' then raise exception 'verified_key_did_not_grade'; end if;
 -- Expiry preserves all responses and uses the same pending-key behavior.
 update question_keys set correct='null'::jsonb where question_id=q;
 update attempts set status='in_progress',score=null,started_at=now()-interval '76 minutes',deadline_at=now()-interval '1 minute',submitted_at=null where id=a.id;
 perform public.finalize_expired_for(u,e);
 select * into a from attempts where id=a.id;
 if a.status<>'expired' or a.score is not null or a.total<>1 or a.time_used<>4500 then raise exception 'expiry_failed'; end if;
 if exists(select 1 from attempt_results where attempt_id=a.id) then raise exception 'expiry_false_marks'; end if;
 if has_function_privilege('authenticated','public.grade_attempt(uuid)','execute') or has_function_privilege('anon','public.attempt_review(uuid,uuid)','execute') then raise exception 'private_rpc_exposed'; end if;
end $$;
select 'PASS: 75-minute timer, keyless payload, saved submission, pending grading, history, lesson isolation, later grading and expiry' as result;
