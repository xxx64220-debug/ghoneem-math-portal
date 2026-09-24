-- Additional security and authoring regressions, within the caller's rollback transaction.
do $$
declare adm uuid:=public.tid('admin'); u uuid:=public.tid('both'); qid uuid; eid uuid; aid uuid; a attempts; j jsonb; j2 jsonb; msg text; cnt int; x uuid;
begin
 j=portal_admin(adm,'question.save','{"track_id":"est","topic":"QA","type":"grid_in","stem":"What is one half?","correct":["1/2","0.5"],"explanation":"Divide 1 by 2."}');
 qid=(j->'question_ids'->>0)::uuid;
 j=portal_admin(adm,'exam.save',jsonb_build_object('track_id','est','title','QA exact conversion','question_ids',jsonb_build_array(qid),'duration_seconds',600,'is_published',true,'is_full_length',true,'scoring_map','{"0":100,"1":400}'::jsonb));
 eid=(j->>'id')::uuid;
 perform portal_admin(adm,'assignment.save',jsonb_build_object('exam_id',eid,'user_id',u,'close_at',now()+interval '1 hour'));
 a=start_attempt(eid,u);
 insert into attempt_answers(attempt_id,question_id,response) values(a.id,qid,'"0.5"');
 j=portal_submit(a.id,u,'qa-same-key');j2=portal_submit(a.id,u,'qa-same-key');
 perform t_ok('upgrade: same idempotency key returns identical response',j=j2 and j->>'status'='200');
 perform t_ok('upgrade: windowed submission exposes no review items',j->'body'->'items'='[]'::jsonb);
 perform t_ok('upgrade: exact EST conversion gives 400 for full raw mark',(j->'body'->'attempt'->>'scaled_score')::int=400);
 j=portal_submit(a.id,u,'qa-different-key');perform t_ok('upgrade: different submit key returns conflict',j->>'status'='409');
 begin perform portal_admin(adm,'question.save',jsonb_build_object('id',qid,'type','grid_in','stem','Changed','correct','2'));exception when others then msg=sqlerrm;end;
 perform t_ok('upgrade: used question is immutable',msg='question_in_use_create_new_version',coalesce(msg,''));
 select count(*) into cnt from questions;
 begin perform portal_admin(adm,'question.import','{"track_id":"est","questions":[{"type":"grid_in","stem":"valid","correct":["1"]},{"type":"mcq","stem":"invalid","correct":"Z","choices":[]}]}');exception when others then msg=sqlerrm;end;
 perform t_ok('upgrade: invalid import rolls back every question',(select count(*) from questions)=cnt);
 begin perform portal_admin(u,'user.update',jsonb_build_object('id',u,'role','admin'));exception when others then msg=sqlerrm;end;
 perform t_ok('upgrade: staff RPC rejects student actor',msg='forbidden');
 perform portal_admin(adm,'exam.save',jsonb_build_object('id',eid,'is_published',false));
 perform t_ok('upgrade: used exam may be unpublished',(select not is_published from exams where id=eid));
 perform portal_admin(adm,'exam.save',jsonb_build_object('id',eid,'is_published',true));
 perform t_ok('upgrade: staff writes are audited',(select count(*) from audit_log where actor_id=adm and action in ('question.save','exam.save','assignment.save'))>=3);
 -- Suspension must invalidate RLS despite any existing role claim.
 perform portal_admin(adm,'user.update',jsonb_build_object('id',u,'status','suspended'));
 perform t_ok('upgrade: suspended student fails enrollment gate',not is_enrolled(u,'est'));
 perform portal_admin(adm,'user.update',jsonb_build_object('id',u,'status','active'));
 -- Session creation validates auth.sessions instead of trusting a client device label.
 begin perform portal_session(u,gen_random_uuid(),'QA');exception when others then msg=sqlerrm;end;
 perform t_ok('upgrade: forged session is rejected',msg='invalid_session');
 -- Score-only and instructor-release content cannot leak through the results endpoint.
 perform t_ok('upgrade: no client privilege on staff or idempotent RPC',not has_function_privilege('authenticated','portal_admin(uuid,text,jsonb)','execute') and not has_function_privilege('authenticated','portal_submit(uuid,uuid,text)','execute'));
 perform t_ok('upgrade: staff direct writes are unavailable',not has_table_privilege('authenticated','exams','insert') and not has_table_privilege('authenticated','retake_grants','insert'));
end $$;
do $$ declare f int;begin select count(*) into f from test_results where not ok;if f>0 then raise exception 'QA failed: %',(select string_agg(label||': '||detail,'; ') from test_results where not ok);end if;end $$;
