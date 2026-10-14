do $test$
declare v_ids uuid[] := array[
 '12039edd-0ed2-4caf-847b-1f8b79633f6d','5f8bdfe2-cb1a-409e-b86a-1f4c6fd5c15a','98b55bd5-6947-41a1-8d69-5f942958b2f4',
 '9d7495b1-b96a-431f-b79d-6d76a5a220a3','a443a041-cac2-43fb-89c5-19e7039d8f56','bffede21-7eb9-449a-9ff9-c8fff021ae10',
 'ca2b3234-ea0e-4328-9cc7-ac8d9e9e32cf','ff6f428b-3bba-4c63-aa81-05c6afba57a6','086ff1ee-3885-4c3c-ab7d-cf4685e399e4',
 '1acd1ade-28f1-4ee4-8c84-855f427629e2','61de8416-5bda-4d8c-aaf3-14f52feb16ff','e5897815-836d-4eb7-8da2-1d7873e5f913',
 'da7220f9-fad9-570f-a8df-5500fe4f5823']::uuid[];
begin
 if (select count(*) from public.questions where id=any(v_ids))<>13 then raise exception 'missing corrected questions'; end if;
 if (select count(*) from public.questions where id=any(v_ids) and topic='Trigonometry')<>7 then raise exception 'cofunction correction failed'; end if;
 if (select count(*) from public.questions where id=any(v_ids) and topic='Polynomial division and remainder')<>5 then raise exception 'remainder correction failed'; end if;
 if (select count(*) from public.questions where id=any(v_ids) and topic='Functions and transformations')<>1 then raise exception 'range correction failed'; end if;
 if exists(select 1 from public.questions where id=any(v_ids) and (
  assets->>'curriculum_lesson'<>topic or assets->>'lesson_taxonomy_version'<>'20260929.1'
  or assets->>'lesson_subtopic'<>'fixture detail' or assets->>'lesson_original_topic'<>'fixture original'
  or assets->>'image'<>'fixture.png' or assets->'table'<>jsonb_build_array(jsonb_build_array('x','y'))
  or stem<>'taxonomy fixture '||id::text or choices<>'[{"key":"A","text":"fixture"}]'::jsonb
 )) then raise exception 'question content or detailed assets changed'; end if;
 if exists(select 1 from public.revision_items r join public.questions q on q.id=r.question_id where q.id=any(v_ids) and r.lesson<>q.topic) then raise exception 'revision lesson mismatch'; end if;
 if exists(select 1 from public.question_keys where question_id=any(v_ids) and (correct<>to_jsonb('A'::text) or explanation<>'fixture explanation')) then raise exception 'answer key changed'; end if;
 if (select cardinality(question_ids) from public.exams where id='11111111-1111-4111-8111-111111111111')<>13 then raise exception 'exam membership changed'; end if;
 if (select count(*) from public.audit_log where action='question.lesson_taxonomy_corrections.20260929')<>13 then raise exception 'correction audit incomplete'; end if;
end $test$;
