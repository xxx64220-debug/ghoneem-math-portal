-- Read-model and categorization regression tests. Always execute within ROLLBACK.
do $$
declare u uuid:=gen_random_uuid(); other_ uuid:=gen_random_uuid(); adm uuid:=gen_random_uuid();
 ids uuid[]:='{}'; qid uuid; e uuid:=gen_random_uuid(); locked uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
 j jsonb; l jsonb; n int; msg text; category_ text;
begin
 insert into auth.users(id,email) values(u,u::text||'@qa.invalid'),(other_,other_::text||'@qa.invalid'),(adm,adm::text||'@qa.invalid');
 insert into profiles(id,role) values(u,'student'),(other_,'student'),(adm,'admin');
 insert into enrollments(user_id,track_id) values(u,'sat'),(other_,'est');
 for n in 1..7 loop
  qid=gen_random_uuid();ids=array_append(ids,qid);
  insert into questions(id,track_id,topic,type,stem) values(qid,'sat',case when n<=3 then 'QA Focus' when n<=6 then 'QA Strong' else 'QA Little evidence' end,'grid_in','QA only');
  insert into question_keys values(qid,'["1"]','QA explanation');
 end loop;
 insert into exams(id,track_id,title,duration_seconds,question_ids,is_published,assessment_type) values(e,'sat','QA lesson',600,ids,true,'lesson_exam');
 insert into assignments(exam_id,user_id) values(e,u);
 insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,status,deadline_at,submitted_at,review_unlocks_at,score,total) values(a,u,e,1,1,'graded',now(),now()-interval '1 hour',now()-interval '1 minute',5,7);
 insert into attempt_results select a,id,ord=1 or ord>=4,case when ord=1 or ord>=4 then 1 else 0 end from unnest(ids) with ordinality as t(id,ord);
 j=student_dashboard(u,'sat');
 if (j->'summary'->>'completed')::int<>1 or jsonb_array_length(j->'history')<>1 then raise exception 'history_count'; end if;
 select x into l from jsonb_array_elements(j->'lessons') x where x->>'lesson'='QA Focus';
 if l->>'priority'<>'focus' or (l->>'seen')::int<>3 then raise exception 'focus_classification'; end if;
 select x into l from jsonb_array_elements(j->'lessons') x where x->>'lesson'='QA Strong';
 if l->>'priority' is distinct from 'strong' then raise exception 'strong_classification'; end if;
 update attempt_results set is_correct=true,awarded=1 where attempt_id=a and question_id=ids[2];
 update attempts set score=6 where id=a;
 j=student_dashboard(u,'sat');select x into l from jsonb_array_elements(j->'lessons') x where x->>'lesson'='QA Focus';
 if l->>'priority' is distinct from 'practice' then raise exception 'practice_classification'; end if;
 select x into l from jsonb_array_elements(j->'lessons') x where x->>'lesson'='QA Little evidence';
 if l->>'priority'<>'more_evidence' then raise exception 'insufficient_evidence_classification'; end if;
 begin perform student_dashboard(other_,'sat');exception when others then msg=sqlerrm;end;
 if msg is distinct from 'not_enrolled_in_track' then raise exception 'track_isolation'; end if;
 if jsonb_array_length(student_dashboard(other_,'est')->'history')<>0 then raise exception 'other_student_history'; end if;
 -- A retake replaces each question's evidence while both attempts remain in history.
 insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,status,deadline_at,submitted_at,review_unlocks_at,score,total) values(b,u,e,2,2,'graded',now(),now(),now()-interval '1 minute',7,7);
 insert into attempt_results select b,id,true,1 from unnest(ids) id;
 j=student_dashboard(u,'sat');select x into l from jsonb_array_elements(j->'lessons') x where x->>'lesson'='QA Focus';
 if l->>'priority'<>'strong' or (l->>'seen')::int<>3 or jsonb_array_length(j->'history')<>2 then raise exception 'retake_progress_and_history'; end if;
 -- Even unpublished completed assessments remain in the student's history.
 update exams set is_published=false where id=e;
 if jsonb_array_length(student_dashboard(u,'sat')->'history')<>2 then raise exception 'unpublished_history_lost'; end if;
 -- Category changes are permitted after completion, are audited, and do not change grades.
 perform portal_admin(adm,'exam.classify',jsonb_build_object('id',e,'assessment_type','quiz'));
 j=student_dashboard(u,'sat');if j->'history'->0->>'assessment_type'<>'quiz' or (j->'history'->0->>'score')::int<>7 then raise exception 'category_change'; end if;
 if not exists(select 1 from audit_log where actor_id=adm and action='exam.classify') then raise exception 'category_audit'; end if;
 -- Locked correctness never contributes to lesson diagnostics.
 qid=gen_random_uuid();insert into questions(id,track_id,topic,type,stem) values(qid,'sat','QA Locked','grid_in','QA locked');insert into question_keys values(qid,'["1"]','Secret');
 insert into exams(id,track_id,title,duration_seconds,question_ids,is_published) values(locked,'sat','QA locked',600,array[qid],true);
 insert into assignments(exam_id,user_id,close_at) values(locked,u,now()+interval '1 day');
 a=gen_random_uuid();insert into attempts(id,user_id,exam_id,attempt_no,shuffle_seed,status,deadline_at,submitted_at,review_unlocks_at,score,total) values(a,u,locked,1,3,'graded',now(),now(),now()+interval '1 day',1,1);
 insert into attempt_results values(a,qid,true,1);
 j=student_dashboard(u,'sat');select x into l from jsonb_array_elements(j->'lessons') x where x->>'lesson'='QA Locked';
 if (l->>'seen')::int<>0 or l->>'priority'<>'not_started' or (j->'summary'->>'review_pending')::int<>1 then raise exception 'locked_review_leak'; end if;
 if j::text like '%Secret%' or j::text like '%"question_id"%' then raise exception 'key_or_question_leak'; end if;
 if has_function_privilege('authenticated','student_dashboard(uuid,text)','execute') then raise exception 'rpc_exposed'; end if;
end $$;
select 'PASS: history, focus ratings, retakes, categories, audit, track and student isolation, locked review protection' as result;
