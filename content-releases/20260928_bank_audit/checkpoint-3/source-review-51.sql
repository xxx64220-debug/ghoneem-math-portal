DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:PAM 086", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "15efe217-228d-5c8d-bb88-3956091c5345", "stem": "For F(x)=−x²+6x+1, which statements are true? I. The axis of symmetry is x=−3. II. The maximum y-value is 28.", "choices": [{"key": "A", "text": "I only"}, {"key": "B", "text": "II only"}, {"key": "C", "text": "I and II"}, {"key": "D", "text": "Both statements are false."}], "type": "mcq", "correct": "D", "explanation": "Complete the square: F(x)=−(x−3)²+10. The axis is x=3 and the maximum is 10. Both statements are false.", "topic": "Functions, Transformations & Graphs", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 361, "extra_sources": []}, {"id": "clean:PAM 088", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "62206ebc-2c4c-5243-98f8-92dd3c2be3c4", "stem": "Simplify (3xy)(4y)²(−2x²y).", "choices": [{"key": "A", "text": "−96x²y²"}, {"key": "B", "text": "−32x³y⁴"}, {"key": "C", "text": "−96x³y⁴"}, {"key": "D", "text": "−32x⁴y³"}], "type": "mcq", "correct": "C", "explanation": "The numerical coefficient is 3·16·(−2)=−96. The x power is 1+2=3 and the y power is 1+2+1=4. Thus the product is −96x³y⁴.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered the square on 4y and square on x in the last factor; removed the redundant outer power 1.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 362, "extra_sources": []}, {"id": "clean:PAM 090", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "81cc7bcf-ff3c-5650-bf5f-f3199e3e1fcd", "stem": "What is the real domain of \\(f(x)=1/\\sqrt{x-7}\\)?", "choices": [{"key": "A", "text": "x≥7"}, {"key": "B", "text": "x>7"}, {"key": "C", "text": "All real numbers"}, {"key": "D", "text": "All real numbers except 7"}], "type": "mcq", "correct": "B", "explanation": "The square root requires x−7≥0, and the denominator cannot be zero. Together these require x−7>0, or x>7.", "topic": "Functions, Transformations & Graphs", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 363, "extra_sources": []}, {"id": "clean:PAM 094", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "ee3201b7-057a-5666-8d14-eac1f2f60e22", "stem": "Which of the following equations represents a parabola with vertex (4,1)?", "choices": [{"key": "A", "text": "y=x²−8x+17"}, {"key": "B", "text": "y=x²−18x−15"}, {"key": "C", "text": "y=x²+18x+17"}, {"key": "D", "text": "y=x²−18x+15"}], "type": "mcq", "correct": "A", "explanation": "Choice A is y=(x−4)²+1, whose vertex is (4,1). The other choices have axes x=9 or x=−9 and cannot have that vertex.", "topic": "Functions, Transformations & Graphs", "note": "The source really prints 18x in every option, so none is correct. Corrected A’s coefficient from −18 to −8; this is a documented source erratum, not an OCR correction.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 365, "extra_sources": []}, {"id": "clean:HOA 079", "old_status": "ocr_screened_not_verified", "status": "worked_missing_choice", "note": "Original table recovered: x=−7,−4,−2,1,7 and y=−11,−5,−1,5,17. All points satisfy y=2x+3, so visible A is correct. Final choice D remains clipped; retain until the full original option is recovered.", "correct": "A"}, {"id": "clean:HOA 084", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "0e971003-2039-5b97-91b1-81449fcb0baf", "stem": "Let i²=−1 and let a be complex. If (a+2i)/(3−i)=2−5i, what is a²?", "choices": [{"key": "A", "text": "2(19i+180)"}, {"key": "B", "text": "19i+180"}, {"key": "C", "text": "−19i−180"}, {"key": "D", "text": "−2(19i+180)"}], "type": "mcq", "correct": "D", "explanation": "Multiply by 3−i: a+2i=(2−5i)(3−i)=1−17i, so a=1−19i. Squaring gives a²=1−38i−361=−360−38i=−2(19i+180).", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Restored the complex quotient; a cannot be restricted to real numbers.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 54, "extra_sources": []}]$payload$::jsonb) LOOP
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
