-- Restore only if every repaired record still matches this release.
begin;
do $rollback$
declare b public.question_reliability_20261004_backup%rowtype;q public.questions%rowtype;k public.question_keys%rowtype;
begin
 if (select count(*) from public.question_reliability_20261004_backup)<>12 then raise exception 'Incomplete release backup'; end if;
 for b in select * from public.question_reliability_20261004_backup order by question_id loop
  select * into q from public.questions where id=b.question_id for update;
  select * into k from public.question_keys where question_id=b.question_id for update;
  if md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text) is distinct from b.after_hash then raise exception 'Concurrent content change during rollback: %',b.question_id; end if;
  if exists(select 1 from revision_items r where r.question_id=b.question_id and
    (r.fingerprint is distinct from revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)
    or r.active is distinct from case when nullif(q.assets->>'release_hold_reason','') is not null then false else b.revision_active end))
    or (b.revision_fingerprint is not null and not exists(select 1 from revision_items where question_id=b.question_id))
   then raise exception 'Concurrent revision change during rollback: %',b.question_id; end if;
  update public.questions set choices=b.before_choices,assets=b.before_assets where id=b.question_id;
  update public.question_keys set explanation=b.before_explanation where question_id=b.question_id;
  update public.revision_items set fingerprint=b.revision_fingerprint,active=b.revision_active where question_id=b.question_id;
  insert into public.audit_log(action,target_type,target_id,meta) values('question.reliability_20261004.rollback','question',b.question_id::text,jsonb_build_object('restored_hash',b.before_hash));
 end loop;
end $rollback$;
delete from public.question_reliability_20261004_backup;
commit;
