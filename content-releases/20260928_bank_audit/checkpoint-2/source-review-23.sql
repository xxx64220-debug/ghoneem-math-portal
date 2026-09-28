DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:PSD 125", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "d95b7991-e6ca-5e32-b47d-178ef4d2b299", "stem": "A line of best fit for the number of phones sold versus elapsed months passes through (0,105) and (7,112.7). What average increase per month does the line predict?", "choices": [{"key": "A", "text": "0.8"}, {"key": "B", "text": "0.9"}, {"key": "C", "text": "1"}, {"key": "D", "text": "1.1"}], "type": "mcq", "correct": "D", "explanation": "The line’s slope is (112.7−105)/(7−0)=7.7/7=1.1 phones per month.", "topic": "Statistics, Probability & Data Analysis", "note": "Restored the defining points stated in the shared stimulus under PSD 124 page 242.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 243, "extra_sources": []}, {"id": "clean:PSD 171", "old_status": "defective_choices", "status": "ready", "question_id": "8d5150b6-5ae5-5bfc-9840-1d56a0d7467f", "stem": "Three cards are selected uniformly without replacement from cards numbered 1 through 30. What is the probability that all three numbers are prime, rounded to four decimal places?", "choices": [{"key": "A", "text": "0.0220"}, {"key": "B", "text": "0.0296"}, {"key": "C", "text": "0.4560"}, {"key": "D", "text": "0.5850"}], "type": "mcq", "correct": "B", "explanation": "The ten primes are 2,3,5,7,11,13,17,19,23,29. Thus the probability is (10/30)(9/29)(8/28)=6/203≈0.02955665, which rounds to 0.0296. The number 1 is not prime.", "topic": "Statistics, Probability & Data Analysis", "note": "Corrected the source’s decimal-place error in B (0.296 to 0.0296) and specified rounding.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 271, "extra_sources": []}, {"id": "clean:PSD 173", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "f45d092c-c386-53e9-ac7a-9d0560de1d97", "stem": "Ali has 68 eggs, at most 13 small boxes holding 4 eggs each, and at most 10 large boxes holding 6 eggs each. A full small box sells for $8 and a full large box for 45% more. If every egg is sold in full boxes, which choice gives the greatest revenue?", "choices": [{"key": "A", "text": "5 small and 8 large"}, {"key": "B", "text": "8 small and 6 large"}, {"key": "C", "text": "11 small and 4 large"}, {"key": "D", "text": "14 small and 2 large"}], "type": "mcq", "correct": "C", "explanation": "A large box sells for 8(1.45)=$11.60. The first three choices each hold 68 eggs; their revenues are $132.80, $133.60, and $134.40. The fourth would need 14 small boxes, exceeding the available 13. More generally 4s+6b=68 and the box limits imply s=2,5,8,11; revenue grows with s, so 11 small and 4 large is the maximum.", "topic": "Statistics, Probability & Data Analysis", "note": "Clarified revenue rather than profit, because the source gives sale prices but no costs; checked both egg capacity and available box constraints.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 271, "extra_sources": []}, {"id": "clean:PSD 199", "old_status": "defective_choices", "status": "ready", "question_id": "622583f2-079e-5528-9e9c-dac082ec4b59", "stem": "Karim’s sales were $2,000 in month 5 and $3,500 in month 6. What was the percent change?", "choices": [{"key": "A", "text": "Increase by 75%"}, {"key": "B", "text": "Increase by 25%"}, {"key": "C", "text": "Decrease by 20%"}, {"key": "D", "text": "Decrease by 25%"}], "type": "mcq", "correct": "A", "explanation": "The increase is 3500−2000=1500. Relative to the original 2000, the increase is 1500/2000=0.75=75%. The source’s 20% decrease belongs to Amir’s black line, not Karim’s gray line.", "topic": "Statistics, Probability & Data Analysis", "note": "Confirmed legend and both series on page 290. Transcribed Karim’s values and corrected A to 75%; original choices had no correct answer.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 290, "extra_sources": []}, {"id": "clean:PSD 202", "old_status": "ambiguous_distribution", "status": "ready", "question_id": "5029740c-b122-5181-8a99-f2d3be7d6301", "stem": "A company has 6 departments, each with 10 to 14 bureaus. Each bureau has 30 to 50 workers, and exactly 20% of the workers in each department are web developers. What is the minimum number of web developers in one department?", "choices": [{"key": "A", "text": "36"}, {"key": "B", "text": "60"}, {"key": "C", "text": "360"}, {"key": "D", "text": "1800"}], "type": "mcq", "correct": "B", "explanation": "A department has at least 10 bureaus with at least 30 workers each, so at least 300 workers. At 20% developers per department, the minimum is 0.20×300=60. This is attained with 10 bureaus of 30 workers.", "topic": "Statistics, Probability & Data Analysis", "note": "Added the missing per-department percentage condition. A company-wide 20% alone would permit zero developers in a particular department.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 293, "extra_sources": []}, {"id": "clean:HOA 038", "old_status": "needs_source_reconstruction", "status": "ready", "question_id": "77e7e990-00f8-5ce0-9f15-e3ddb6979b64", "stem": "Line f passes through (−1,1) and (0,2). Line g is perpendicular to f and passes through (2,2) and (−2,m). What is m?", "choices": [{"key": "A", "text": "6"}, {"key": "B", "text": "−2"}, {"key": "C", "text": "2"}, {"key": "D", "text": "8"}], "type": "mcq", "correct": "A", "explanation": "The slope of f is (2−1)/(0+1)=1, so the slope of g is −1. Therefore (m−2)/(−2−2)=−1, giving m−2=4 and m=6.", "topic": "Coordinate Geometry & Circles", "note": "Recovered the exact missing shared graph in MIX 004, page 421, and read all four labeled coordinates at enlarged resolution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 28, "extra_sources": [], "audit_action": "source_review_20260928_revision2"}]$payload$::jsonb) LOOP
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
