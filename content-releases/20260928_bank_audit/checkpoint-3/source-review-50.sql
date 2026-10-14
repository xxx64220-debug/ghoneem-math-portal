DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 193", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "4375bd52-b016-5937-b993-d7cc3ef69d25", "stem": "Let f(x)=2x+5 and g(x)=2a+5x+1. If g(−2)=f(−6), what is a?", "choices": [{"key": "A", "text": "1"}, {"key": "B", "text": "−7"}, {"key": "C", "text": "5"}, {"key": "D", "text": "12"}], "type": "mcq", "correct": "A", "explanation": "Compute f(−6)=−12+5=−7 and g(−2)=2a−10+1=2a−9. Thus 2a−9=−7, giving a=1.", "topic": "Functions, Transformations & Graphs", "note": "Exact duplicate copies visually checked on pages 113 and 358; retained one canonical question.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 113, "extra_sources": []}, {"id": "clean:PAM 081", "old_status": "ocr_screened_not_verified", "status": "duplicate", "note": "Exact repeat of HOA 193. Both original function definitions agree, and 2a−9=−7 gives a=1.", "correct": "A", "question_id": "4375bd52-b016-5937-b993-d7cc3ef69d25", "duplicate_of": "clean:HOA 193"}, {"id": "clean:PAM 082", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "cb353634-d70f-50fb-9bde-cbf8f1538785", "stem": "For \\(f(x)=(x-2)/(x-5)\\), the asymptotes are x=a and y=b. What is a−b?", "choices": [{"key": "A", "text": "1"}, {"key": "B", "text": "4"}, {"key": "C", "text": "5"}, {"key": "D", "text": "6"}], "type": "mcq", "correct": "B", "explanation": "The denominator vanishes at x=5 and the numerator does not, so a=5. Equal numerator/denominator degrees give horizontal asymptote y=1, so b=1. Hence a−b=4.", "topic": "Functions, Transformations & Graphs", "note": "Repaired “difference between asymptotes” by explicitly asking for the difference of their coordinate constants.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 358, "extra_sources": []}, {"id": "clean:PAM 083", "old_status": "ocr_screened_not_verified", "status": "worked_missing_choice", "note": "The full function is y=(2x−1)/x=2−1/x. Its inverse is 1/(2−x), with domain x≠2. Only original choices A/B survive, and the sign preceding A is unclear; C/D are absent. The formula is verified, but the original answer letter cannot be verified.", "correct": "1/(2−x)"}, {"id": "clean:PAM 084", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "22591c04-f42a-516d-9971-059ad5417cbd", "stem": "The chart records 4,000 cars sold in 2016. A car cost $1,450 in 2012, and its 2016 price was 15% higher. What was the total revenue for 2016?", "choices": [{"key": "A", "text": "$4600"}, {"key": "B", "text": "$6670"}, {"key": "C", "text": "$4015"}, {"key": "D", "text": "$6670000"}], "type": "mcq", "correct": "D", "explanation": "The 2016 price was 1450·1.15=$1667.50. Revenue for 4000 cars is 4000·1667.5=$6,670,000.", "topic": "Statistics, Probability & Data Analysis", "note": "Read year 6 as 2016 and the chart’s thousands-of-cars scale; transcribed the required value.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 359, "extra_sources": [], "parts": [{"label": "Q15", "question_id": "37ea788a-19f5-521d-8687-b91357ceaaec", "stem": "Three kilograms of apples and 7 kilograms of oranges cost $6.25. Two kilograms of apples and 5 kilograms of oranges cost $4.25. What is the price of 1 kilogram of apples?", "choices": [{"key": "A", "text": "$1.50"}, {"key": "B", "text": "$0.25"}, {"key": "C", "text": "$1.76"}, {"key": "D", "text": "$0.21"}], "type": "mcq", "correct": "A", "explanation": "Let a,o be prices per kilogram. Subtract twice 3a+7o=6.25 from three times 2a+5o=4.25: o=0.25. Then 3a+1.75=6.25, giving a=1.50.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Split from the original shared crop; original PDF visually checked and solution independently verified."}]}, {"id": "clean:PAM 085", "old_status": "ocr_screened_not_verified", "status": "duplicate", "note": "Fuller repeated crop matches all four PAM 073 questions. Reused the primary and three separate parts. The table starts with x=−2, so a+b=−3; the other answers are height55.3, exponent expression−20, and 4ˣ.", "correct": ["B", "D", "C", "A"], "question_id": "c0b55ceb-00a1-58a4-9344-10f01e1e3d69", "duplicate_of": "clean:PAM 073"}]$payload$::jsonb) LOOP
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
