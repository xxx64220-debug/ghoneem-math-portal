DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 151", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "050dedfa-2e1d-5897-b160-118989501a3a", "stem": "For a≠0, the product of the two complex roots of 2ax²+6a²=0 is 90. What is a?", "choices": [{"key": "A", "text": "10"}, {"key": "B", "text": "12"}, {"key": "C", "text": "20"}, {"key": "D", "text": "30"}], "type": "mcq", "correct": "D", "explanation": "By Vieta’s formula, the product is (6a²)/(2a)=3a. Thus 3a=90 and a=30. The roots need not be real; at a=30 they are ±i√90.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Explicitly allowed complex roots because the verified positive a gives no real roots.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 90, "extra_sources": []}, {"id": "clean:HOA 152", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "2c681e38-bb79-525d-8327-ab92047ba0a5", "stem": "Solve the system 4x−4y=−16 and x−2y=−12.", "choices": [{"key": "A", "text": "(8,−4)"}, {"key": "B", "text": "(4,8)"}, {"key": "C", "text": "(−2,4)"}, {"key": "D", "text": "(4,−8)"}], "type": "mcq", "correct": "B", "explanation": "Divide the first equation by 4: x−y=−4. Subtract the second equation to get y=8. Then x=4. Both original equations are satisfied.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 91, "extra_sources": [], "parts": [{"label": "Q10", "question_id": "226ea372-559a-5484-9288-1f05354fe294", "stem": "Which statement describes the solutions of (x²+x−30)/(x−5)=11?", "choices": [{"key": "A", "text": "x=−6"}, {"key": "B", "text": "There is no solution, because the only candidate x=5 is excluded."}, {"key": "C", "text": "x=16"}, {"key": "D", "text": "x=5"}], "type": "mcq", "correct": "B", "explanation": "Factor the numerator as (x+6)(x−5). For x≠5 the equation becomes x+6=11, giving x=5, which violates the original domain. Therefore there is no solution.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered C/D from HOA 153 on the same page; retained the denominator exclusion."}]}, {"id": "clean:HOA 153", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "4f6ca37f-c5df-51a0-bfc9-79c108a29f88", "stem": "The line through (8,3) and (5,−3) has slope k/5. What is k?", "choices": [{"key": "A", "text": "1"}, {"key": "B", "text": "19"}, {"key": "C", "text": "10"}, {"key": "D", "text": "6"}], "type": "mcq", "correct": "C", "explanation": "The slope is (3−(−3))/(8−5)=6/3=2. Thus k/5=2, so k=10.", "topic": "Coordinate Geometry & Circles", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 91, "extra_sources": []}, {"id": "clean:HOA 154", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "959f6d65-594c-55d0-8e01-6b54e424925e", "stem": "Which statement about the line 6y−18=24 is false?", "choices": [{"key": "A", "text": "It crosses the y-axis at 7."}, {"key": "B", "text": "It is horizontal."}, {"key": "C", "text": "It is parallel to the y-axis."}, {"key": "D", "text": "It has slope 0."}], "type": "mcq", "correct": "C", "explanation": "Solve to get y=7. This is a horizontal line, with slope 0 and y-intercept 7. It is parallel to the x-axis, not the y-axis.", "topic": "Coordinate Geometry & Circles", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 92, "extra_sources": []}, {"id": "clean:HOA 155", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "f7928919-18f1-56a2-925b-89faabb0e419", "stem": "If 8^(2x−1)=32, what is x?", "choices": [{"key": "A", "text": "8/6"}, {"key": "B", "text": "6/7"}, {"key": "C", "text": "1/9"}, {"key": "D", "text": "5/7"}], "type": "mcq", "correct": "A", "explanation": "Write 8=2³ and 32=2⁵. Then 3(2x−1)=5, so 6x=8 and x=8/6=4/3.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Enlarged and verified exponent 2x−1. The preceding salary chart is incomplete and remains excluded.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 92, "extra_sources": []}, {"id": "clean:HOA 156", "old_status": "ocr_screened_not_verified", "status": "worked_missing_choice", "note": "For 2x+2y≤−6 the correct graph is the closed half-plane y≤−x−3, with a solid boundary and shading below. Visible B matches and A has the wrong dashed boundary, but C/D are absent. The preceding 17000 LE depreciation question also lacks its rate and duration.", "correct": "B"}]$payload$::jsonb) LOOP
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
