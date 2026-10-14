DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:PAM 039", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "136814dc-095a-5cc0-8b5e-6f5732f1e473", "stem": "For positive a and m, simplify \\([4m\\sqrt{3a}-2\\sqrt{27am^2}+m\\sqrt{12a}]/\\sqrt{243a^5}\\).", "choices": [{"key": "A", "text": "\\(2m/(9a^2)\\)"}, {"key": "B", "text": "\\(m/(9a^2)\\)"}, {"key": "C", "text": "\\(-m/(9a^2)\\)"}, {"key": "D", "text": "0"}], "type": "mcq", "correct": "D", "explanation": "Because m>0, √(27am²)=3m√(3a), and √(12a)=2√(3a). The numerator becomes (4−6+2)m√(3a)=0. The positive denominator is nonzero, so the quotient is 0.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 330, "extra_sources": []}, {"id": "clean:PAM 041", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "72fb159d-811c-533a-9d8d-14dd9a702518", "stem": "Which quadratic function passes through (3,0), (−2,0), and (1,7)?", "choices": [{"key": "A", "text": "f(x)=(7/6)x²+(7/6)x+7"}, {"key": "B", "text": "f(x)=−(7/6)x²+(7/6)x+7"}, {"key": "C", "text": "f(x)=−(7/6)x²−(7/6)x+7"}, {"key": "D", "text": "f(x)=(7/6)x²−(7/6)x+7"}], "type": "mcq", "correct": "B", "explanation": "The roots give f(x)=a(x−3)(x+2). Using (1,7), −6a=7, so a=−7/6. Expanding gives −(7/6)x²+(7/6)x+7.", "topic": "Functions, Transformations & Graphs", "note": "Recovered the fractional coefficients 7/6; the OCR integer coefficients incorrectly made the options appear defective.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 331, "extra_sources": []}, {"id": "clean:PAM 042", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "2858a353-8f4b-5070-a627-18545de9f047", "stem": "What is the real domain of \\(f(x)=\\sqrt{3-x}\\)?", "choices": [{"key": "A", "text": "All real numbers"}, {"key": "B", "text": "x≤3"}, {"key": "C", "text": "x≥3"}, {"key": "D", "text": "−3<x<3"}], "type": "mcq", "correct": "B", "explanation": "The radicand must be nonnegative: 3−x≥0, so x≤3. Equality is allowed because √0 is defined.", "topic": "Functions, Transformations & Graphs", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 331, "extra_sources": []}, {"id": "clean:PAM 043", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "0c56b011-7c45-5f32-9091-71f3295be4c5", "stem": "What is the x-coordinate of the vertex of g(x)=x²−7x−4?", "choices": [], "type": "grid_in", "correct": ["7/2", "3.5"], "explanation": "The vertex x-coordinate is −b/(2a)=7/2=3.5.", "topic": "Functions, Transformations & Graphs", "note": "Isolated complete Q20; preceding triangle diagram belongs to a different question.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 332, "extra_sources": []}, {"id": "clean:PAM 044", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "a18fcfc0-2ce4-5dde-b000-9325cb1cb7f3", "stem": "Let \\(f(x)=1/x-x\\) and \\(g(x)=f(2x)\\). What is g(−3)?", "choices": [], "type": "grid_in", "correct": ["35/6", "5.833333333333333"], "explanation": "Evaluate g(−3)=f(−6)=−1/6−(−6)=35/6. The input −6 is in the domain because it is nonzero.", "topic": "Functions, Transformations & Graphs", "note": "Recovered the rational definition and converted the complete problem to numeric response because options are clipped.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 333, "extra_sources": []}, {"id": "clean:PAM 045", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "8582b2f1-2ab9-522f-958e-a0805cc91e9b", "stem": "For \\(f(x)=(2x+3)/(3x+5)\\), which expression is \\(f^{-1}(x)\\)?", "choices": [{"key": "A", "text": "\\((-5x-3)/(-3x-2)\\)"}, {"key": "B", "text": "\\((-3x-5)/(-3x-2)\\)"}, {"key": "C", "text": "\\((-5x+3)/(3x-2)\\)"}, {"key": "D", "text": "\\((3x+5)/(3x+2)\\)"}], "type": "mcq", "correct": "C", "explanation": "Write y=(2x+3)/(3x+5). Rearranging gives (3y−2)x=3−5y, hence x=(3−5y)/(3y−2). Swap variable names: f⁻¹(x)=(3−5x)/(3x−2), defined for x≠2/3.", "topic": "Functions, Transformations & Graphs", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 333, "extra_sources": []}]$payload$::jsonb) LOOP
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
