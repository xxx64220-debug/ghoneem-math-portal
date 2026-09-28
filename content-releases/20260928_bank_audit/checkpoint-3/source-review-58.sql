DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 127", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "039dee6e-f8c7-5e92-9847-ba5e2e49886a", "stem": "What is the slope of a line parallel to 2y+x=8?", "choices": [], "type": "grid_in", "correct": ["-1/2", "-0.5"], "explanation": "Rearrange the given equation to y=−x/2+4. Parallel lines have the same slope, −1/2.", "topic": "Coordinate Geometry & Circles", "note": "Original B is coincident with the given line and C is distinct parallel, while A/D are duplicated. Converted to an unambiguous numeric slope question.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 78, "extra_sources": []}, {"id": "clean:HOA 128", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "a1fdadd9-f195-5e59-aa94-01e2080f8363", "stem": "What is the distance on the number line between the roots of x²−2x−8=0?", "choices": [{"key": "A", "text": "8"}, {"key": "B", "text": "6"}, {"key": "C", "text": "4"}, {"key": "D", "text": "10"}], "type": "mcq", "correct": "B", "explanation": "Factor as (x−4)(x+2)=0. The roots are 4 and −2, whose distance is |4−(−2)|=6.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Restored the missing =0 at the end of the polynomial equation.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 79, "extra_sources": [], "parts": [{"label": "Q6", "question_id": "43b46b52-8f9f-5a29-9db0-461137edbbcd", "stem": "The identity x²−3x−10=(x−a)(x+b) holds, and a is a positive integer. What is a?", "choices": [{"key": "A", "text": "5"}, {"key": "B", "text": "2"}, {"key": "C", "text": "4"}, {"key": "D", "text": "10"}], "type": "mcq", "correct": "A", "explanation": "Factor x²−3x−10=(x−5)(x+2). The positive root is a=5. The alternative assignment would make a=−2, which violates positivity.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "The following hand-annotated sector question has unclear angle/radius data and remains excluded."}]}, {"id": "clean:HOA 129", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "0b8bebe9-b7ce-5835-9efd-2091ec06df7f", "stem": "What is the real solution of √(2x+4)=x−2?", "choices": [{"key": "A", "text": "0"}, {"key": "B", "text": "4"}, {"key": "C", "text": "6"}, {"key": "D", "text": "8"}], "type": "mcq", "correct": "C", "explanation": "The right side requires x≥2. Squaring gives 2x+4=x²−4x+4, or x(x−6)=0. Reject 0 because it violates x≥2; 6 satisfies √16=4=6−2.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 80, "extra_sources": [], "parts": [{"label": "Q10", "question_id": "f2cb2a9b-d366-5d98-a939-f5bf859156ef", "stem": "If 3x+5=81, what is 15x?", "choices": [{"key": "A", "text": "280"}, {"key": "B", "text": "380"}, {"key": "C", "text": "25.3"}, {"key": "D", "text": "122.5"}], "type": "mcq", "correct": "B", "explanation": "Subtract 5 to get 3x=76, then multiply by 5: 15x=380.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Split from the original shared crop; original PDF visually checked and solution independently verified."}]}, {"id": "clean:HOA 130", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "bbded6eb-b32f-5747-b13d-434dfc49355b", "stem": "Which equation represents a line perpendicular to 2y=3x+4?", "choices": [{"key": "A", "text": "y=3x/2+5"}, {"key": "B", "text": "5y=2x−5"}, {"key": "C", "text": "3y=−2x+11"}, {"key": "D", "text": "2y=−3x+10"}], "type": "mcq", "correct": "C", "explanation": "The original slope is 3/2; a perpendicular slope is −2/3. Choice C becomes y=−2x/3+11/3.", "topic": "Coordinate Geometry & Circles", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 81, "extra_sources": []}, {"id": "clean:HOA 131", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "ec6a3917-bfc6-5a6d-a175-c5268f9fe921", "stem": "If x+y+z=6 and 2x+2y+z=9, what is z?", "choices": [{"key": "A", "text": "2"}, {"key": "B", "text": "6"}, {"key": "C", "text": "3"}, {"key": "D", "text": "9"}], "type": "mcq", "correct": "C", "explanation": "Twice the first equation is 2x+2y+2z=12. Subtracting the second gives z=3.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 81, "extra_sources": []}, {"id": "clean:HOA 134", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "216c2e58-5af7-559b-8f23-3d524323281f", "stem": "One intersection of y=2x+1 and y=x²+x+1 is (a,b). Which listed number could b be?", "choices": [{"key": "A", "text": "2"}, {"key": "B", "text": "−1"}, {"key": "C", "text": "0"}, {"key": "D", "text": "3"}], "type": "mcq", "correct": "D", "explanation": "Equating gives x²−x=0, so x=0 or 1. The corresponding y-values are 1 and 3. Only 3 is listed.", "topic": "Functions, Transformations & Graphs", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 82, "extra_sources": []}]$payload$::jsonb) LOOP
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
