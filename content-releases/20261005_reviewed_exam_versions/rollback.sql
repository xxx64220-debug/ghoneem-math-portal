begin;
do $rollback$
declare b portal_private.exam_review_20261005_backup%rowtype;e public.exams%rowtype;q public.questions%rowtype;k public.question_keys%rowtype;added_ uuid[];
begin
 lock table public.exams,public.assignments,public.attempts in share row exclusive mode;
 if (select count(*) from portal_private.exam_review_20261005_backup where kind='exam')<>30 then raise exception 'Incomplete review backup';end if;
 select array_agg(id) into added_ from portal_private.exam_review_20261005_backup where kind='adaptation';
 if exists(select 1 from public.daily_quizzes where question_ids&&added_)
 or exists(select 1 from public.practice_drills where question_ids&&added_)
 or exists(select 1 from public.practice_notebook where question_id=any(added_))
 or exists(select 1 from public.revision_items where question_id=any(added_))
 or exists(select 1 from public.revision_sessions s cross join lateral jsonb_array_elements(s.snapshot) j where j->>'id'=any(array(select a::text from unnest(added_) a)))
 then raise exception 'Adaptations are in practice history; rollback must preserve them';end if;
 for b in select * from portal_private.exam_review_20261005_backup where kind='exam' order by id loop
  select * into e from public.exams where id=b.id for update;
  if md5(to_jsonb(e)::text)<>b.after_hash then raise exception 'Exam edited after release';end if;
  if exists(select 1 from public.attempts where exam_id=b.new_id) then raise exception 'Corrected version has attempts; rollback requires preserving new history';end if;
 end loop;
 for b in select * from portal_private.exam_review_20261005_backup where kind='adaptation' order by id loop
  select * into q from public.questions where id=b.id for update;select * into k from public.question_keys where question_id=q.id for update;
  if md5(jsonb_build_object('q',to_jsonb(q),'k',to_jsonb(k))::text)<>b.after_hash then raise exception 'Adaptation edited after release';end if;
 end loop;
 for b in select * from portal_private.exam_review_20261005_backup where kind='exam' order by id loop
  if b.new_id<>b.id then delete from public.assignments where exam_id=b.new_id;delete from public.exams where id=b.new_id;end if;
  e:=jsonb_populate_record(null::public.exams,b.before_row);
  -- Old held versions cannot be republished through the modern eligibility trigger.
  -- Their unchanged publication flag is retained; only membership/title are restored.
  if b.new_id=b.id then
   -- Refuse to weaken the publish guard. A rollback to held content keeps this unused version as a draft.
   update public.exams set is_published=false where id=e.id;
   update public.exams set question_ids=e.question_ids,title=e.title,assessment_type=e.assessment_type,max_attempts=e.max_attempts,is_full_length=e.is_full_length where id=e.id;
  else update public.exams set title=e.title where id=e.id;end if;
 end loop;
 for b in select * from portal_private.exam_review_20261005_backup where kind='held_copy' loop
  select * into q from public.questions where id=b.id for update;
  if md5(to_jsonb(q)::text)<>b.after_hash then raise exception 'Held copy edited after release';end if;
  update public.questions set assets=b.before_row->'assets' where id=b.id;
 end loop;
 delete from public.question_keys where question_id in(select id from portal_private.exam_review_20261005_backup where kind='adaptation');
 delete from public.questions where id in(select id from portal_private.exam_review_20261005_backup where kind='adaptation');
 delete from portal_private.exam_review_20261005_backup;
end $rollback$;
commit;
