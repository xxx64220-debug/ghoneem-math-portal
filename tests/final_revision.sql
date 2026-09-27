-- Transactional integration test. Every created practice session is rolled back.
begin;
set local role service_role;
do $$
declare u uuid; u2 uuid; d jsonb; a jsonb; s jsonb; firstq jsonb; question_ jsonb; key_ jsonb; sid uuid; result_ jsonb; n int;
begin
 select id into u from public.profiles where role='student' and status='active' and public.is_enrolled(id,'est') order by id limit 1;
 select id into u2 from public.profiles where role='student' and status='active' and public.is_enrolled(id,'est') and id<>u order by id limit 1;
 if u is null or u2 is null then raise exception 'two_eligible_test_students_required'; end if;
 d:=public.final_revision(u,'est','catalogue');
 assert jsonb_array_length(d->'items')=378,'catalogue count';
 assert not exists(select 1 from jsonb_array_elements(d->'items') q where q ?| array['correct','answer','explanation','stem']),'catalogue key leak';
 s:=public.final_revision(u,'est','start','{"count":20,"scope":"both","source":"both","difficulty":"mixed"}');
 sid:=(s->>'id')::uuid;
 assert jsonb_array_length(s->'questions')=20,'set size';
 assert (select count(distinct q->>'id') from jsonb_array_elements(s->'questions') q)=20,'duplicate';
 assert (select count(*) from jsonb_array_elements(s->'questions') q where q->>'difficulty'='easy')=6,'easy quota';
 assert (select count(*) from jsonb_array_elements(s->'questions') q where q->>'difficulty'='medium')=8,'medium quota';
 assert (select count(*) from jsonb_array_elements(s->'questions') q where q->>'difficulty'='hard')=6,'hard quota';
 assert (select count(distinct q->>'source') from jsonb_array_elements(s->'questions') q)=2,'mixed sources';
 assert not exists(select 1 from jsonb_array_elements(s->'questions') q where q ?| array['correct','explanation'] or q->'feedback'<>'null'::jsonb),'preanswer key leak';
 begin perform public.final_revision(u2,'est','state',jsonb_build_object('session',sid));raise exception 'owner check missing';
 exception when others then if sqlerrm<>'revision_session_not_found' then raise;end if;end;
 begin perform public.final_revision(u,'est','answer',jsonb_build_object('session',sid,'question',gen_random_uuid(),'answer','A'));raise exception 'membership check missing';
 exception when others then if sqlerrm<>'invalid_answer' then raise;end if;end;
 firstq:=s->'questions'->0;
 for question_ in select * from jsonb_array_elements(s->'questions') loop
  select correct into key_ from public.question_keys where question_id=(question_->>'id')::uuid;
  if jsonb_typeof(key_)='array' then key_:=key_->0; end if;
  -- Deliberately answer the first question incorrectly.
  if question_->>'id'=firstq->>'id' then
   if question_->>'type'='mcq' then select to_jsonb(c->>'key') into key_ from jsonb_array_elements(question_->'choices') c where not public.answer_matches('mcq',to_jsonb(c->>'key'),key_) limit 1;
   else key_:='"999999999"'::jsonb;end if;
  end if;
  result_:=public.final_revision(u,'est','answer',jsonb_build_object('session',sid,'question',question_->>'id','answer',key_));
 end loop;
 assert (result_->>'completed')::boolean,'completion not saved';
 assert (select count(*) from jsonb_array_elements(result_->'questions') q where (q->'feedback'->>'correct')::boolean)=19,'grading count';
 a:=public.final_revision(u,'est','state',jsonb_build_object('session',sid));assert a=result_,'resume changed state';
 select correct into key_ from public.question_keys where question_id=(firstq->>'id')::uuid;
 if jsonb_typeof(key_)='array' then key_:=key_->0;end if;
 a:=public.final_revision(u,'est','answer',jsonb_build_object('session',sid,'question',firstq->>'id','answer',key_));
 assert a=result_,'repeat submission changed score';
 s:=public.final_revision(u,'est','start',jsonb_build_object('count',20,'retry',sid));
 assert jsonb_array_length(s->'questions')=1 and s->'questions'->0->>'id'=firstq->>'id','retry does not contain exact mistake';
 s:=public.final_revision(u,'est','start','{"count":10,"scope":"sat","source":"sat","difficulty":"easy","lesson":"Area and volume"}');
 assert not exists(select 1 from jsonb_array_elements(s->'questions') q where q->>'source'<>'sat' or q->>'difficulty'<>'easy' or q->>'lesson'<>'Area and volume'),'filters';
 assert public.answer_matches('grid_in','"0.5"','"1/2"'),'fraction equivalence';
 assert public.answer_matches('grid_in','"16"','["10","16"]'),'multiple valid roots';
 assert not has_function_privilege('authenticated','public.final_revision(uuid,text,text,jsonb)','execute'),'public RPC';
 assert not has_table_privilege('authenticated','public.revision_sessions','select'),'snapshot exposed';
end $$;
rollback;
