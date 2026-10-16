-- Reviewed content only. No migrations, grading, assessment or audience writes.
begin isolation level repeatable read;
set local lock_timeout='5s';
set local statement_timeout='45s';
do $review$
declare
 packet_ jsonb := __PACKET__::jsonb;
 item_ jsonb; q_ public.questions; k_ public.question_keys;
 before_ jsonb; after_ jsonb; revision_before_ jsonb; revision_after_ jsonb;
 preservation_before_ jsonb; preservation_after_ jsonb;
 table_ text; digest_ text; count_ int:=0;
begin
 if exists(select 1 from public.audit_log where action='content.est_math_review_20261015') then
  raise exception 'Release already applied; do not replay';
 end if;
 -- Exact row fingerprints cover identity, track, content, complete source assets and private key.
 perform 1 from public.questions where id in(select (value->>'id')::uuid from jsonb_array_elements(packet_)) order by id for update;
 perform 1 from public.question_keys where question_id in(select (value->>'id')::uuid from jsonb_array_elements(packet_)) order by question_id for update;
 perform 1 from public.revision_items where question_id in(select (value->>'id')::uuid from jsonb_array_elements(packet_)) order by question_id for update;
 preservation_before_:='{}';
 foreach table_ in array array['exams','assignments','attempts','attempt_answers','attempt_results','revision_sessions','enrollments','group_members'] loop
  execute format($digest$select md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by md5(to_jsonb(t)::text)),'')) from public.%I t$digest$,table_) into digest_;
  preservation_before_:=preservation_before_||jsonb_build_object(table_,digest_);
 end loop;
 for item_ in select value from jsonb_array_elements(packet_) loop
  select * into strict q_ from public.questions where id=(item_->>'id')::uuid;
  select * into strict k_ from public.question_keys where question_id=q_.id;
  before_:=jsonb_build_object('q',to_jsonb(q_),'k',to_jsonb(k_));
  if md5(before_::text)<>item_->>'before_hash' or q_.track_id<>item_->>'track_id' then raise exception 'Concurrent content change: %',q_.id; end if;
  if k_.correct is distinct from item_->'correct' or not portal_private.question_eligible(q_,k_,q_.track_id,false) then raise exception 'Key or eligibility mismatch: %',q_.id; end if;
  select to_jsonb(r) into revision_before_ from public.revision_items r where r.question_id=q_.id;
  if revision_before_ is not null and revision_before_->>'fingerprint' is distinct from public.revision_question_fingerprint(q_.stem,q_.choices,q_.assets,k_.correct,k_.explanation) then raise exception 'Stale revision fingerprint: %',q_.id; end if;
  update public.questions set choices=item_->'choices',
   assets=assets||jsonb_build_object('answer_review_status','independently_solved','math_review_release','20261015_est_math_review','independent_math_review',item_->'evidence')
   where id=q_.id;
  update public.question_keys set explanation=item_->>'explanation' where question_id=q_.id;
  select * into strict q_ from public.questions where id=q_.id;
  select * into strict k_ from public.question_keys where question_id=q_.id;
  if k_.correct is distinct from before_->'k'->'correct' or not portal_private.question_eligible(q_,k_,q_.track_id,false) then raise exception 'Postcondition failed: %',q_.id; end if;
  update public.revision_items set fingerprint=public.revision_question_fingerprint(q_.stem,q_.choices,q_.assets,k_.correct,k_.explanation) where question_id=q_.id;
  select to_jsonb(r) into revision_after_ from public.revision_items r where r.question_id=q_.id;
  if revision_before_-'fingerprint' is distinct from revision_after_-'fingerprint' then raise exception 'Revision membership changed'; end if;
  after_:=jsonb_build_object('q',to_jsonb(q_),'k',to_jsonb(k_));
  insert into public.audit_log(action,target_type,target_id,meta) values('question.est_math_review_20261015','question',q_.id::text,
   jsonb_build_object('release','20261015_est_math_review','source_code',item_->>'source_code','before',before_,'after_hash',md5(after_::text),'revision_before',revision_before_,'revision_after',revision_after_));
  count_:=count_+1;
 end loop;
 if count_<>28 then raise exception 'Wrong release size'; end if;
 preservation_after_:='{}';
 foreach table_ in array array['exams','assignments','attempts','attempt_answers','attempt_results','revision_sessions','enrollments','group_members'] loop
  execute format($digest$select md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by md5(to_jsonb(t)::text)),'')) from public.%I t$digest$,table_) into digest_;
  preservation_after_:=preservation_after_||jsonb_build_object(table_,digest_);
 end loop;
 if preservation_before_ is distinct from preservation_after_ then raise exception 'History or assessment preservation failed'; end if;
 insert into public.audit_log(action,target_type,target_id,meta) values('content.est_math_review_20261015','content_release','20261015_est_math_review',
  jsonb_build_object('reviewed',28,'est',14,'est2',14,'choice_repairs',2,'keys_changed',0,'preservation',preservation_after_));
end $review$;
commit;
