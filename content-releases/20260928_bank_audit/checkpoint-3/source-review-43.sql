DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:PAM 007", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "6b25c92a-617c-5688-bb95-95ebbd20f4e4", "stem": "For positive x and y with \\(3xy\\ge2\\), which expression equals \\(\\sqrt{27x^3y^5-18x^2y^4}\\)?", "choices": [{"key": "A", "text": "\\(3xy^2(\\sqrt{3xy}-\\sqrt2)\\)"}, {"key": "B", "text": "\\(3xy^2\\sqrt{3xy-2}\\)"}, {"key": "C", "text": "\\(9xy^2\\sqrt{3xy-2}\\)"}, {"key": "D", "text": "\\(9xy^2(\\sqrt{3xy}-\\sqrt2)\\)"}], "type": "mcq", "correct": "B", "explanation": "Factor the radicand as 9x²y⁴(3xy−2). Because x,y are positive, its square root is 3xy²√(3xy−2). A square root does not distribute over subtraction.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Confirmed that one square-root bar spans the entire difference; added the necessary real-radicand condition.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 312, "extra_sources": []}, {"id": "clean:PAM 011", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "c86cdc50-0413-54e5-9ef9-ddbcdc8dbf14", "stem": "A drone is within radio range when its distance from its stationary operator is at most 55 m. Its distance after t seconds is D=4t²+20t. What is the first whole-number time at which it is out of range?", "choices": [{"key": "A", "text": "0 seconds"}, {"key": "B", "text": "1 second"}, {"key": "C", "text": "2 seconds"}, {"key": "D", "text": "3 seconds"}], "type": "mcq", "correct": "C", "explanation": "At t=0,1,2 the distances are 0,24,56 m. The distance increases for t≥0, and 56 exceeds 55. Hence the first whole-number time is 2 seconds. The exact boundary time is (−5+√80)/2≈1.972 seconds.", "topic": "Functions, Transformations & Graphs", "note": "Clarified whole-number time; the continuous-time inequality is strict and has no least time strictly beyond the boundary.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 314, "extra_sources": []}, {"id": "clean:PAM 014", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "2f21f9c8-6ec5-5fe4-af70-0dadb9ca0a22", "stem": "What is the x-coordinate of the vertex of f(x)=3x²−18x+4?", "choices": [], "type": "grid_in", "correct": "3", "explanation": "For ax²+bx+c, the vertex x-coordinate is −b/(2a). Here it is 18/(2·3)=3.", "topic": "Functions, Transformations & Graphs", "note": "Isolated complete Q20 from the preceding triangle fragment.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 315, "extra_sources": []}, {"id": "clean:PAM 015", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "62175592-fc21-5734-9fd9-9b97c5e062e4", "stem": "Let \\(f(x)=(2x^2-7x+5)/(x-4)\\) and \\(g(x)=x^2/3-7\\). What is \\(f(g(3))-f(2)\\)?", "choices": [], "type": "grid_in", "correct": ["-69/8", "-8.625"], "explanation": "First g(3)=9/3−7=−4. Then f(−4)=(32+28+5)/(−8)=−65/8 and f(2)=(8−14+5)/(−2)=1/2. Their difference is −65/8−4/8=−69/8. Both inputs avoid the excluded value 4.", "topic": "Functions, Transformations & Graphs", "note": "Recovered both function definitions. Published numeric response because several original options are clipped; preceding line fragment excluded.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 316, "extra_sources": []}, {"id": "clean:PAM 017", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "23f31530-38e2-5084-802a-84800295583d", "stem": "For which x-values is \\(f(x)=(2x^2-3)/[(x-3)(2x+5)]\\) undefined?", "choices": [{"key": "A", "text": "2.5 and 3"}, {"key": "B", "text": "−2.5 and −3"}, {"key": "C", "text": "2.5 and −3"}, {"key": "D", "text": "−2.5 and 3"}], "type": "mcq", "correct": "D", "explanation": "A rational expression is undefined where its denominator is zero. The factors give x=3 or x=−5/2=−2.5.", "topic": "Functions, Transformations & Graphs", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 317, "extra_sources": []}, {"id": "clean:PAM 021", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "8bbca984-cc7f-5a02-8787-4a71ccca0e01", "stem": "Which expression equals \\((2-a/3)^2-(-2)^2(1+a^2/3)\\)?", "choices": [{"key": "A", "text": "\\(a(11a/3+4)\\)"}, {"key": "B", "text": "\\(-a(11a/3-2)\\)"}, {"key": "C", "text": "\\(-\\frac a3(11a/3+4)\\)"}, {"key": "D", "text": "\\(\\frac a3(11a/3+4)^2\\)"}], "type": "mcq", "correct": "C", "explanation": "Expand to 4−4a/3+a²/9−4−4a²/3=−11a²/9−4a/3. Factoring out −a/3 gives −(a/3)(11a/3+4).", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Restored parentheses and squares from the original image.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 319, "extra_sources": []}]$payload$::jsonb) LOOP
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
