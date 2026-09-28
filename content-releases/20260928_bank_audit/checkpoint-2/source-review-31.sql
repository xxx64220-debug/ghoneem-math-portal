DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:GTC 042", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "3e4657f2-edf3-5f52-abbc-d012cd42aefa", "stem": "What is \\(\\pi/5\\) radians in degrees?", "choices": [{"key": "A", "text": "36°"}, {"key": "B", "text": "288°"}, {"key": "C", "text": "72°"}, {"key": "D", "text": "112°"}], "type": "mcq", "correct": "A", "explanation": "Multiply radians by 180°/π: (π/5)(180°/π)=36°.", "topic": "Coordinate Geometry & Circles", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 395, "extra_sources": []}, {"id": "clean:GTC 045", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "288016c6-e03a-5c04-a505-ebaf2a6eec55", "stem": "An equilateral triangle has perimeter 18. Its altitude is a√3. What is a?", "choices": [], "type": "grid_in", "correct": "3", "explanation": "Each side is 18/3=6. Bisecting the triangle gives altitude √(6²−3²)=√27=3√3, so a=3.", "topic": "Coordinate Geometry & Circles", "note": "Published as numeric response because only the first original choice survives.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 396, "extra_sources": []}, {"id": "clean:GTC 047", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "4e5b592f-0d6f-5a16-b5a1-d406b2102bb1", "stem": "An equilateral triangle has perimeter 18 units. Its area is a√3 square units. What is a?", "choices": [], "type": "grid_in", "correct": "9", "explanation": "Each side is 6. The area is (√3/4)·6²=9√3, so a=9.", "topic": "Coordinate Geometry & Circles", "note": "Corrected adaptation to a numeric coefficient question; the original area choices are incomplete, and the following 16/17 fragment is unrelated.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 397, "extra_sources": []}, {"id": "clean:GTC 048", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "b3f53447-ec31-5db2-8599-29864967cd5d", "stem": "Which line is distinct from and parallel to y=2x+3?", "choices": [{"key": "A", "text": "3y=6x+33"}, {"key": "B", "text": "6x−5y=0"}, {"key": "C", "text": "2y=4x+6"}, {"key": "D", "text": "y=x"}], "type": "mcq", "correct": "A", "explanation": "A simplifies to y=2x+11, with the same slope 2 and a different intercept. C is the original line itself, while B and D have slopes 6/5 and 1.", "topic": "Coordinate Geometry & Circles", "note": "Clarified distinct parallel lines, since choice C represents the coincident original line.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 397, "extra_sources": []}, {"id": "clean:GTC 049", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "7525bf7f-609a-5a22-9e60-e7294de55c94", "stem": "Which constant completes x²−14x+□ as a perfect square, and what is the resulting square?", "choices": [{"key": "A", "text": "49; (x+7)²"}, {"key": "B", "text": "−49; (x+7)²"}, {"key": "C", "text": "49; (x−7)²"}, {"key": "D", "text": "−49; (x−7)²"}], "type": "mcq", "correct": "C", "explanation": "Half the x coefficient is −7 and its square is 49. Expanding (x−7)² gives x²−14x+49.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered missing choices C/D from MIX 030 on page 435 and joined them to the question on page 398.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 398, "extra_sources": []}, {"id": "clean:GTC 050", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "4f82025f-e44b-598d-bcd9-ecdab7d454c0", "stem": "A parallelogram has one side 40 units, perimeter 100 units, and area 320 square units. What is its acute interior angle, rounded to two decimal places?", "choices": [{"key": "A", "text": "97.00°"}, {"key": "B", "text": "17.90°"}, {"key": "C", "text": "100.00°"}, {"key": "D", "text": "53.13°"}], "type": "mcq", "correct": "D", "explanation": "From 2(40+b)=100, the other side is b=10. The area is 40·10·sin θ=320, so sin θ=0.8. The acute solution is θ=arcsin(0.8)≈53.13°.", "topic": "Coordinate Geometry & Circles", "note": "Specified the acute angle and rounding; the obtuse supplementary angle is not the requested angle.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 398, "extra_sources": []}]$payload$::jsonb) LOOP
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
