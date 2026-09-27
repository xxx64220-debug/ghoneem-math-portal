-- Regression: old mixed sessions must not expose SAT content in EST I.
begin;
set local role service_role;
do $$
declare u uuid; sat_u uuid; sid uuid; estq jsonb; satq jsonb; s jsonb; d jsonb;
begin
 select id into u from public.profiles where role='student' and status='active' and public.is_enrolled(id,'est') order by id limit 1;
 s:=public.final_revision(u,'est','start','{"source":"sat","scope":"sat","count":10}');
 assert not exists(select 1 from jsonb_array_elements(s->'questions') q where q->>'source'<>'est'),'old filter leaked SAT';
 select snapshot->0 into estq from public.revision_sessions where id=(s->>'id')::uuid;
 select jsonb_build_object('id',q.id,'source','sat','type',q.type,'choices',q.choices,'stem',q.stem,'correct',k.correct,'explanation',k.explanation) into satq from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where q.track_id='sat' and r.active limit 1;
 assert satq is not null,'SAT fixture missing';
 insert into public.revision_sessions(user_id,access_track,snapshot) values(u,'est',jsonb_build_array(satq,estq)) returning id into sid;
 s:=public.final_revision(u,'est','state',jsonb_build_object('session',sid));
 assert jsonb_array_length(s->'questions')=1 and s#>>'{questions,0,source}'='est','legacy state filtering';
 begin perform public.final_revision(u,'est','answer',jsonb_build_object('session',sid,'question',satq->>'id','answer','A'));raise exception 'legacy SAT accepted';
 exception when others then if sqlerrm<>'invalid_answer' then raise;end if;end;
 -- Stored completion from a legacy mixed session is derived from eligible questions.
 update public.revision_sessions set answers=jsonb_build_object(estq->>'id',case when estq->>'type'='mcq' then estq#>>'{choices,0,key}' else '999999999' end) where id=sid;
 s:=public.final_revision(u,'est','state',jsonb_build_object('session',sid));
 assert (s->>'completed')::boolean,'legacy eligible completion';
 d:=public.final_revision(u,'est','catalogue');
 assert d#>>'{session,id}' is distinct from sid::text,'completed legacy session offered';
 insert into public.revision_sessions(user_id,access_track,snapshot) values(u,'est',jsonb_build_array(satq)) returning id into sid;
 begin perform public.final_revision(u,'est','state',jsonb_build_object('session',sid));raise exception 'SAT-only legacy session exposed';
 exception when others then if sqlerrm<>'revision_session_not_found' then raise;end if;end;
 d:=public.final_revision(u,'est','catalogue');
 assert d#>>'{session,id}' is distinct from sid::text,'SAT-only legacy resume';
 select id into sat_u from public.profiles where role='student' and status='active' and public.is_enrolled(id,'sat') order by id limit 1;
 assert sat_u is not null,'SAT student fixture missing';
 s:=public.final_revision(sat_u,'sat','start','{"source":"sat","scope":"sat","count":10}');
 assert jsonb_array_length(s->'questions')=10 and not exists(select 1 from jsonb_array_elements(s->'questions') q where q->>'source'<>'sat'),'SAT regression';
 assert not has_function_privilege('anon','public.final_revision_state(uuid,text,uuid)','execute'),'anonymous state access';
end $$;
rollback;
