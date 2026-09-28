DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 052", "old_status": "worked_needs_crop", "status": "ready", "question_id": "ff978f0d-c3cc-542c-bfbf-4b5b8dbf28ff", "stem": "If \\(\\frac12y-\\frac35x=-6\\), what is \\(6x-5y\\)?", "choices": [], "type": "grid_in", "correct": "60", "explanation": "Multiply both sides by −10: \\(-5y+6x=60\\). This is exactly \\(6x-5y\\), so the answer is 60.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Source page 36 visually checked; isolated complete Q17.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 36, "extra_sources": []}, {"id": "clean:HOA 053", "old_status": "worked_needs_crop", "status": "ready", "question_id": "608d0635-39a1-58ee-8a41-61e352f0db81", "stem": "If \\((3^9)^{3^{12}}=3^{3^x}\\), what is x?", "choices": [], "type": "grid_in", "correct": "14", "explanation": "The power rule gives \\((3^9)^{3^{12}}=3^{9\\cdot3^{12}}=3^{3^{14}}\\). Since the exponential function with base 3 is one-to-one, \\(3^x=3^{14}\\), so x = 14.", "topic": "Rational, Radical, Exponential & Logarithmic Functions", "note": "Nested exponents visually checked on page 37; unrelated preceding fragment removed.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 37, "extra_sources": []}, {"id": "clean:HOA 005", "old_status": "worked_missing_choice", "status": "ready", "question_id": "c273bdc5-f808-5dce-a9a1-35c650221a5e", "stem": "For a four-digit PIN abcd, the secret value k is found by subtracting three times b from c, then dividing by half the sum of a and d. Which expression gives k, assuming a + d is nonzero?", "choices": [{"key": "A", "text": "\\(\\frac{c-3b}{2a+2d}\\)"}, {"key": "B", "text": "\\(\\frac{b-3c}{2a+2d}\\)"}, {"key": "C", "text": "\\(\\frac{2c-6b}{a+d}\\)"}, {"key": "D", "text": "\\(\\frac{6b-2c}{a+d}\\)"}], "type": "mcq", "correct": "C", "explanation": "The instructions give \\(k=(c-3b)/((a+d)/2)\\). Dividing by one-half the sum is multiplying by \\(2/(a+d)\\), so \\(k=(2c-6b)/(a+d)\\).", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered missing choice D from PSD 006 on page 149; original stem and A–C checked on page 5.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 5, "extra_sources": []}, {"id": "clean:HOA 054", "old_status": "worked_needs_crop", "status": "ready", "question_id": "3d79b5c1-fe84-5cba-96da-2a470fbf0121", "stem": "If \\(-\\frac45x+3\\ge2-\\frac15x\\), what is the greatest possible value of \\(\\frac32x+4\\)?", "choices": [{"key": "A", "text": "3.5"}, {"key": "B", "text": "4.5"}, {"key": "C", "text": "5.5"}, {"key": "D", "text": "6.5"}], "type": "mcq", "correct": "D", "explanation": "The inequality simplifies to \\(1\\ge3x/5\\), so \\(x\\le5/3\\). The expression \\(3x/2+4\\) increases with x, so its greatest value occurs at x = 5/3 and is \\(5/2+4=6.5\\).", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original compiled PDF page 38 visually checked; complete question retyped separately from unrelated fragments.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 38, "extra_sources": []}, {"id": "clean:HOA 064", "old_status": "worked_needs_crop", "status": "ready", "question_id": "82d56026-8a01-5f1d-b747-381272a2a54d", "stem": "What is the product of the real solutions of \\(\\sqrt{x^2-5x+8}=2\\)?", "choices": [], "type": "grid_in", "correct": "4", "explanation": "Squaring gives \\(x^2-5x+8=4\\), or \\((x-1)(x-4)=0\\). Both x = 1 and x = 4 make the original radicand 4, so both satisfy the original equation. Their product is 4.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original compiled PDF page 43 visually checked; complete question retyped separately from unrelated fragments.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 43, "extra_sources": []}, {"id": "clean:HOA 065", "old_status": "partial_multi_question", "status": "ready", "question_id": "6769cf25-b015-5fc3-8573-c3519cf77dd8", "stem": "If \\(3x=24y\\) and \\(x\\ne0\\), what is \\((3y/x)^2\\)?", "choices": [{"key": "A", "text": "9/64"}, {"key": "B", "text": "3/4"}, {"key": "C", "text": "8/3"}, {"key": "D", "text": "24"}], "type": "mcq", "correct": "A", "explanation": "Dividing \\(3x=24y\\) by 24x gives \\(y/x=1/8\\). Therefore \\((3y/x)^2=(3/8)^2=9/64\\).", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original compiled PDF page 43 visually checked; complete question retyped separately from unrelated fragments.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 43, "extra_sources": []}]$payload$::jsonb) LOOP
  SELECT * INTO s FROM public.est_source_review WHERE id=v->>'id' FOR UPDATE;
  IF s.id IS NULL THEN RAISE EXCEPTION 'Missing source %',v->>'id'; END IF;
  IF EXISTS(SELECT 1 FROM public.audit_log WHERE action='source_review_20260928' AND target_id=s.id) THEN CONTINUE; END IF;
  IF s.review_status<>v->>'old_status' THEN RAISE EXCEPTION 'Source status changed %',s.id; END IF;
  qid=nullif(v->>'question_id','')::uuid;
  IF qid IS NOT NULL AND EXISTS(SELECT 1 FROM public.exams e JOIN public.attempts t ON t.exam_id=e.id
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
  INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES('source_review_20260928','source_review',s.id,
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
  END IF;
  UPDATE public.est_source_review SET review_status=v->>'status',question_id=coalesce(qid,question_id),
   worked_answer=coalesce(v->'correct',worked_answer),duplicate_of=coalesce(v->>'duplicate_of',duplicate_of),
   review_note='Rechecked 2026-09-28. '||coalesce(v->>'note','')||CASE WHEN v ? 'explanation' THEN E'\nWorked solution: '||(v->>'explanation') ELSE '' END,
   updated_at=now() WHERE id=s.id;
 END LOOP;
END;
$review$;
SELECT count(*) applied_source_decisions FROM public.audit_log WHERE action='source_review_20260928';
