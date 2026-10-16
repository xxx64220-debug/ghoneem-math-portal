-- Safe rollback: never restore malformed MA-30 to selectable use.
-- Restored never-attempted assessments are drafts; historical attempts remain visible.
begin isolation level repeatable read;
set local lock_timeout='5s';
do $undo$
declare p_ jsonb:=__PACKET__;x_ jsonb;a_ public.audit_log;q_ public.questions;k_ public.question_keys;e_ public.exams;
 h_ text; t_ text; used_ boolean;
begin
 if not exists(select 1 from public.audit_log where action='content.est_cleanup_20261015') or exists(select 1 from public.audit_log where action='content.est_cleanup_20261015.rollback') then raise exception 'Cleanup absent or already rolled back'; end if;
 lock table public.questions,public.question_keys,public.exams,public.assignments,public.attempts,public.revision_items in share row exclusive mode;
 select md5(jsonb_build_object('q',to_jsonb(q),'k',to_jsonb(k))::text) into h_ from public.questions q join public.question_keys k on k.question_id=q.id where q.id=(p_->'question'->>'id')::uuid;
 if h_ is distinct from (select meta->>'new_question_hash' from public.audit_log where action='content.est_cleanup_20261015') then raise exception 'Adaptation content changed'; end if;
 foreach t_ in array array['attempt_answers','attempt_results','revision_sessions','revision_items','daily_quizzes','practice_drills','practice_notebook'] loop
  execute format('select exists(select 1 from public.%I r where strpos(to_jsonb(r)::text,$1)>0)',t_) into used_ using p_->'question'->>'id';
  if used_ then raise exception 'Adaptation has new practice/history use'; end if;
 end loop;
 if exists(select 1 from public.exams where (p_->'question'->>'id')::uuid=any(question_ids) and id not in(select (value->>'new_id')::uuid from jsonb_array_elements(p_->'exams'))) then raise exception 'Adaptation has new assessment use'; end if;
 for x_ in select value from jsonb_array_elements(p_->'exams') loop
  select * into strict a_ from public.audit_log where action='exam.est_cleanup_20261015' and target_id=x_->'before'->>'id';
  select * into strict e_ from public.exams where id=(x_->>'new_id')::uuid;
  if md5(to_jsonb(e_)::text) is distinct from a_.meta->>'new_exam_hash' or exists(select 1 from public.attempts where exam_id=e_.id) then raise exception 'Corrected assessment changed or has attempts'; end if;
  select md5(coalesce(jsonb_agg(to_jsonb(z) order by z.id),'[]'::jsonb)::text) into h_ from public.assignments z where z.exam_id=e_.id;
  if h_ is distinct from a_.meta->>'new_assignments_hash' then raise exception 'Corrected assignment changed'; end if;
  select * into strict e_ from public.exams where id=(x_->'before'->>'id')::uuid;
  if md5(to_jsonb(e_)::text) is distinct from a_.meta->>'after_hash' then raise exception 'Original assessment changed'; end if;
 end loop;
 for x_ in select value from jsonb_array_elements(p_->'archive') loop
  select * into strict a_ from public.audit_log where action='question.est_cleanup_20261015' and target_id=x_->>'id';
  select * into strict q_ from public.questions where id=a_.target_id::uuid;
  select * into strict k_ from public.question_keys where question_id=q_.id;
  if md5(to_jsonb(q_)::text) is distinct from a_.meta->>'after_hash' or md5(to_jsonb(k_)::text) is distinct from a_.meta->>'key_hash' then raise exception 'Archived content changed'; end if;
 end loop;
 for x_ in select value from jsonb_array_elements(p_->'sources') loop
  if not exists(select 1 from public.est_source_review where id=x_->>'id' and review_status=x_->>'status' and review_note=x_->>'note') then raise exception 'Source metadata changed'; end if;
 end loop;
 -- Keep MA-30 archived because its original choice defect remains established.
 for a_ in select * from public.audit_log where action='question.est_cleanup_20261015' and target_id<>p_->'question'->'assets'->>'adapted_from_question_id' loop
  update public.questions set assets=a_.meta->'before'->'assets' where id=a_.target_id::uuid;
 end loop;
 for x_ in select value from jsonb_array_elements(p_->'exams') loop
  if (x_->>'has_history')::boolean then
   delete from public.assignments where exam_id=(x_->>'new_id')::uuid;
   delete from public.exams where id=(x_->>'new_id')::uuid;
   -- Its previous exact question IDs, grades and held historical title remain.
  else
   update public.exams set question_ids=array(select jsonb_array_elements_text(x_->'before'->'question_ids')::uuid),title=x_->'before'->>'title',is_published=false where id=(x_->'before'->>'id')::uuid;
  end if;
 end loop;
 for a_ in select * from public.audit_log where action='source.est_cleanup_20261015' loop
  update public.est_source_review set review_status=a_.meta->'before'->>'review_status',review_note=a_.meta->'before'->>'review_note',updated_at=(a_.meta->'before'->>'updated_at')::timestamptz where id=a_.target_id;
 end loop;
 delete from public.question_keys where question_id=(p_->'question'->>'id')::uuid;
 delete from public.questions where id=(p_->'question'->>'id')::uuid;
 insert into public.audit_log(action,target_type,target_id,meta) values('content.est_cleanup_20261015.rollback','content_release','20261015_est_cleanup',jsonb_build_object('restored_held_metadata',171,'ma30_stays_archived',true,'unused_exams_drafted',7));
end $undo$;
commit;
