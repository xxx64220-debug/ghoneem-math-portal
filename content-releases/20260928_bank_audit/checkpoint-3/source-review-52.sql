DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 085", "old_status": "ocr_screened_not_verified", "status": "needs_source_reconstruction", "note": "Visually matches the $1950 brochure-budget item FA 041, but both source crops omit the brochure cost model. The existing transcription 79+0.44n would give 4252 brochures, but the missing model has not been verified from an original source. Retain the hold.", "correct": null}, {"id": "clean:HOA 086", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "6e9fced1-4284-5f4b-8921-26daa96748b0", "stem": "Which line passes through (3,4) and is parallel to y=−2x+5?", "choices": [{"key": "A", "text": "y=−2x+3"}, {"key": "B", "text": "y=x/2+10"}, {"key": "C", "text": "y=−2x+10"}, {"key": "D", "text": "y=2x"}], "type": "mcq", "correct": "C", "explanation": "A parallel line has slope −2. Substituting (3,4) in y=−2x+b gives 4=−6+b, so b=10. The line is y=−2x+10.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 55, "extra_sources": []}, {"id": "clean:HOA 087", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "222beb0f-105f-5f02-82e6-db8beab21776", "stem": "If 3^(2x−1)=27, what is x/2+3?", "choices": [{"key": "A", "text": "3"}, {"key": "B", "text": "0"}, {"key": "C", "text": "5"}, {"key": "D", "text": "4"}], "type": "mcq", "correct": "D", "explanation": "Since 27=3³, equal bases give 2x−1=3, hence x=2. Then x/2+3=1+3=4.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 56, "extra_sources": []}, {"id": "clean:HOA 088", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "b6a07123-513e-50c5-bb44-84d92137a7a3", "stem": "Which listed number is a solution of 3−8x+5x²=0?", "choices": [{"key": "A", "text": "0"}, {"key": "B", "text": "2"}, {"key": "C", "text": "−1"}, {"key": "D", "text": "1"}], "type": "mcq", "correct": "D", "explanation": "Factor 5x²−8x+3=(5x−3)(x−1). The roots are 3/5 and 1; only 1 is listed.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 56, "extra_sources": []}, {"id": "clean:HOA 089", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "b48a56d6-8c2f-5077-bb63-5e7235ace7c1", "stem": "What is the least integer k such that (k+5+6)/3>15?", "choices": [{"key": "A", "text": "34"}, {"key": "B", "text": "35"}, {"key": "C", "text": "33"}, {"key": "D", "text": "36"}], "type": "mcq", "correct": "B", "explanation": "Multiply by 3 and subtract 11: k>45−11=34. The least integer strictly greater than 34 is 35.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 56, "extra_sources": []}, {"id": "clean:HOA 090", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "533c4b25-f0ef-56d8-b11f-458782e03fff", "stem": "A positive number n is twice as far from 9 as it is from 3 on the number line. What is n?", "choices": [], "type": "grid_in", "correct": "5", "explanation": "The distance equation is |n−9|=2|n−3|. Squaring and simplifying gives n²−2n−15=0, or (n−5)(n+3)=0. The roots are 5 and −3. Positivity selects 5; its distances are 4 and 2.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Isolated the complete number-line problem; incomplete preceding composition excluded.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 57, "extra_sources": []}]$payload$::jsonb) LOOP
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
