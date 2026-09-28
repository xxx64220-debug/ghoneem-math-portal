DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:MIX 014", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "0f936c8d-b2be-5974-8686-39ac98a729e7", "stem": "Three friends divide a prize. The youngest receives 3/5, the middle friend 1/4, and the eldest the remaining $57. What is the total prize?", "choices": [{"key": "A", "text": "$380"}, {"key": "B", "text": "$420"}, {"key": "C", "text": "$140"}, {"key": "D", "text": "$270"}], "type": "mcq", "correct": "A", "explanation": "The remaining fraction is 1−3/5−1/4=3/20. Thus (3/20)P=57 and P=57·20/3=$380.", "topic": "Statistics, Probability & Data Analysis", "note": "Recovered both printed fractions, also visible in the duplicate MIX 031.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 427, "extra_sources": []}, {"id": "clean:MIX 015", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "f8422f89-aa76-5dc1-a62a-334a17077a2b", "stem": "For real a and nonzero b, a/b is negative. Which expression is definitely negative?", "choices": [{"key": "A", "text": "2ab"}, {"key": "B", "text": "a²b"}, {"key": "C", "text": "(b−a)²"}, {"key": "D", "text": "a−b"}], "type": "mcq", "correct": "A", "explanation": "Since b²>0, ab=(a/b)b²<0, so 2ab<0. The square is nonnegative; a²b and a−b can have either sign depending on which variable is positive.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Confirmed that A is 2ab and B is a²b; OCR incorrectly omitted the square in B.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 427, "extra_sources": []}, {"id": "clean:MIX 017", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "c4aee271-9096-5d06-b9d0-2c96f06f5fc8", "stem": "If a+b>0 and a−c<0, which statement must hold?", "choices": [{"key": "A", "text": "b+c<0 and a<c"}, {"key": "B", "text": "b+c>0 and a<c"}, {"key": "C", "text": "b+c<0 and a>c"}, {"key": "D", "text": "b+c>0 and a>c"}], "type": "mcq", "correct": "B", "explanation": "The second inequality gives c−a>0 and a<c. Adding c−a>0 to a+b>0 yields b+c>0. Thus both statements in B hold.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 428, "extra_sources": []}, {"id": "clean:MIX 018", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "66c17106-d5ad-5d0f-be29-e46d9eb91cdd", "stem": "For \\(w\\ne0\\), multiplying \\(1/(5w)+2/w^2=1/3\\) by \\(15w^2\\) and rearranging gives \\(5w^2+kw-30=0\\). What is k?", "choices": [{"key": "A", "text": "1"}, {"key": "B", "text": "−1"}, {"key": "C", "text": "3"}, {"key": "D", "text": "−3"}], "type": "mcq", "correct": "D", "explanation": "Multiplying gives 3w+30=5w². Move every term to the right: 5w²−3w−30=0. Therefore k=−3.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered the fractional equation and repaired the original incomplete “identical” wording to an explicit equivalent polynomial equation.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 429, "extra_sources": []}, {"id": "clean:MIX 019", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "4bc4c178-17c1-5b9b-9745-942182ddfa9d", "stem": "Simplify (6m⁴n−8mn)+(−m⁴n+2mn+5)+(3mn+8).", "choices": [{"key": "A", "text": "5m⁴n−7mn+13"}, {"key": "B", "text": "5m⁴n−3mn+13"}, {"key": "C", "text": "6m⁴n−3mn−8"}, {"key": "D", "text": "7m⁴n−5mn+13"}], "type": "mcq", "correct": "B", "explanation": "Combine like terms: the m⁴n coefficient is 6−1=5, the mn coefficient is −8+2+3=−3, and the constant is 5+8=13.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Enlarged source confirms power 4, not the OCR power 2, and middle coefficient 2.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 429, "extra_sources": []}, {"id": "clean:MIX 020", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "15f9fdad-ef0e-5330-88e5-ba8dd8f4ddf9", "stem": "For \\(x\\ne-1,0,1\\), combine \\(2x/[3(x^2-1)]+(4x-1)/[x(x+1)]\\) over the denominator \\(3x(x^2-1)\\). If the numerator is the polynomial A(x), what is A(−1)?", "choices": [{"key": "A", "text": "2"}, {"key": "B", "text": "16"}, {"key": "C", "text": "40"}, {"key": "D", "text": "32"}], "type": "mcq", "correct": "D", "explanation": "The numerator is A(x)=2x²+3(4x−1)(x−1)=14x²−15x+3. Thus A(−1)=14+15+3=32. The original rational expression is undefined at −1; this question evaluates its numerator polynomial only.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered choice D=32 from the opening of HOA 121, page 75. Specified the common denominator to make A unique and distinguished the polynomial value from the undefined rational expression.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 429, "extra_sources": []}]$payload$::jsonb) LOOP
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
