DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:PAM 024", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "b807fee5-3724-5a5c-8a11-a7919e8c6db9", "stem": "Positive quantities satisfy \\(I=P/(4\\pi D^2)\\). Which expression equals D?", "choices": [{"key": "A", "text": "\\(2\\sqrt{\\pi I/P}\\)"}, {"key": "B", "text": "\\(\\frac12\\sqrt{P/(\\pi I)}\\)"}, {"key": "C", "text": "\\((P/(4\\pi I))^2\\)"}, {"key": "D", "text": "\\(\\sqrt{P/(2\\pi I)}\\)"}], "type": "mcq", "correct": "B", "explanation": "Rearrange to D²=P/(4πI). Since D is positive, D=(1/2)√[P/(πI)].", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 321, "extra_sources": []}, {"id": "clean:PAM 027", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "9c8b2be6-3568-54ff-9945-8f6cdbf498a7", "stem": "For positive k and m, which expression equals \\((16k^{12}m^4)^{1/4}\\)?", "choices": [{"key": "A", "text": "4k³m"}, {"key": "B", "text": "2k³"}, {"key": "C", "text": "4k³m²"}, {"key": "D", "text": "2k³m"}], "type": "mcq", "correct": "D", "explanation": "Take the fourth root of each positive factor: 16^(1/4)=2, k^(12/4)=k³, and m^(4/4)=m. The result is 2k³m.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Verified all variable exponents and the fractional power 1/4.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 323, "extra_sources": []}, {"id": "clean:PAM 029", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "dc7b3a9c-fccc-5405-98d6-a658946b6cef", "stem": "Let f(x)=−3−2x and g(x)=−x²/6 for real x. Which number cannot be in the range of f(g(x))?", "choices": [{"key": "A", "text": "−4"}, {"key": "B", "text": "−2"}, {"key": "C", "text": "0"}, {"key": "D", "text": "2"}], "type": "mcq", "correct": "A", "explanation": "The composition is −3−2(−x²/6)=−3+x²/3, with range [−3,∞). Therefore −4 is excluded and every other listed number is attainable.", "topic": "Functions, Transformations & Graphs", "note": "Recovered the negative sign and denominator 6 in g.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 323, "extra_sources": []}, {"id": "clean:PAM 030", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "b7b6bbcf-a1d3-5b7d-a4a1-4073fd57307e", "stem": "Which expression equals \\(\\sqrt[4]3/\\sqrt[8]3\\)?", "choices": [{"key": "A", "text": "\\(\\sqrt3\\)"}, {"key": "B", "text": "\\(\\sqrt[4]3\\)"}, {"key": "C", "text": "\\(\\sqrt[8]3\\)"}, {"key": "D", "text": "9"}], "type": "mcq", "correct": "C", "explanation": "Subtract exponents: 3^(1/4)/3^(1/8)=3^(1/4−1/8)=3^(1/8), the eighth root of 3.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Confirmed root indices 4 and 8.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 324, "extra_sources": []}, {"id": "clean:PAM 031", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "f6495aa7-57e5-56e9-ab0b-9519380538c4", "stem": "The model 10P+2U=2500 relates unit price P to units sold U. How many additional units does the model predict if the price decreases from $50 to $45?", "choices": [{"key": "A", "text": "75"}, {"key": "B", "text": "50"}, {"key": "C", "text": "25"}, {"key": "D", "text": "10"}], "type": "mcq", "correct": "C", "explanation": "Rearrange to U=1250−5P. A $5 price decrease raises U by 5·5=25 units. Directly, the predictions are 1000 and 1025.", "topic": "Statistics, Probability & Data Analysis", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 325, "extra_sources": [], "parts": [{"label": "Q7", "question_id": "5af8f905-d416-5e69-826b-d9c189d29330", "stem": "Which expression equals \\([(2x-y)^2-(2x+y)^2]^2\\)?", "choices": [{"key": "A", "text": "16x⁴−y²"}, {"key": "B", "text": "−64x⁴y⁴"}, {"key": "C", "text": "−8x²y²"}, {"key": "D", "text": "64x²y²"}], "type": "mcq", "correct": "D", "explanation": "The inner difference is (4x²−4xy+y²)−(4x²+4xy+y²)=−8xy. Squaring gives 64x²y².", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered both inner squares and the outer square; separated the two prompts."}]}, {"id": "clean:PAM 033", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "8cdf6453-23ca-5c3a-a88b-6ff3db1a15de", "stem": "For x>0, supply is f(x)=(1+x)/2 and demand is g(x)=2/x+1. What is the equilibrium price x, rounded to two decimal places?", "choices": [{"key": "A", "text": "1.56"}, {"key": "B", "text": "1.79"}, {"key": "C", "text": "2.56"}, {"key": "D", "text": "2.79"}], "type": "mcq", "correct": "C", "explanation": "Set (1+x)/2=2/x+1 and multiply by 2x: x+x²=4+2x. Thus x²−x−4=0, giving x=(1±√17)/2. Only the positive root is a price; it is approximately 2.56155, which rounds to 2.56.", "topic": "Functions, Transformations & Graphs", "note": "Enlarged source confirms denominator 2 in supply. Clarified that the requested number is the positive x-coordinate, not the full intersection point.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 326, "extra_sources": []}]$payload$::jsonb) LOOP
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
