DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 144", "old_status": "ocr_screened_not_verified", "status": "defective_choices", "note": "The printed equation (2i+3)(i+5)=7i+m gives 13+13i=7i+m, hence m=13+6i. No listed real choice (17,13,15,11) is correct. If m is intended real, the equation is inconsistent. A corrected original is needed.", "correct": "13+6i"}, {"id": "clean:HOA 146", "old_status": "ocr_screened_not_verified", "status": "needs_source_repair", "note": "For g(x)=2x²+10x−10, g(x)=2 has solutions x=1 and x=−6. The quadratic is not one-to-one on the reals and no branch domain is stated. Thus g⁻¹(2) is not well-defined; do not approve −6 merely because it is listed.", "correct": ["1", "-6"]}, {"id": "clean:HOA 147", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "bbe47b2b-229e-528d-a5d5-ff8fdf82d160", "stem": "What is the greatest integer n satisfying n+6<−1.5?", "choices": [{"key": "A", "text": "−8"}, {"key": "B", "text": "−9"}, {"key": "C", "text": "8"}, {"key": "D", "text": "9"}], "type": "mcq", "correct": "A", "explanation": "Subtract 6 to obtain n<−7.5. The greatest integer below −7.5 is −8.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered C/D from the opening of page 89.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 88, "extra_sources": []}, {"id": "clean:HOA 148", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "6ecf081a-039f-56d1-869f-f41f869bc663", "stem": "Solve the system y=x+3 and y=x²+10x+23.", "choices": [{"key": "A", "text": "(5,8) and (4,7)"}, {"key": "B", "text": "(−2,1) and (2,5)"}, {"key": "C", "text": "(−5,−2) and (−4,−1)"}, {"key": "D", "text": "(−6.41,−3.41) and (−3.59,−0.59)"}], "type": "mcq", "correct": "C", "explanation": "Equating gives x²+9x+20=0=(x+5)(x+4). Thus x=−5 or −4. Substituting in y=x+3 gives (−5,−2) and (−4,−1).", "topic": "Functions, Transformations & Graphs", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 89, "extra_sources": [], "parts": [{"label": "Q18", "question_id": "da25a4d3-0e54-51b5-8409-b5607840e9da", "stem": "Two parallel lines are cut by a transversal. A pair of interior angles on the same side of the transversal measure 50° and (2x+1)°. What is x?", "choices": [], "type": "grid_in", "correct": ["129/2", "64.5"], "explanation": "Same-side interior angles sum to 180°. Thus 50+(2x+1)=180, giving 2x=129 and x=64.5.", "topic": "Coordinate Geometry & Circles", "note": "Verified the positions in the original figure and transcribed them explicitly. Used numeric response because D is missing."}]}, {"id": "clean:HOA 149", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "e8ec8cf7-b913-5fb3-af88-723e48d527d6", "stem": "What is the negative solution of 3(2x−1)²+7=19?", "choices": [{"key": "A", "text": "−1/2"}, {"key": "B", "text": "−3/2"}, {"key": "C", "text": "−2"}, {"key": "D", "text": "−3/4"}], "type": "mcq", "correct": "A", "explanation": "Subtract 7 and divide by 3: (2x−1)²=4. Thus 2x−1=±2, giving x=3/2 or −1/2. The negative solution is −1/2.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 90, "extra_sources": []}, {"id": "clean:HOA 150", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "4bf3fde7-3626-52dd-b088-bbcdcc6c638c", "stem": "An investment of $7000 earns $420 in simple interest over 3 years at an annual rate of x%. What is x?", "choices": [], "type": "grid_in", "correct": "2", "explanation": "Simple interest is I=Prt. Thus 420=7000·(x/100)·3=210x, so x=2.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Verified the principal, interest, and time; numeric response because D is clipped.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 90, "extra_sources": []}]$payload$::jsonb) LOOP
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
