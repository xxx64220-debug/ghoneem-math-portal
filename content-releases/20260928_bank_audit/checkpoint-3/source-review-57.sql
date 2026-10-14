DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 120", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "24150e31-432d-5c42-92ba-1be0c3bff293", "stem": "Line M is perpendicular to line L, whose equation is 2y−5(x+y)=4. What is the slope of M?", "choices": [], "type": "grid_in", "correct": ["3/5", "0.6"], "explanation": "Simplify L to −5x−3y=4, so y=−5x/3−4/3. Its slope is −5/3. The perpendicular slope is the negative reciprocal, 3/5.", "topic": "Coordinate Geometry & Circles", "note": "Used numeric response because the final choices are missing.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 74, "extra_sources": []}, {"id": "clean:HOA 122", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "42d786db-fe2f-5888-8fa2-1fecf2f5a0de", "stem": "At 9:30,10:00,10:30,11:00,11:30, the distances for car A are 1,3,9,27,81 km and those for car B are 12,27,42,57,72 km. Which statement is true?", "choices": [{"key": "A", "text": "Both distance patterns are linear."}, {"key": "B", "text": "Both distance patterns are exponential."}, {"key": "C", "text": "A is exponential, B is linear, and A travels farther from 11:00 to 11:30."}, {"key": "D", "text": "A is linear, B is exponential, and B travels farther from 11:00 to 11:30."}], "type": "mcq", "correct": "C", "explanation": "A’s values multiply by 3 every half-hour, an exponential pattern. B’s values increase by 15, a linear pattern. In the last interval A travels 81−27=54 km, while B travels 72−57=15 km, so A travels farther.", "topic": "Functions, Transformations & Graphs", "note": "Transcribed the full table. The last-interval difference is 54, not the preceding interval’s 18.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 76, "extra_sources": []}, {"id": "clean:HOA 123", "old_status": "ocr_screened_not_verified", "status": "needs_source_reconstruction", "note": "The exponent on 27 and the exponent on 3 are too blurred to transcribe reliably, and only choice A remains. Retain until a sharper original is available.", "correct": null}, {"id": "clean:HOA 124", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "5311ec33-2195-5f23-bf90-6a99577224f7", "stem": "If 2x+3y=−1 and y−2x=−3, what is x+y?", "choices": [{"key": "A", "text": "1"}, {"key": "B", "text": "0"}, {"key": "C", "text": "8"}, {"key": "D", "text": "−8"}], "type": "mcq", "correct": "B", "explanation": "Adding the equations gives 4y=−4, so y=−1. Then −1−2x=−3 gives x=1. Hence x+y=0.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 77, "extra_sources": []}, {"id": "clean:HOA 125", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "cb0e3476-aa1f-5bf0-87f3-ceb8f913d593", "stem": "What is the y-coordinate of the vertex of y=x²−10x+1?", "choices": [], "type": "grid_in", "correct": "-24", "explanation": "Complete the square: y=(x−5)²−24. Thus the vertex is (5,−24), whose y-coordinate is −24.", "topic": "Functions, Transformations & Graphs", "note": "The original options omit the negative y-coordinate. Published as a numeric vertex-coordinate question with the verified result; incomplete preceding end-behavior fragment excluded.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 77, "extra_sources": []}, {"id": "clean:HOA 126", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "07559ba8-c298-5a24-beb4-0b81e137c96b", "stem": "If 20° equals aπ/9 radians, what is a?", "choices": [{"key": "A", "text": "1"}, {"key": "B", "text": "2"}, {"key": "C", "text": "π"}, {"key": "D", "text": "2π"}], "type": "mcq", "correct": "A", "explanation": "Convert degrees to radians: 20·π/180=π/9. Comparing to aπ/9 gives a=1.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Restored the degree unit in the angle-to-radian conversion.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 78, "extra_sources": []}]$payload$::jsonb) LOOP
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
