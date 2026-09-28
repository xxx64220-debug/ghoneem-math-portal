DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:MIX 047", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "3beae24d-3b6a-5b95-95c8-6f73ec49ce14", "stem": "Let \\(x>0\\), \\(x\\ne1\\), \\(\\log_x6=m\\), and \\(\\log_x3=n\\). If \\(6^a=3\\), which expression equals a?", "choices": [{"key": "A", "text": "mn"}, {"key": "B", "text": "n/m"}, {"key": "C", "text": "m/n"}, {"key": "D", "text": "n−m"}], "type": "mcq", "correct": "B", "explanation": "Take logarithms to base x: a·logₓ6=logₓ3, so am=n and a=n/m. Since 6≠1, m is nonzero for every allowed base.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Restored the common logarithm base and explicitly stated its domain.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 443, "extra_sources": []}, {"id": "clean:MIX 048", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "1e715039-b5fb-5601-902b-a849d4bbae01", "stem": "Majed leaves home at 9:00 and reaches a coffee shop 800 meters away at 9:15. What is his average walking speed in km/h?", "choices": [{"key": "A", "text": "0.8 km/h"}, {"key": "B", "text": "2.4 km/h"}, {"key": "C", "text": "3.2 km/h"}, {"key": "D", "text": "8 km/h"}], "type": "mcq", "correct": "C", "explanation": "The distance is 0.8 km and elapsed time is 15 minutes=0.25 hour. Speed=0.8/0.25=3.2 km/h.", "topic": "Statistics, Probability & Data Analysis", "note": "Recovered the outbound graph endpoints. Explicitly assigned meters to the distance scale in this corrected adaptation; the cropped prose does not retain its unit. Return-trip speed remains missing and is not inferred.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 444, "extra_sources": []}, {"id": "clean:MIX 049", "old_status": "ocr_screened_not_verified", "status": "needs_source_reconstruction", "note": "The shared graph in MIX 048 gives arrival at the shop at 9:15 and a 20-minute stop, hence departure at 9:35. The return-speed clause is clipped, so the arrival time home cannot be determined. The drawn vertical drop is not a physically valid constant-speed return journey; do not infer the answer from the choices.", "correct": null}, {"id": "clean:MIX 051", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "8bb598c7-8531-561a-bdeb-9bbb883576e0", "stem": "Karim’s monthly sales, in thousands of dollars, are 2.5,2,1.5,2,2,3.5. Amir’s are 1.5,2.5,3,2,2.5,2. How much greater are Karim’s best-month sales than Amir’s best-month sales?", "choices": [{"key": "A", "text": "$500"}, {"key": "B", "text": "$1000"}, {"key": "C", "text": "$1500"}, {"key": "D", "text": "$5000"}], "type": "mcq", "correct": "A", "explanation": "Karim’s maximum is $3500 and Amir’s maximum is $3000. The difference is $3500−$3000=$500.", "topic": "Statistics, Probability & Data Analysis", "note": "The original reverses the comparison: Amir’s best month is $500 lower, not greater. Corrected the order and transcribed both series using the graph legend; agrees with PSD 199’s verified series.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 446, "extra_sources": []}, {"id": "clean:MIX 052", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "c897ade2-5e6f-57a2-88e4-82a16500ab3d", "stem": "For real \\(x\\ne y\\), simplify \\(E=[\\sqrt[3]{8x^6}-2\\sqrt{y^4}]/\\sqrt[3]{(x-y)^3}\\).", "choices": [{"key": "A", "text": "2x−2y"}, {"key": "B", "text": "−2x−2y"}, {"key": "C", "text": "−2"}, {"key": "D", "text": "2x+2y"}], "type": "mcq", "correct": "D", "explanation": "For real variables, ∛(8x⁶)=2x², √(y⁴)=|y²|=y², and ∛((x−y)³)=x−y. Thus E=2(x²−y²)/(x−y)=2(x+y), using x≠y.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Verified cube-root versus square-root indices and included the original denominator restriction.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 447, "extra_sources": []}, {"id": "clean:MIX 053", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "e8b9e0e8-052f-52df-8a2a-5c7aa12ebad2", "stem": "Which expression equals \\(x^2/4+x+2\\)?", "choices": [{"key": "A", "text": "\\(2+(x/2+1)^2\\)"}, {"key": "B", "text": "\\(-3+(x/2+2)^2\\)"}, {"key": "C", "text": "\\(1+(x/2+1)^2\\)"}, {"key": "D", "text": "\\(1/4+(x+1/2)^2\\)"}], "type": "mcq", "correct": "C", "explanation": "Expand 1+(x/2+1)²=1+x²/4+x+1=x²/4+x+2. The other options have different coefficients or constants.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered the coefficient 1/4 and all four completed-square forms.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 447, "extra_sources": []}]$payload$::jsonb) LOOP
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
