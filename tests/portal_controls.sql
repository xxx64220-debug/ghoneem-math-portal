-- Uses disposable rows and rolls back every write, including revision sessions.
begin;
set local role service_role;
do $$
declare u uuid; a uuid; q uuid; q2 uuid; ids uuid[]:='{}'; more_ids uuid[]:='{}'; r jsonb; s jsonb; cfg jsonb; rid uuid:=gen_random_uuid(); sid uuid; n int; today_ date:=(now() at time zone 'Africa/Cairo')::date;
begin
 select id into u from public.profiles where role='student' and status='active' and public.is_enrolled(id,'est2') limit 1;
 select id into a from public.profiles where role='admin' and status='active' limit 1;
 assert u is not null and a is not null,'active EST II student and admin fixtures required';
 r:=public.final_revision(u,'est2','catalogue');
 assert jsonb_array_length(r->'items')=416,'EST II count';
 assert not exists(select 1 from jsonb_array_elements(r->'items') x where x->>'source'<>'est2' or x ?| array['correct','explanation','stem']),'scope or key leak';
 s:=public.final_revision(u,'est2','start','{"count":20,"source":"sat","scope":"sat","collection":"priority"}');
 sid:=(s->>'id')::uuid;q:=(s->'questions'->0->>'id')::uuid;
 assert jsonb_array_length(s->'questions')=20,'EST II set size';
 assert (select count(distinct(x->>'lesson',x->>'idea')) from jsonb_array_elements(s->'questions') x)=20,'repeated idea in priority';
 assert not exists(select 1 from jsonb_array_elements(s->'questions') x where x->>'source'<>'est2' or x ?| array['correct','explanation'] or x->'feedback'<>'null'::jsonb),'EST II source/key isolation';
 perform public.portal_manage(a,'revision.visibility','{"track":"est2","visible":false}');
 assert not (public.portal_student_controls(u,'settings','{"track":"est2"}')->>'revision_visible')::boolean,'hidden setting';
 begin perform public.final_revision(u,'est2','state',jsonb_build_object('session',sid));raise exception 'visibility bypass';exception when others then if sqlerrm<>'revision_hidden' then raise;end if;end;
 perform public.portal_manage(a,'revision.visibility','{"track":"est2","visible":true}');
 perform public.portal_manage(a,'revision.release',jsonb_build_object('track','est2','ids',array[q],'active',false));
 r:=public.final_revision(u,'est2','catalogue');
 assert jsonb_array_length(r->'items')=415,'release filtering';
 assert jsonb_array_length(public.final_revision(u,'est2','state',jsonb_build_object('session',sid))->'questions')=20,'saved revision retained';
 begin perform public.portal_manage(u,'revision.visibility','{"track":"est2","visible":false}');raise exception 'student staff bypass';exception when others then if sqlerrm<>'staff_required' then raise;end if;end;
 r:=public.portal_student_controls(u,'report',jsonb_build_object('track','est2','kind','question','question_id',q,'request_id',rid,'message','Please check this test question.','screen','test'));
 assert r=public.portal_student_controls(u,'report',jsonb_build_object('track','est2','kind','question','question_id',q,'request_id',rid,'message','Please check this test question.')),'report retry not idempotent';
 assert (select count(*) from public.portal_reports where user_id=u and request_id=rid)=1,'duplicate report';
 perform public.portal_manage(a,'reports.update',jsonb_build_object('track','est2','id',r->>'id','status','resolved','note','Test transaction only'));
 assert exists(select 1 from public.portal_reports where id=(r->>'id')::uuid and status='resolved'),'report resolution';
 select id into q2 from public.questions where track_id='est' limit 1;
 begin perform public.portal_student_controls(u,'report',jsonb_build_object('track','est2','kind','question','question_id',q2,'request_id',gen_random_uuid(),'message','Wrong track must be rejected.'));raise exception 'report track bypass';exception when others then if sqlerrm<>'question_track_mismatch' then raise;end if;end;
 -- Isolated daily track: no existing student scores or frozen quizzes are changed.
 insert into public.tracks(id,name) values('controls_test','Disposable controls test');
 insert into public.portal_track_controls(track_id) values('controls_test');
 insert into public.enrollments(user_id,track_id) values(u,'controls_test');
 for n in 1..10 loop
  insert into public.questions(track_id,topic,stem,choices,assets) values('controls_test',case when n<=5 then 'Lesson A' else 'Lesson B' end,'Disposable question '||n,'[{"key":"A","text":"1"},{"key":"B","text":"2"},{"key":"C","text":"3"},{"key":"D","text":"4"}]','{"verified_release":"test"}') returning id into q;
  insert into public.question_keys(question_id,correct,explanation) values(q,'"A"','A is correct in this test fixture.');
  if n<=5 then ids:=array_append(ids,q);else more_ids:=array_append(more_ids,q);end if;
 end loop;
 begin perform public.portal_manage(a,'quiz.save',jsonb_build_object('track','controls_test','mode','selected','ids',ids[1:4]));raise exception 'small pool accepted';exception when others then if sqlerrm<>'select_at_least_five_questions' then raise;end if;end;
 perform public.portal_manage(a,'quiz.save',jsonb_build_object('track','controls_test','mode','selected','ids',ids));
 s:=public.daily_state(u,'controls_test');
 assert jsonb_array_length(s->'quiz')=5 and not exists(select 1 from jsonb_array_elements(s->'quiz') x where not (x->>'id')::uuid=any(ids) or x->'answer'<>'null'::jsonb),'fixed question selection';
 cfg:=public.portal_manage(a,'quiz.save','{"track":"controls_test","mode":"lessons","lessons":["Lesson B"]}');
 assert (cfg->>'today_frozen')::boolean,'opened quiz not frozen';
 assert (public.daily_state(u,'controls_test')->'quiz')=(s->'quiz'),'pool edit changed opened quiz';
 r:=public.daily_submit(u,'controls_test',(select jsonb_object_agg(x::text,'A') from unnest(ids) x));
 assert (select quiz_score=5 and points>=60 from public.daily_progress where user_id=u and track_id='controls_test' and day=today_),'quiz score';
 update public.daily_progress set focus_done=true,review_done=true where user_id=u and track_id='controls_test';
 begin perform public.portal_manage(a,'quiz.reset',jsonb_build_object('track','controls_test','user_id',u,'mode','quiz','day',today_));raise exception 'reset without confirmation';exception when others then if sqlerrm<>'reset_confirmation_required' then raise;end if;end;
 r:=public.portal_manage(a,'quiz.reset',jsonb_build_object('track','controls_test','user_id',u,'mode','quiz','day',today_,'confirm','RESET'));
 assert (select quiz_completed_at is null and quiz_score is null and points=0 and answers='{}' and focus_done and review_done from public.daily_progress where user_id=u and track_id='controls_test' and day=today_),'quiz reset scope';
 assert exists(select 1 from public.daily_reset_archive where track_id='controls_test' and (previous_progress->0->>'quiz_score')::int=5),'score archive missing';
 perform public.portal_manage(a,'quiz.reset',jsonb_build_object('track','controls_test','user_id',u,'mode','all','range','all','confirm','RESET'));
 assert not exists(select 1 from public.daily_progress where user_id=u and track_id='controls_test'),'full reset failed';
 -- With no opened progress left, a saved pool may replace today's questions.
 perform public.portal_manage(a,'quiz.save','{"track":"controls_test","mode":"lessons","lessons":["Lesson B"]}');
 s:=public.daily_state(u,'controls_test');
 assert not exists(select 1 from jsonb_array_elements(s->'quiz') x where not (x->>'id')::uuid=any(more_ids)),'lesson selection';
 -- Instructor access remains limited to assigned tracks and their own students.
 update public.profiles set role='instructor' where id=u;
 insert into public.instructor_tracks(user_id,track_id) values(u,'controls_test') on conflict do nothing;
 begin perform public.portal_manage(u,'quiz.reset',jsonb_build_object('track','controls_test','user_id',u,'mode','all','range','all','confirm','RESET'));raise exception 'instructor reset bypass';exception when others then if sqlerrm<>'admin_required' then raise;end if;end;
 r:=public.portal_student_controls(a,'report',jsonb_build_object('track','controls_test','kind','functionality','request_id',gen_random_uuid(),'message','An unrelated report for privacy testing.'));
 cfg:=public.portal_manage(u,'reports.list','{"track":"controls_test"}');
 assert jsonb_array_length(cfg->'items')=0 and (cfg->>'open_count')::int=0,'unrelated instructor report access';
 begin perform public.portal_manage(u,'reports.update',jsonb_build_object('track','controls_test','id',r->>'id','status','resolved'));raise exception 'instructor report edit bypass';exception when others then if sqlerrm<>'report_not_found' then raise;end if;end;
 insert into public.tracks(id,name) values('scope_test','Unauthorized test track');
 begin perform public.portal_manage(u,'revision.list','{"track":"scope_test"}');raise exception 'instructor track bypass';exception when others then if sqlerrm<>'forbidden_track' then raise;end if;end;
 assert not has_function_privilege('authenticated','public.portal_manage(uuid,text,jsonb)','execute'),'public management RPC';
 assert not has_function_privilege('authenticated','public.portal_student_controls(uuid,text,jsonb)','execute'),'actor spoofing RPC';
 assert not has_table_privilege('authenticated','public.portal_reports','select'),'reports exposed';
 assert not has_table_privilege('authenticated','public.daily_reset_archive','select'),'archive exposed';
end $$;
rollback;
