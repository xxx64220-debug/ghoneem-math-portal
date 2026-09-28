DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 091", "old_status": "ocr_screened_not_verified", "status": "needs_source_reconstruction", "note": "The function and referenced figure are absent from the original crop. Nearby unrelated vertex/triangle questions do not identify this item uniquely.", "correct": null}, {"id": "clean:HOA 092", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "8291c4e0-7dc4-57f6-9cb8-77874b089962", "stem": "At what point do y=3x+2 and y=4x²−9x+11 intersect?", "choices": [{"key": "A", "text": "(3.5,3)"}, {"key": "B", "text": "(4,14)"}, {"key": "C", "text": "(−2,−4)"}, {"key": "D", "text": "(1.5,6.5)"}], "type": "mcq", "correct": "D", "explanation": "Equating gives 4x²−12x+9=0, or (2x−3)²=0. Thus x=1.5 and y=3(1.5)+2=6.5.", "topic": "Functions, Transformations & Graphs", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 57, "extra_sources": []}, {"id": "clean:HOA 093", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "4c684715-549d-5de2-a440-d2a5eddc9458", "stem": "What is the product of all three roots of x³−4x²−7x+10=0?", "choices": [{"key": "A", "text": "−10"}, {"key": "B", "text": "−12"}, {"key": "C", "text": "14"}, {"key": "D", "text": "5"}], "type": "mcq", "correct": "A", "explanation": "The polynomial factors as (x−1)(x−5)(x+2). Its roots are 1,5,−2 and their product is −10. Equivalently, Vieta’s formula gives minus the constant term for a monic cubic.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 58, "extra_sources": []}, {"id": "clean:HOA 095", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "9e2dea6c-59af-5000-8deb-ffd55ac8d8ae", "stem": "Line T passes through (3,2) and (2,5). Line K passes through (3,2) and is perpendicular to T. Which other point lies on K?", "choices": [{"key": "A", "text": "(5,3)"}, {"key": "B", "text": "(−2,1)"}, {"key": "C", "text": "(1,2)"}, {"key": "D", "text": "(6,3)"}], "type": "mcq", "correct": "D", "explanation": "T has slope (5−2)/(2−3)=−3, so K has slope 1/3. From (3,2) to (6,3), rise/run=1/3. Thus (6,3) lies on K.", "topic": "Coordinate Geometry & Circles", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 59, "extra_sources": []}, {"id": "clean:HOA 097", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "a8c2d946-125b-50b7-af4a-367564959bb7", "stem": "Solve 5(x+2)−3x≤4+2x+3(x+1).", "choices": [{"key": "A", "text": "x≤−3"}, {"key": "B", "text": "x≤3"}, {"key": "C", "text": "x≥3"}, {"key": "D", "text": "x≥−3"}], "type": "mcq", "correct": "C", "explanation": "Expand to 2x+10≤5x+7. Subtract 2x+7 to obtain 3≤3x, hence x≥3.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Confirmed the printed non-strict inequality; equality at x=3 is included.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 60, "extra_sources": []}, {"id": "clean:HOA 098", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "51129bb7-39bd-528a-9c57-6922ef0de34b", "stem": "For a≠5, (2a+1.2b)/(a−5)=4/5. Which relation must hold?", "choices": [{"key": "A", "text": "3a+3b=−7"}, {"key": "B", "text": "a−b=10"}, {"key": "C", "text": "a+b=−10/3"}, {"key": "D", "text": "2a−b=5"}], "type": "mcq", "correct": "C", "explanation": "Multiply by 5(a−5): 10a+6b=4a−20. Thus 6a+6b=−20, so a+b=−10/3.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Split complete Q27 from Q26, whose graph is absent; Q26 remains unpublished.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 60, "extra_sources": []}]$payload$::jsonb) LOOP
  SELECT * INTO s FROM public.est_source_review WHERE id=v->>'id' FOR UPDATE;
  IF s.id IS NULL THEN RAISE EXCEPTION 'Missing source %',v->>'id'; END IF;
  IF EXISTS(SELECT 1 FROM public.audit_log WHERE action=coalesce(v->>'audit_action','source_review_20260928') AND target_id=s.id) THEN CONTINUE; END IF;
  IF s.review_status<>v->>'old_status' THEN RAISE EXCEPTION 'Source status changed %',s.id; END IF;
  qid=nullif(v->>'question_id','')::uuid;
  IF v->>'status'='ready' AND qid IS NOT NULL AND EXISTS(SELECT 1 FROM public.exams e JOIN public.attempts t ON t.exam_id=e.id
      WHERE qid=ANY(e.question_ids) AND t.status='in_progress' AND t.deadline_at>now()) THEN
   INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES('source_review_deferred_20260928','source_review',s.id,jsonb_build_object('reason','Active exam','proposed',v));
   CONTINUE;
  END IF;
  SELECT * INTO q FROM public.questions WHERE id=qid FOR UPDATE;
  SELECT * INTO k FROM public.question_keys WHERE question_id=qid FOR UPDATE;
  IF q.id IS NOT NULL AND v ? 'before' AND
    (q.stem IS DISTINCT FROM v->'before'->>'stem' OR q.choices IS DISTINCT FROM v->'before'->'choices' OR
     k.correct IS DISTINCT FROM v->'before'->'correct' OR k.explanation IS DISTINCT FROM v->'before'->>'explanation') THEN
    RAISE EXCEPTION 'Concurrent live question change %',qid;
  END IF;
  INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES(coalesce(v->>'audit_action','source_review_20260928'),'source_review',s.id,
    jsonb_build_object('before_source',to_jsonb(s),'before_question',to_jsonb(q),'before_key',to_jsonb(k),'decision',v-'assets'-'before'));
  IF v->>'status'='ready' THEN
   IF v->>'type'='mcq' AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v->'choices') c WHERE c->>'key'=v->'correct'#>>'{}') THEN RAISE EXCEPTION 'Invalid key %',s.id; END IF;
   IF v->>'type'='grid_in' AND NOT public.answer_matches('grid_in',CASE WHEN jsonb_typeof(v->'correct')='array' THEN v->'correct'->0 ELSE v->'correct' END,v->'correct') THEN RAISE EXCEPTION 'Grader rejects %',s.id; END IF;
   a=(coalesce(q.assets,'{}'::jsonb)-'release_hold_reason')||coalesce(v->'assets','{}'::jsonb)||jsonb_build_object(
    'verified_release','2026-09-28-independent-solution-and-source-check','answer_review','2026-09-28-independent-solution-and-source-check',
    'verification_note',v->>'note','source_review_id',s.id,'verification_source',s.source_document||' page '||s.source_page);
   IF q.id IS NULL THEN
    a=a||jsonb_build_object('source','reviewed-bank-20260928','source_code',s.source_code,'source_document',s.source_document,'source_page',s.source_page);
    INSERT INTO public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
     VALUES(qid,s.track_id,v->>'topic','medium',v->>'type',v->>'stem',v->'choices',a);
    INSERT INTO public.question_keys(question_id,correct,explanation) VALUES(qid,v->'correct',v->>'explanation');
   ELSE
    UPDATE public.questions SET topic=v->>'topic',type=v->>'type',stem=v->>'stem',choices=v->'choices',assets=a WHERE id=qid;
    UPDATE public.question_keys SET correct=v->'correct',explanation=v->>'explanation' WHERE question_id=qid;
   END IF;
   FOR p IN SELECT value FROM jsonb_array_elements(coalesce(v->'parts','[]'::jsonb)) LOOP
    pid=(p->>'question_id')::uuid;
    IF EXISTS(SELECT 1 FROM public.questions WHERE id=pid) THEN RAISE EXCEPTION 'Split question already exists %',pid; END IF;
    IF p->>'type'='mcq' AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p->'choices') c WHERE c->>'key'=p->'correct'#>>'{}') THEN RAISE EXCEPTION 'Invalid split key %',pid; END IF;
    IF p->>'type'='grid_in' AND NOT public.answer_matches('grid_in',CASE WHEN jsonb_typeof(p->'correct')='array' THEN p->'correct'->0 ELSE p->'correct' END,p->'correct') THEN RAISE EXCEPTION 'Invalid split numeric key %',pid; END IF;
    INSERT INTO public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
     VALUES(pid,s.track_id,coalesce(p->>'topic',v->>'topic'),'medium',p->>'type',p->>'stem',p->'choices',coalesce(p->'assets','{}'::jsonb)||jsonb_build_object(
      'source','reviewed-bank-20260928','source_review_id',s.id,'source_code',s.source_code||':'||(p->>'label'),'source_document',s.source_document,'source_page',s.source_page,
      'verified_release','2026-09-28-independent-solution-and-source-check','answer_review','2026-09-28-independent-solution-and-source-check','verification_note',p->>'note'));
    INSERT INTO public.question_keys(question_id,correct,explanation) VALUES(pid,p->'correct',p->>'explanation');
   END LOOP;
  END IF;
  UPDATE public.est_source_review SET review_status=v->>'status',question_id=coalesce(qid,question_id),
   worked_answer=coalesce(v->'correct',worked_answer),duplicate_of=coalesce(v->>'duplicate_of',duplicate_of),
   review_note='Rechecked 2026-09-28. '||coalesce(v->>'note','')||CASE WHEN v ? 'explanation' THEN E'\nWorked solution: '||(v->>'explanation') ELSE '' END,
   updated_at=now() WHERE id=s.id;
  IF v ? 'parts' THEN UPDATE public.est_source_review SET review_note=review_note||E'\nAdditional separately published questions: '||(SELECT string_agg((partrow.value->>'label')||': '||(partrow.value->>'question_id')||'. '||(partrow.value->>'explanation'),E'\n') FROM jsonb_array_elements(v->'parts') partrow(value)) WHERE id=s.id; END IF;
 END LOOP;
END;
$review$;
SELECT count(*) applied_source_decisions FROM public.audit_log WHERE action='source_review_20260928';
