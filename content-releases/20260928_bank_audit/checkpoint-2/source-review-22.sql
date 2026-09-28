DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:PSD 048", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "a31056cb-9d44-5b2b-9cf0-dbea17214344", "stem": "The number of eligible voters, in millions, is modeled by V(t)=1.6t+10.8, where t is years since 1990. If the model continues, what is the difference between the predictions for 2020 and 2017?", "choices": [{"key": "A", "text": "5.2"}, {"key": "B", "text": "4.8"}, {"key": "C", "text": "6.4"}, {"key": "D", "text": "2.4"}], "type": "mcq", "correct": "B", "explanation": "The dates differ by 3 years and the linear model increases by 1.6 million per year. The predicted difference is 1.6×3=4.8 million. Equivalently V(30)−V(27)=4.8.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Isolated Q8 and repaired the typographical definition “y=1 represents the number of years” to a clear elapsed-time variable. The rate and intercept are unchanged.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 184, "extra_sources": []}, {"id": "clean:PSD 099", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "a1bbe169-747e-50a5-9868-2636edce7222", "stem": "A model records 91,072 cases on July 24 and 94,640 on August 3 of the same year, with 31 days in July. Assuming a linear daily increase, how many cases does it predict for August 9, rounded to the nearest whole case?", "choices": [{"key": "A", "text": "96,781"}, {"key": "B", "text": "97,138"}, {"key": "C", "text": "98,208"}, {"key": "D", "text": "101,776"}], "type": "mcq", "correct": "A", "explanation": "July 24 to August 3 is 10 days. The daily increase is (94640−91072)/10=356.8. August 9 is 6 more days, giving 94640+6(356.8)=96780.8, which rounds to 96,781.", "topic": "Statistics, Probability & Data Analysis", "note": "Verified date intervals and rounding from the source; presented as the supplied mathematical model, without making a current public-health claim.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 225, "extra_sources": []}, {"id": "clean:PSD 104", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "9c0c633d-9cf4-5433-924c-15cff76f472a", "stem": "Three squash and two zucchini cost 10 EGP. Five squash and three zucchini cost 16.5 EGP. What is the cost of one squash and four zucchini?", "choices": [{"key": "A", "text": "7 EGP"}, {"key": "B", "text": "5 EGP"}, {"key": "C", "text": "10 EGP"}, {"key": "D", "text": "8.5 EGP"}], "type": "mcq", "correct": "B", "explanation": "Let s and z be the prices. From 3s+2z=10 and 5s+3z=16.5, subtract 3 times the first equation from 2 times the second: s=3. Then 9+2z=10 gives z=0.5. The required cost is s+4z=3+2=5 EGP.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Isolated Q3. The following news-survey chart was restored to PSD 105/106.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 228, "extra_sources": []}, {"id": "clean:PSD 105", "old_status": "missing_stimulus", "status": "ready", "question_id": "23c83f0a-e90c-5e19-8361-46976ec2dbac", "stem": "In a survey of the one news source parents trust most, 14 chose TV, 21 websites, 17 social media, and 6 radio. Approximately what percentage chose social media?", "choices": [{"key": "A", "text": "17%"}, {"key": "B", "text": "25.7%"}, {"key": "C", "text": "29.3%"}, {"key": "D", "text": "34%"}], "type": "mcq", "correct": "C", "explanation": "The total is 14+21+17+6=58 parents. The social-media share is 100×17/58≈29.3103%, which rounds to 29.3%.", "topic": "Statistics, Probability & Data Analysis", "note": "Recovered the shared chart from PSD 104 page 228 and transcribed its labeled counts.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 229, "extra_sources": []}, {"id": "clean:PSD 106", "old_status": "missing_stimulus", "status": "ready", "question_id": "63abf139-4bf6-5b76-a9b8-1268df388700", "stem": "A survey found that 14 parents trust TV most, 21 websites, 17 social media, and 6 radio. If a survey of 120 people has the same proportions, approximately how many would choose TV or radio?", "choices": [{"key": "A", "text": "29"}, {"key": "B", "text": "41"}, {"key": "C", "text": "53"}, {"key": "D", "text": "58"}], "type": "mcq", "correct": "B", "explanation": "TV and radio together account for 14+6=20 out of 58 responses. In a sample of 120, the expected number is 120×20/58≈41.379, or about 41 people.", "topic": "Statistics, Probability & Data Analysis", "note": "Recovered shared source counts from PSD 104 page 228; used the full 58-response denominator.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 229, "extra_sources": []}, {"id": "clean:PSD 124", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "9ad7281b-74b7-5753-814d-34a39ad340f8", "stem": "What value of x satisfies \\(2=\\sqrt{2x-3}\\)?", "choices": [{"key": "A", "text": "2.5"}, {"key": "B", "text": "3.5"}, {"key": "C", "text": "4.5"}, {"key": "D", "text": "0.5"}], "type": "mcq", "correct": "B", "explanation": "Square both nonnegative sides: 4=2x−3, so x=7/2=3.5. Check: √(2·3.5−3)=√4=2.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 242, "extra_sources": []}]$payload$::jsonb) LOOP
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
