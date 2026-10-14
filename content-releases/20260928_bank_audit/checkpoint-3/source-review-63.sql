DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 179", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "97a4e8db-e914-5a56-a4c6-f3b6efe36600", "stem": "For what a does the system 2x+5y=1/5 and 5x+ay=2/25 have no solution?", "choices": [{"key": "A", "text": "25/2"}, {"key": "B", "text": "1/2"}, {"key": "C", "text": "1.9"}, {"key": "D", "text": "11"}], "type": "mcq", "correct": "A", "explanation": "The lines must be parallel with different intercepts. Multiplying the first left side by 5/2 gives 5x+(25/2)y, so a=25/2. Its right side would be 1/2, which differs from 2/25; hence the lines are distinct and the system is inconsistent.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 104, "extra_sources": [], "parts": [{"label": "Q13", "question_id": "8e9348c2-eb8d-53b0-92c8-e8b452bde1a3", "stem": "In triangle ABC, D and E are the midpoints of AB and AC. If DE=4x−3 and BC=2x+3, what is x?", "choices": [{"key": "A", "text": "2.5"}, {"key": "B", "text": "1.5"}, {"key": "C", "text": "2.25"}, {"key": "D", "text": "1.25"}], "type": "mcq", "correct": "B", "explanation": "The midsegment theorem gives DE=BC/2. Thus 4x−3=(2x+3)/2, giving 8x−6=2x+3 and x=9/6=1.5. Both lengths are positive.", "topic": "Coordinate Geometry & Circles", "note": "Transcribed the full midpoint relation and segment labels from the figure."}]}, {"id": "clean:HOA 180", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "a9047443-b24d-56d3-bda2-9b30ec1bd1fb", "stem": "If 2x−5y=−7 and 5x−3y=11, what is y?", "choices": [{"key": "A", "text": "4"}, {"key": "B", "text": "4/7"}, {"key": "C", "text": "2"}, {"key": "D", "text": "3"}], "type": "mcq", "correct": "D", "explanation": "Multiply the first equation by 5 and the second by 2: 10x−25y=−35 and 10x−6y=22. Subtract to get 19y=57, hence y=3.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 105, "extra_sources": []}, {"id": "clean:HOA 181", "old_status": "ocr_screened_not_verified", "status": "worked_missing_choice", "note": "The altitude through A=(4,7) to BC on y=2x+3 has equation y=−(1/2)(x−4)+7. Visible B is correct, but original D is missing. Formula and point substitution verified.", "correct": "B"}, {"id": "clean:HOA 182", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "9c5bb9d8-9750-5bcc-897c-a249167c1cf0", "stem": "How many ordered-pair solutions does the system y=x²−2 and x=2 have?", "choices": [{"key": "A", "text": "0"}, {"key": "B", "text": "1"}, {"key": "C", "text": "2"}, {"key": "D", "text": "3"}], "type": "mcq", "correct": "B", "explanation": "The second equation fixes x=2. The first then fixes y=4−2=2. There is exactly one ordered pair, (2,2).", "topic": "Functions, Transformations & Graphs", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 105, "extra_sources": []}, {"id": "clean:HOA 183", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "99552b0c-1dbc-5c48-ba3e-7409e085db43", "stem": "How many distinct positive zeros does y=x⁴−3x³+2x² have?", "choices": [{"key": "A", "text": "0"}, {"key": "B", "text": "1"}, {"key": "C", "text": "2"}, {"key": "D", "text": "3"}], "type": "mcq", "correct": "C", "explanation": "Factor x⁴−3x³+2x²=x²(x−1)(x−2). The distinct zeros are 0,1,2. Only 1 and 2 are positive, so there are two.", "topic": "Functions, Transformations & Graphs", "note": "Repaired the incomplete “positive solutions” wording by explicitly asking for positive zeros of the displayed function.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 106, "extra_sources": []}, {"id": "clean:HOA 184", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "bb6c8acb-c9e2-532c-ba7d-3306a0d10091", "stem": "Point N has x-coordinate 8 and lies on the perpendicular bisector of the segment joining (1,−3) and (−4,5). What is its y-coordinate?", "choices": [{"key": "A", "text": "111/16"}, {"key": "B", "text": "−3/2"}, {"key": "C", "text": "−8/5"}, {"key": "D", "text": "−18/16"}], "type": "mcq", "correct": "A", "explanation": "The midpoint is (−3/2,1), and the segment’s slope is −8/5. Its perpendicular bisector has slope 5/8. At x=8, y=1+(5/8)(8+3/2)=1+95/16=111/16.", "topic": "Coordinate Geometry & Circles", "note": "Verified the bisector question. Separate fruit chart counts total 47 (5+8+12+12+4+6), giving k=3600/47; none of its choices is correct. That defective fragment remains unpublished.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 107, "extra_sources": []}]$payload$::jsonb) LOOP
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
