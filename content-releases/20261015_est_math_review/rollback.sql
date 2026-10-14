-- Restore only this release, rejecting subsequent edits and repeated rollback.
begin isolation level repeatable read;
set local lock_timeout='5s';
do $rollback$
declare a_ record; q_ questions; k_ question_keys; r_ jsonb; n_ int:=0;
begin
 if not exists(select 1 from audit_log where action='content.est_math_review_20261015') or exists(select 1 from audit_log where action='content.est_math_review_20261015.rollback') then raise exception 'Release absent or already rolled back'; end if;
 for a_ in select * from audit_log where action='question.est_math_review_20261015' order by target_id loop
  select * into strict q_ from questions where id=a_.target_id::uuid for update;
  select * into strict k_ from question_keys where question_id=q_.id for update;
  select to_jsonb(r) into r_ from revision_items r where question_id=q_.id for update;
  if md5(jsonb_build_object('q',to_jsonb(q_),'k',to_jsonb(k_))::text)<>a_.meta->>'after_hash' or r_ is distinct from a_.meta->'revision_after' and not(r_ is null and a_.meta->'revision_after'='null'::jsonb) then raise exception 'Concurrent post-release edit: %',q_.id; end if;
  update questions set choices=a_.meta->'before'->'q'->'choices',assets=a_.meta->'before'->'q'->'assets' where id=q_.id;
  update question_keys set explanation=a_.meta->'before'->'k'->>'explanation' where question_id=q_.id;
  update revision_items set fingerprint=a_.meta->'revision_before'->>'fingerprint' where question_id=q_.id;
  n_:=n_+1;
 end loop;
 if n_<>28 then raise exception 'Incomplete audit packet'; end if;
 insert into audit_log(action,target_type,target_id,meta) values('content.est_math_review_20261015.rollback','content_release','20261015_est_math_review',jsonb_build_object('restored',n_));
end $rollback$;
commit;

