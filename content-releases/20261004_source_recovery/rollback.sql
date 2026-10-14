begin;
set local lock_timeout='5s';
do $rollback$
declare a audit_log%rowtype;q questions%rowtype;k question_keys%rowtype;e exams%rowtype;old exams%rowtype;
begin
 perform pg_advisory_xact_lock(hashtextextended('source_recovery_20261004',0));
 if not exists(select 1 from audit_log where action='question.source_recovery_20261004') then raise exception 'Recovery not applied'; end if;
 if exists(select 1 from audit_log where action='source_recovery_20261004.rolled_back') then raise exception 'Recovery already rolled back'; end if;
 for a in select * from audit_log where action='exam.source_recovery_20261004' order by target_id loop
  select * into e from exams where id=a.target_id::uuid for update;
  old:=jsonb_populate_record(null::exams,a.meta->'original_exam');
  if e.id is null or exists(select 1 from attempts where exam_id=e.id) then raise exception 'Replacement has attempts or was removed: %',a.target_id; end if;
  if e.question_ids is distinct from old.question_ids or e.title is distinct from old.title||' — Source-corrected v2 (Oct 2026)' then raise exception 'Replacement edited: %',e.id; end if;
  update exams set is_published=false where id=e.id;
  -- Keep the replacement and assignment rows as an audit trail.
  update exams set is_published=old.is_published where id=old.id and not is_published;
 end loop;
 for a in select * from audit_log where action='question.source_recovery_20261004' order by target_id loop
  select * into q from questions where id=a.target_id::uuid for update;
  select * into k from question_keys where question_id=q.id for update;
  if q.id is null or md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text) is distinct from a.meta->>'after_hash' then raise exception 'Question changed since recovery: %',a.target_id; end if;
  update questions set choices=a.meta->'before_choices',assets=a.meta->'before_assets' where id=q.id;
  update question_keys set explanation=a.meta->>'before_explanation' where question_id=q.id;
  update revision_items r set fingerprint=revision_question_fingerprint(q2.stem,q2.choices,q2.assets,k2.correct,k2.explanation)
   from questions q2 join question_keys k2 on k2.question_id=q2.id where r.question_id=q2.id and q2.id=q.id;
 end loop;
 insert into audit_log(action,target_type,target_id,meta) values('source_recovery_20261004.rolled_back','release','20261004',jsonb_build_object('history_preserved',true));
end $rollback$;
commit;
