DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:MIX 006", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "948818cc-5cb7-509d-b985-b21f89b29b34", "stem": "If a²+b²=20 and ab=8, what is (b−a)²?", "choices": [], "type": "grid_in", "correct": "4", "explanation": "Expand (b−a)²=a²+b²−2ab=20−16=4.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Removed the preceding clipped question and verified the squared exponent.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 422, "extra_sources": []}, {"id": "clean:MIX 007", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "f4999b61-8fd7-57da-952b-98a3bd205d75", "stem": "The number of eligible voters, in millions, is modeled by V(t)=1.6t+10.8, where t is the number of years since 1990. Approximately how many million voters does it predict for 1999?", "choices": [{"key": "A", "text": "27"}, {"key": "B", "text": "25"}, {"key": "C", "text": "29"}, {"key": "D", "text": "3209"}], "type": "mcq", "correct": "B", "explanation": "For 1999, t=9. The model gives 1.6·9+10.8=25.2 million, which is approximately 25 million.", "topic": "Statistics, Probability & Data Analysis", "note": "Corrected the same elapsed-year indexing typo as PSD 048; removed the unrelated ticket fragment.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 423, "extra_sources": []}, {"id": "clean:MIX 008", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "2db1ae41-4d26-5e43-a52d-91080e334776", "stem": "With \\(i^2=-1\\), which expression equals \\((2-i)/(3+2i)\\)?", "choices": [{"key": "A", "text": "\\(4/13+(7/13)i\\)"}, {"key": "B", "text": "\\(4/13-(7/13)i\\)"}, {"key": "C", "text": "\\(4/5+(7/5)i\\)"}, {"key": "D", "text": "\\(2/5-(7/10)i\\)"}], "type": "mcq", "correct": "B", "explanation": "Multiply by the conjugate 3−2i. The numerator is (2−i)(3−2i)=4−7i and the denominator is 3²+2²=13. Thus the quotient is 4/13−(7/13)i.", "topic": "Complex Numbers", "note": "Recovered both terms of the complex fraction and all four options from page 424.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 424, "extra_sources": []}, {"id": "clean:MIX 011", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "d3e1f13e-a52c-510b-a6f4-33b681b8137c", "stem": "Let g(x)=3x²+kx−8. If g(−2)=−4, what is g(−3)?", "choices": [], "type": "grid_in", "correct": "7", "explanation": "The condition gives 12−2k−8=−4, so k=4. Hence g(−3)=27−12−8=7.", "topic": "Functions, Transformations & Graphs", "note": "Verified the exponent 2 and split the following independent remainder question.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 425, "extra_sources": [], "parts": [{"label": "Q33", "question_id": "a903851a-5afb-520d-bc49-cc68fe1cd736", "stem": "What is the remainder when P(x)=4x³−x²−8x+6 is divided by x−1?", "choices": [], "type": "grid_in", "correct": "1", "explanation": "By the remainder theorem, the remainder is P(1)=4−1−8+6=1.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Split from the original shared crop; original PDF visually checked and solution independently verified."}]}, {"id": "clean:MIX 012", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "7ce5105f-4cd9-533f-9387-dea286e5abfc", "stem": "Nonzero a, b, and c satisfy \\((3a/b)\\div c=7\\). What is \\(bc/(2a)\\)?", "choices": [{"key": "A", "text": "3/14"}, {"key": "B", "text": "7/3"}, {"key": "C", "text": "21"}, {"key": "D", "text": "6/7"}], "type": "mcq", "correct": "A", "explanation": "The relation is 3a/(bc)=7, so bc/a=3/7. Dividing by 2 gives bc/(2a)=3/14.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Visually recovered the division sign and denominators; nonzero variables make every fraction defined.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 426, "extra_sources": []}, {"id": "clean:MIX 013", "old_status": "ocr_screened_not_verified", "status": "duplicate", "note": "Recovered the shared color plot on topic page 44. The observed points coincide at x=2, about 2350 boys; x=0 is 2011, so the year is 2013, C. The fitted curves cross elsewhere and are not the observed counts asked for. Reused the existing full question.", "correct": "C", "duplicate_of": "topic:DAP 067", "question_id": "593e6bab-df95-5e53-8a0f-dc71bdb39871", "before": {"stem": "Questions 24 and 25: A scatterplot shows how many boys there have been in two different villages each year since 2011 (year 2011 is 0). The cubic curve of best fit for village A: y = −0.83x³ + 51.43x² + 0.12x + 2,149.86, where x represents the year and y the number of boys. The line of best fit for village B: y = 194.3x + 2,020.4. — At which date did the two villages have approximately the same number of boys?", "choices": [{"key": "A", "text": "At the end of year 2011"}, {"key": "B", "text": "2012"}, {"key": "C", "text": "2013"}, {"key": "D", "text": "At the beginning of year 2014"}], "correct": "C", "explanation": "Compare the observed dots, not intersections of fitted curves. At x = 2, both villages have about 2,350 boys. Since x = 0 is 2011, x = 2 is 2013."}}]$payload$::jsonb) LOOP
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
