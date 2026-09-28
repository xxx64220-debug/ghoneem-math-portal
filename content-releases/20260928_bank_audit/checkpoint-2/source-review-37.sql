DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 121", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "029fd4eb-69c9-5852-afe7-6c0a856a34c4", "stem": "A river is 34 feet deep and its water level falls by 0.5 foot each day. Which choice gives the level w after d days and the time at which it reaches 26 feet?", "choices": [{"key": "A", "text": "w=34d+0.5; 16 days"}, {"key": "B", "text": "w=−0.5d−34; 120 days"}, {"key": "C", "text": "w=34d−0.5; 120 days"}, {"key": "D", "text": "w=−0.5d+34; 16 days"}], "type": "mcq", "correct": "D", "explanation": "The initial level is the intercept 34, and the daily change is the slope −0.5, so w=34−0.5d. Set 26=34−0.5d to obtain d=16 days. The negative slope represents a fall of 0.5 foot per day.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Joined Q19 on page 75 to its final choice explanation in MIX 021 on page 430; removed the preceding option D=32 belonging to MIX 020.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 75, "extra_sources": []}, {"id": "clean:MIX 021", "old_status": "ocr_screened_not_verified", "status": "duplicate", "note": "This fragment is the continuation of HOA 121 choice D, not a separate question. Reunited the complete solution: w=34−0.5d; at w=26, d=16.", "correct": "D", "question_id": "029fd4eb-69c9-5852-afe7-6c0a856a34c4", "duplicate_of": "clean:HOA 121"}, {"id": "clean:MIX 022", "old_status": "ocr_screened_not_verified", "status": "needs_source_reconstruction", "note": "The seven bar values are visible (32,35,37,37,42,44,47 hours), but the right half of the question is clipped, including the relation between week-7 and week-3 pay and two choices. The $140 amount alone does not determine the requested earlier hourly rate.", "correct": null}, {"id": "clean:MIX 027", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "21d048d9-abc1-556e-a6e2-3fff796482cc", "stem": "Simplify (−7p⁵q+6pq)+(4p⁵q−8pq+3)+(7pq+7).", "choices": [{"key": "A", "text": "−11p⁵q+13pq+10"}, {"key": "B", "text": "−3p⁵q+21pq+10"}, {"key": "C", "text": "−3p⁵q+5pq+10"}, {"key": "D", "text": "−4p⁵q+5pq+9"}], "type": "mcq", "correct": "C", "explanation": "The p⁵q terms total (−7+4)p⁵q=−3p⁵q. The pq terms total (6−8+7)pq=5pq, and constants total 10.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Verified exponent 5 and each coefficient from the image; removed the preceding unrelated choice.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 433, "extra_sources": []}, {"id": "clean:MIX 029", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "e6cbc0ae-7246-52b0-a7e7-09bbe463ba52", "stem": "A linear function has f(−1)=2, f(−3)=7, and f(−5)=a. What is a?", "choices": [{"key": "A", "text": "12"}, {"key": "B", "text": "−2"}, {"key": "C", "text": "6"}, {"key": "D", "text": "−4"}], "type": "mcq", "correct": "A", "explanation": "Each decrease of 2 in x raises f by 5. Moving from −3 to −5 therefore raises 7 to 12. Equivalently the slope is −5/2.", "topic": "Functions, Transformations & Graphs", "note": "Recovered the full table, which was absent from OCR. The preceding 39-correct question lacks its percentage and remains excluded.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 434, "extra_sources": [], "parts": [{"label": "Q28", "question_id": "3541d46f-545d-5a70-903b-bb85fc125d92", "stem": "What value of x satisfies 0.2(3x−8)=10.4?", "choices": [], "type": "grid_in", "correct": "20", "explanation": "Divide by 0.2 to obtain 3x−8=52. Then 3x=60, so x=20. Check: 0.2(60−8)=10.4.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Converted this complete equation to numeric response because the fourth original choice is clipped."}]}, {"id": "clean:MIX 030", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "82d09e05-241a-5e7b-a97a-7f0bc535095a", "stem": "When P(x)=−2x³+2x²−5x−1 is divided by x−a, the remainder is 86. What is the real value of a?", "choices": [], "type": "grid_in", "correct": "-3", "explanation": "The remainder theorem requires P(a)=86. Substitution gives P(−3)=54+18+15−1=86. Uniqueness follows because P(a)−86=−(a+3)(2a²−8a+29), and the quadratic has discriminant 64−232<0. Thus a=−3.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Verified cubic and square powers. Converted the incomplete multiple-choice divisor question to numeric a; the divisor is x+3. The leading square-completion options were reunited with GTC 049.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 435, "extra_sources": []}]$payload$::jsonb) LOOP
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
