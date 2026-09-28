DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 157", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "9858b521-d789-59be-b89a-a2550959db7f", "stem": "What is the positive solution of |2x−2|=6?", "choices": [], "type": "grid_in", "correct": "4", "explanation": "The two branches are 2x−2=6 and 2x−2=−6, giving x=4 and x=−2. The positive solution is 4.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Converted to a positive-root numeric response because original D is absent and the original singular wording does not distinguish both roots.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 94, "extra_sources": []}, {"id": "clean:HOA 158", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "6ca035ef-fe2d-56fc-b516-227048937da8", "stem": "Squares of side x inches are removed from the corners of an 8 by 12 inch sheet, then its sides are folded up to make an open box. For 0<x<4, which inequality describes a volume of at least 60 in³?", "choices": [{"key": "A", "text": "x³−10x²+24x≤15"}, {"key": "B", "text": "x³−10x²+24x≥15"}, {"key": "C", "text": "x³−20x²+96x≥60"}, {"key": "D", "text": "x³−20x²+96x≤60"}], "type": "mcq", "correct": "B", "explanation": "The dimensions are x, 8−2x, and 12−2x. Thus x(8−2x)(12−2x)≥60. Expanding gives 4x³−40x²+96x≥60; dividing by 4 gives x³−10x²+24x≥15.", "topic": "Coordinate Geometry & Circles", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 94, "extra_sources": []}, {"id": "clean:HOA 174", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "e548b0e4-e5cd-55d4-b378-fb2908c07471", "stem": "If 8^(3x+2)=32, what is 9x+1?", "choices": [{"key": "A", "text": "0"}, {"key": "B", "text": "1"}, {"key": "C", "text": "3"}, {"key": "D", "text": "9"}], "type": "mcq", "correct": "A", "explanation": "Convert to base 2: 3(3x+2)=5, so 9x+6=5. Subtract 5 to get 9x+1=0.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered B/C/D from page 102. The preceding triangle is cut off and remains excluded.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 101, "extra_sources": []}, {"id": "clean:HOA 175", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "af033971-6ce0-515b-908e-b9a70ad16c78", "stem": "For real x,y and i²=−1, 5xi+2y+5=2x+(4y+2)i. What is x?", "choices": [{"key": "A", "text": "1.7"}, {"key": "B", "text": "1.8"}, {"key": "C", "text": "−8"}, {"key": "D", "text": "−21/2"}], "type": "mcq", "correct": "C", "explanation": "Equate real parts: 2y+5=2x, so y=x−5/2. Equate imaginary parts: 5x=4y+2. Substitution gives 5x=4x−10+2, hence x=−8.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 102, "extra_sources": []}, {"id": "clean:HOA 177", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "a5be5891-fcd8-569c-aeb4-fb25b2bf031e", "stem": "What is the product of the roots of 3(4x−1)(2x−11)=0?", "choices": [{"key": "A", "text": "1/4"}, {"key": "B", "text": "11/2"}, {"key": "C", "text": "11/8"}, {"key": "D", "text": "23/4"}], "type": "mcq", "correct": "C", "explanation": "The constant factor 3 is nonzero. The roots are 1/4 and 11/2, whose product is 11/8.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 102, "extra_sources": []}, {"id": "clean:HOA 178", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "fde5ee86-c964-55be-8548-33074868cfe6", "stem": "Solve 3x−y=4 and 2x+y=6 by substitution. Steps: I, add the equations to get x=2; II, solve the substituted equation to get y=2; III, substitute x=(y+4)/3 into the second equation to get 2(y+4)/3+y=6; IV, isolate x=(y+4)/3 in the first equation; VI, substitute y=2 to get x=2. Which order uses substitution?", "choices": [{"key": "A", "text": "IV–I–III–II"}, {"key": "B", "text": "III–VI–I–IV–II"}, {"key": "C", "text": "IV–III–II–VI"}, {"key": "D", "text": "VI–I–IV–III"}], "type": "mcq", "correct": "C", "explanation": "First isolate x (IV), substitute into the second equation (III), solve 2y+8+3y=18 to get y=2 (II), and substitute back to get x=2 (VI). Step I describes elimination and is not needed.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered D from page 104 and corrected the misplaced closing parenthesis in step III. Preserved the source’s step label VI.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 103, "extra_sources": []}]$payload$::jsonb) LOOP
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
