-- Archive, never delete, originals. Existing saved scores/answers are immutable here.
begin isolation level repeatable read;
set local lock_timeout='5s';
set local statement_timeout='50s';
do $cleanup$
declare
 p_ jsonb:=__PACKET__; x_ jsonb; q_ public.questions; k_ public.question_keys; r_ public.questions; rk_ public.question_keys;
 e_ public.exams; n_ public.exams; before_ jsonb; h_ text; old_sources_ jsonb;
 snapshot_before_ jsonb:='{}'; snapshot_after_ jsonb:='{}'; t_ text; c_ int:=0;
begin
 if exists(select 1 from public.audit_log where action='content.est_cleanup_20261015') then raise exception 'Cleanup already applied'; end if;
 lock table public.exams,public.assignments,public.attempts,public.revision_items in share row exclusive mode;
 -- These guards include every unchanged assessment member and replacement source.
 for x_ in select value from jsonb_array_elements(p_->'members') order by value->>'id' loop
  select * into strict q_ from public.questions where id=(x_->>'id')::uuid for update;
  select * into strict k_ from public.question_keys where question_id=q_.id for update;
  if md5(jsonb_build_object('q',to_jsonb(q_),'k',to_jsonb(k_))::text) is distinct from x_->>'hash' then raise exception 'Concurrent member change: %',q_.id; end if;
 end loop;
 for x_ in select value from jsonb_array_elements(p_->'archive') order by value->>'id' loop
  select * into strict q_ from public.questions where id=(x_->>'id')::uuid for update;
  select * into strict k_ from public.question_keys where question_id=q_.id for update;
  if md5(jsonb_build_object('q',to_jsonb(q_),'k',to_jsonb(k_))::text) is distinct from x_->>'hash' then raise exception 'Concurrent archive content change: %',q_.id; end if;
 end loop;
 if (select count(*) from public.revision_items where question_id in(select (value->>'id')::uuid from jsonb_array_elements(p_->'archive')))<>1
 or exists(select 1 from public.revision_items where active and question_id in(select (value->>'id')::uuid from jsonb_array_elements(p_->'archive'))) then raise exception 'Archive revision membership changed'; end if;
 for x_ in select value from jsonb_array_elements(p_->'exams') loop
  select * into strict e_ from public.exams where id=(x_->'before'->>'id')::uuid for update;
  if md5(to_jsonb(e_)::text) is distinct from x_->>'hash' then raise exception 'Concurrent exam change: %',e_.id; end if;
  if (select count(*) from public.attempts where exam_id=e_.id)<>(x_->>'attempts')::int then raise exception 'Concurrent exam history: %',e_.id; end if;
  select md5(coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb)::text) into h_ from public.assignments a where a.exam_id=e_.id;
  if h_ is distinct from x_->>'assignment_hash' then raise exception 'Concurrent assignment change: %',e_.id; end if;
 end loop;
 foreach t_ in array array['attempts','attempt_answers','attempt_results','revision_sessions','enrollments','group_members','revision_items'] loop
  execute format($digest$select md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by md5(to_jsonb(t)::text)),'')) from public.%I t$digest$,t_) into h_;
  snapshot_before_:=snapshot_before_||jsonb_build_object(t_,h_);
 end loop;
 x_:=p_->'question';
 if exists(select 1 from public.questions where id=(x_->>'id')::uuid or assets->>'source_code'=x_->'assets'->>'source_code' or lower(regexp_replace(stem,'[[:space:]]+',' ','g'))=lower(regexp_replace(x_->>'stem','[[:space:]]+',' ','g'))) then raise exception 'Adaptation ID/code/stem collision'; end if;
 insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
 values((x_->>'id')::uuid,x_->>'track_id',x_->>'topic',x_->>'difficulty',x_->>'type',x_->>'stem',x_->'choices',x_->'assets');
 insert into public.question_keys values((x_->>'id')::uuid,x_->'correct',x_->>'explanation');
 for x_ in select value from jsonb_array_elements(p_->'archive') loop
  select * into strict q_ from public.questions where id=(x_->>'id')::uuid;
  select * into strict k_ from public.question_keys where question_id=q_.id;
  select * into strict r_ from public.questions where id=(x_->>'replacement_id')::uuid;
  select * into strict rk_ from public.question_keys where question_id=r_.id;
  if not portal_private.question_eligible(r_,rk_,q_.track_id,false) then raise exception 'Replacement not ready in same track: %',q_.id; end if;
  before_:=to_jsonb(q_);
  update public.questions set assets=assets||jsonb_build_object('bank_removed',true,'bank_removed_at','2026-10-15','bank_disposition',x_->>'disposition','bank_removal_release','20261015_est_cleanup','bank_removal_reason',x_->>'reason','replacement_question_id',x_->>'replacement_id','release_hold_reason',x_->>'reason') where id=q_.id;
  select md5(to_jsonb(q)::text) into h_ from public.questions q where id=q_.id;
  insert into public.audit_log(action,target_type,target_id,meta) values('question.est_cleanup_20261015','question',q_.id::text,jsonb_build_object('before',before_,'after_hash',h_,'key_hash',md5(to_jsonb(k_)::text),'replacement_id',x_->>'replacement_id'));
  c_:=c_+1;
 end loop;
 if c_<>172 then raise exception 'Incomplete archive'; end if;
 for x_ in select value from jsonb_array_elements(p_->'exams') loop
  select * into strict e_ from public.exams where id=(x_->'before'->>'id')::uuid;
  before_:=to_jsonb(e_);
  if not portal_private.exam_content_ready(array(select jsonb_array_elements_text(x_->'question_ids')::uuid),e_.track_id) then raise exception 'Corrected assessment not ready: %',e_.id; end if;
  if (x_->>'has_history')::boolean then
   n_:=e_;n_.id:=(x_->>'new_id')::uuid;n_.title:=x_->>'title';n_.created_at:=now();n_.question_ids:=array(select jsonb_array_elements_text(x_->'question_ids')::uuid);
   insert into public.exams select n_.*;
   insert into public.assignments(exam_id,group_id,user_id,open_at,close_at)
   select n_.id,group_id,user_id,open_at,close_at from public.assignments where exam_id=e_.id;
   update public.exams set title=e_.title||' — Historical version (held)' where id=e_.id;
  else
   update public.exams set question_ids=array(select jsonb_array_elements_text(x_->'question_ids')::uuid),title=x_->>'title' where id=e_.id;
  end if;
  select md5(to_jsonb(e)::text) into h_ from public.exams e where id=e_.id;
  insert into public.audit_log(action,target_type,target_id,meta) values('exam.est_cleanup_20261015','exam',e_.id::text,jsonb_build_object('before',before_,'after_hash',h_,'new_id',x_->>'new_id','has_history',x_->'has_history','new_exam_hash',(select md5(to_jsonb(ex)::text) from public.exams ex where ex.id=(x_->>'new_id')::uuid),'new_assignments_hash',(select md5(coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb)::text) from public.assignments a where a.exam_id=(x_->>'new_id')::uuid)));
 end loop;
 for x_ in select value from jsonb_array_elements(p_->'sources') loop
  perform 1 from public.est_source_review where id=x_->>'id' for update;
  select md5(jsonb_build_object('id',s.id,'track_id',s.track_id,'question_id',s.question_id,'review_status',s.review_status,'review_note',s.review_note,'updated_at',s.updated_at)::text),
   jsonb_build_object('review_status',s.review_status,'review_note',s.review_note,'updated_at',s.updated_at)
   into h_,old_sources_ from public.est_source_review s where s.id=x_->>'id';
  if h_ is distinct from x_->>'hash' then raise exception 'Concurrent source metadata change'; end if;
  update public.est_source_review set review_status=x_->>'status',review_note=x_->>'note',updated_at=now() where id=x_->>'id';
  insert into public.audit_log(action,target_type,target_id,meta) values('source.est_cleanup_20261015','source',x_->>'id',jsonb_build_object('before',old_sources_,'after_status',x_->>'status','after_note',x_->>'note'));
 end loop;
 foreach t_ in array array['attempts','attempt_answers','attempt_results','revision_sessions','enrollments','group_members','revision_items'] loop
  execute format($digest$select md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by md5(to_jsonb(t)::text)),'')) from public.%I t$digest$,t_) into h_;
  snapshot_after_:=snapshot_after_||jsonb_build_object(t_,h_);
 end loop;
 if snapshot_before_ is distinct from snapshot_after_ then raise exception 'Saved history or membership changed'; end if;
 if exists(select 1 from public.questions q left join public.question_keys k on k.question_id=q.id where q.track_id in ('est','est2') and lower(coalesce(q.assets->>'bank_removed','false'))<>'true' and not portal_private.question_eligible(q,k,q.track_id,false)) then raise exception 'Unaccounted active blocked record'; end if;
 insert into public.audit_log(action,target_type,target_id,meta) values('content.est_cleanup_20261015','content_release','20261015_est_cleanup',
 jsonb_build_object('archived',172,'est_archived',159,'est2_archived',13,'replacement_links',172,'added',1,'exam_repairs',8,'new_exam_versions',1,'source_status_repairs',15,'preservation',snapshot_after_,'new_question_id',p_->'question'->>'id','new_question_hash',(select md5(jsonb_build_object('q',to_jsonb(q),'k',to_jsonb(k))::text) from public.questions q join public.question_keys k on k.question_id=q.id where q.id=(p_->'question'->>'id')::uuid)));
end $cleanup$;
commit;

