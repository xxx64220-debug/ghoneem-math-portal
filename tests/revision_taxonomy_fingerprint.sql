begin;
do $test$
declare qid uuid:=md5('revision-taxonomy-1')::uuid; original_stem text; original_assets jsonb; original_correct jsonb; original_explanation text;
begin
 if (select count(*) from public.audit_log where action='revision.fingerprint_taxonomy_repair.item.20260929')<>2194 then raise exception 'repair item audit count';end if;
 if (select count(*) from public.audit_log where action='revision.fingerprint_taxonomy_repair.20260929')<>1 then raise exception 'repair release audit missing';end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>2194 then raise exception 'ready count';end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where r.fingerprint<>public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>13 then raise exception 'pre-existing stale rows were recertified';end if;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' and p.proname in ('final_revision','portal_manage') and pg_get_functiondef(p.oid) like '%md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text)%') then raise exception 'legacy runtime hash remains';end if;

 select q.stem,q.assets,k.correct,k.explanation into original_stem,original_assets,original_correct,original_explanation
 from public.questions q join public.question_keys k on k.question_id=q.id where q.id=qid;
 update public.questions set assets=assets||'{"curriculum_lesson":"Another lesson","lesson_subtopic":"Another skill","lesson_original_topic":"Another original","lesson_taxonomy_version":"future"}'::jsonb where id=qid;
 if not exists(select 1 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where q.id=qid and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)) then raise exception 'classification-only edit invalidated question';end if;
 update public.questions set assets=jsonb_set(assets,'{figure}','"https://example.test/changed.png"') where id=qid;
 if exists(select 1 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where q.id=qid and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)) then raise exception 'diagram edit was not detected';end if;
 update public.questions set assets=original_assets,stem=original_stem||' changed' where id=qid;
 if exists(select 1 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where q.id=qid and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)) then raise exception 'stem edit was not detected';end if;
 update public.questions set stem=original_stem where id=qid;
 update public.question_keys set correct='"B"'::jsonb where question_id=qid;
 if exists(select 1 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where q.id=qid and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)) then raise exception 'answer-key edit was not detected';end if;
 update public.question_keys set correct=original_correct,explanation=original_explanation||' changed' where question_id=qid;
 if exists(select 1 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where q.id=qid and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)) then raise exception 'explanation edit was not detected';end if;
end $test$;
rollback;
