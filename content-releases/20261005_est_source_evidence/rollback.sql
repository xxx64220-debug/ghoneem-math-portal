begin;
set local lock_timeout='5s';
do $rollback$
declare a audit_log%rowtype;q questions%rowtype;k question_keys%rowtype;
begin
 perform pg_advisory_xact_lock(hashtextextended('est_source_evidence_20261005',0));
 if (select count(*) from audit_log where action='question.est_source_evidence_20261005')<>12 then raise exception 'Expected twelve release records';end if;
 if exists(select 1 from audit_log where action='question.est_source_evidence_20261005.rollback') then raise exception 'Already rolled back';end if;
 for a in select * from audit_log where action='question.est_source_evidence_20261005' loop
  select * into strict q from questions where id=a.target_id::uuid for update;
  select * into strict k from question_keys where question_id=q.id for update;
  if jsonb_build_object('question',to_jsonb(q),'key',to_jsonb(k)) is distinct from a.meta->'after' then raise exception 'Later content edit %',q.id;end if;
  update questions set stem=a.meta->'before'->'question'->>'stem',choices=a.meta->'before'->'question'->'choices',assets=a.meta->'before'->'question'->'assets' where id=q.id;
  update question_keys set explanation=a.meta->'before'->'key'->>'explanation' where question_id=q.id;
 end loop;
 insert into audit_log(actor_id,action,target_type) values(null,'question.est_source_evidence_20261005.rollback','questions');
end $rollback$;
commit;
