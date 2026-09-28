DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:PAM 058", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "3b4a2d49-264a-592c-8535-7a83e607d271", "stem": "If f(x)=x²−3x and g(x)=2x+2, what is f(x)g(x)?", "choices": [{"key": "A", "text": "2x³−4x²−6x"}, {"key": "B", "text": "2x³−14x²+6x"}, {"key": "C", "text": "2x³−4x²+6x"}, {"key": "D", "text": "2x³−4x²"}], "type": "mcq", "correct": "A", "explanation": "Distribute: (x²−3x)(2x+2)=2x³+2x²−6x²−6x=2x³−4x²−6x.", "topic": "Functions, Transformations & Graphs", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 342, "extra_sources": []}, {"id": "clean:PAM 059", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "2b566ea1-6c79-5417-9d1e-65a92b7e57ed", "stem": "For \\(x\\ne-1,1\\), simplify \\(1/(1-x)+x/(x^2-1)\\).", "choices": [{"key": "A", "text": "\\(-1/(x^2-1)\\)"}, {"key": "B", "text": "\\(1/(x^2-1)\\)"}, {"key": "C", "text": "\\((2x+1)/(x^2-1)\\)"}, {"key": "D", "text": "\\((x+1)/(-x^2+x^2+x-1)\\)"}], "type": "mcq", "correct": "A", "explanation": "Since 1/(1−x)=−(x+1)/(x²−1), the sum is [−(x+1)+x]/(x²−1)=−1/(x²−1). The original exclusions remain.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Verified each fraction and the literal repeated x² terms in distractor D at enlarged resolution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 343, "extra_sources": []}, {"id": "clean:PAM 060", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "45aa96f1-770c-52be-83e2-e492676a9795", "stem": "The graph of \\(f(x)=(ax^2+bx+c)/(x-2)\\) has a removable hole at (a,1). What is a?", "choices": [{"key": "A", "text": "1"}, {"key": "B", "text": "2"}, {"key": "C", "text": "7"}, {"key": "D", "text": "3"}], "type": "mcq", "correct": "B", "explanation": "The only excluded input is x=2, so a hole must have x-coordinate 2. Since its coordinate is labeled a, a=2. The condition is consistent, for example with b=−7,c=6: f(x)=2x−3 for x≠2, whose limit at 2 is 1.", "topic": "Functions, Transformations & Graphs", "note": "Recovered denominator x−2 and checked that the reused parameter a is consistent with the hole condition.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 343, "extra_sources": []}, {"id": "clean:PAM 069", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "19a5ef6a-d421-510d-9791-9696bd9ffcbf", "stem": "For real x,y,z, which expression is equivalent to \\(\\sqrt[3]{540y^5x^6z^3}\\)?", "choices": [{"key": "A", "text": "\\(3x^3y^4z^6\\sqrt[3]{20y}\\)"}, {"key": "B", "text": "\\(x^2yz^3\\sqrt[3]{540y^2x^3}\\)"}, {"key": "C", "text": "\\(x^2yz\\sqrt[3]{540y^2}\\)"}, {"key": "D", "text": "\\(3xy^3z^3\\sqrt[3]{20y^2x^4}\\)"}], "type": "mcq", "correct": "C", "explanation": "Factor out the perfect cube x⁶y³z³: the cube root becomes x²yz∛(540y²), choice C. It can be simplified further to 3x²yz∛(20y²). Cube roots preserve the sign of real factors.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered radical index 3 and exponents 5,6,3; C is equivalent even though its numerical cube factor is not fully extracted.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 348, "extra_sources": []}, {"id": "clean:PAM 070", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "d6d99a6f-43e1-5c7b-b4d8-b3af491aa0ce", "stem": "If f(x)=x⁵+2x⁴−3 and g(x)=x⁵−x⁴+5x³−20, what is f(x)−g(x)?", "choices": [{"key": "A", "text": "3x⁴−5x³−17"}, {"key": "B", "text": "3x⁴−5x³+17"}, {"key": "C", "text": "3x⁴−5x³−23"}, {"key": "D", "text": "3x⁴+5x³+17"}], "type": "mcq", "correct": "B", "explanation": "Distribute the subtraction: x⁵+2x⁴−3−x⁵+x⁴−5x³+20=3x⁴−5x³+17.", "topic": "Functions, Transformations & Graphs", "note": "Verified powers 5,4,3 from the source.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 349, "extra_sources": []}, {"id": "clean:PAM 071", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "fb0daf18-09d8-590c-ad7f-5a68e0fb51c5", "stem": "For nonzero R and C, isolate L in \\(R=LC/R\\).", "choices": [{"key": "A", "text": "\\(R^2/C\\)"}, {"key": "B", "text": "\\(R^2/2\\)"}, {"key": "C", "text": "\\(R^2C\\)"}, {"key": "D", "text": "\\(\\sqrt{RC}\\)"}], "type": "mcq", "correct": "A", "explanation": "Multiply by R to obtain R²=LC, then divide by nonzero C: L=R²/C.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered the supplied algebraic equation and included its required nonzero denominators.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 350, "extra_sources": []}]$payload$::jsonb) LOOP
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
