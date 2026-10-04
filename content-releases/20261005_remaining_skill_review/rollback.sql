-- Metadata rollback only: retain proven holds, verified substitutions and adaptation.
begin;
lock table public.questions,public.question_keys,public.exams in share row exclusive mode;
do $rollback$
declare b record; q_ public.questions; k_ public.question_keys; e_ public.exams;
begin
 if (select count(*) from portal_private.skill_review_20261005_backup) <> 168 then
  raise exception 'Incomplete release backup';
 end if;
 for b in select * from portal_private.skill_review_20261005_backup loop
  if b.kind in('exam','exam_name') then
   select * into e_ from public.exams where id=b.id;
   if md5(to_jsonb(e_)::text) is distinct from b.after_hash then
    raise exception 'Concurrent exam edit; refusing metadata rollback';
   end if;
  else
   select * into q_ from public.questions where id=b.id;
   select * into k_ from public.question_keys where question_id=b.id;
   if md5(jsonb_build_object('q',to_jsonb(q_),'k',to_jsonb(k_))::text) is distinct from b.after_hash then
    raise exception 'Concurrent question/key edit; refusing metadata rollback';
   end if;
  end if;
 end loop;
 for b in select * from portal_private.skill_review_20261005_backup where kind='question' loop
  update public.questions set topic=b.payload->'q'->>'topic',
   assets=(assets-'curriculum_lesson'-'lesson_subtopic'-'lesson_original_topic'-'lesson_taxonomy_version')
    || (select coalesce(jsonb_object_agg(key,value),'{}'::jsonb)
        from jsonb_each(b.payload->'q'->'assets')
        where key in('curriculum_lesson','lesson_subtopic','lesson_original_topic','lesson_taxonomy_version'))
  where id=b.id;
 end loop;
 for b in select * from portal_private.skill_review_20261005_backup where kind in('exam','exam_name') loop
  update public.exams set title=b.payload->'exam'->>'title' where id=b.id;
  if b.kind='exam' and not (select portal_private.exam_content_ready(question_ids,track_id) from public.exams where id=b.id) then
   raise exception 'Exam no longer eligible';
  end if;
 end loop;
end $rollback$;
commit;
