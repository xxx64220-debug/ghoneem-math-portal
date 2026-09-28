DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 187", "old_status": "ocr_screened_not_verified", "status": "needs_source_reconstruction", "note": "The function is y=2x−3/(1−x), with y-intercept −3, so visible statement I (intercept −5) is false. The remaining statements and answer combinations are absent. A full original is needed.", "correct": null}, {"id": "clean:HOA 188", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "f742708a-c5d0-5382-8d64-f5e223b15524", "stem": "A quadratic passes through (1,−5) and (4,1) and has axis of symmetry x=2. Which expression defines it?", "choices": [{"key": "A", "text": "2x²−8x−1"}, {"key": "B", "text": "2x²−8x+1"}, {"key": "C", "text": "x²−x+1"}, {"key": "D", "text": "−2x²−4x+1"}], "type": "mcq", "correct": "B", "explanation": "Use f(x)=a(x−2)²+k. The points give a+k=−5 and 4a+k=1. Subtraction gives a=2 and k=−7. Thus f(x)=2(x−2)²−7=2x²−8x+1.", "topic": "Functions, Transformations & Graphs", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 109, "extra_sources": [], "parts": [{"label": "Q32", "question_id": "8d3714ba-1e83-549f-8df3-47710bc22970", "stem": "A line through (1,3) and (x,−8) has slope 6. What is x?", "choices": [{"key": "A", "text": "−3/5"}, {"key": "B", "text": "5/6"}, {"key": "C", "text": "−5/6"}, {"key": "D", "text": "3/5"}], "type": "mcq", "correct": "C", "explanation": "The slope equation is (−8−3)/(x−1)=6. Thus −11=6x−6 and x=−5/6.", "topic": "Coordinate Geometry & Circles", "note": "Split from the original shared crop; original PDF visually checked and solution independently verified."}]}, {"id": "clean:HOA 189", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "e56d47bc-d1e0-511d-904c-882d0c5e14e2", "stem": "Given a/b=−c/(a+b), with b≠0, a+b≠0, and a+c≠0, which formula gives b?", "choices": [{"key": "A", "text": "−a²/(a+c)"}, {"key": "B", "text": "a²/(−a+c)"}, {"key": "C", "text": "a²/(a−c)"}, {"key": "D", "text": "a²/(a+c)"}], "type": "mcq", "correct": "A", "explanation": "Cross-multiply to obtain a(a+b)=−bc. Thus a²=−b(a+c), so b=−a²/(a+c). The stated nonzero denominators permit each step.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 109, "extra_sources": []}, {"id": "clean:HOA 191", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "d30b25d5-c436-5e7a-a426-9d512580bbcd", "stem": "If 3y+x=−7 and 2x−3y=14, what is x?", "choices": [{"key": "A", "text": "−7/3"}, {"key": "B", "text": "7/3"}, {"key": "C", "text": "28/9"}, {"key": "D", "text": "−28/9"}], "type": "mcq", "correct": "B", "explanation": "Adding eliminates y and gives 3x=7, so x=7/3.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 111, "extra_sources": [], "parts": [{"label": "Q2", "question_id": "0e9e09c9-1cef-5e08-ac16-ff1d0dc09f41", "stem": "What is the least real x satisfying −3≤x/3+2<12?", "choices": [{"key": "A", "text": "15"}, {"key": "B", "text": "−15"}, {"key": "C", "text": "30"}, {"key": "D", "text": "−30"}], "type": "mcq", "correct": "B", "explanation": "Subtract 2: −5≤x/3<10. Multiply by 3: −15≤x<30. The lower endpoint is included, so the least value is −15.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Split from the original shared crop; original PDF visually checked and solution independently verified."}, {"label": "Q3", "question_id": "959a2dca-9c78-5809-8256-4a24cd9b085f", "stem": "For all x, (x+a)(x+b)=x²+18x+77, and a>b. What is a?", "choices": [], "type": "grid_in", "correct": "11", "explanation": "The constants satisfy a+b=18 and ab=77. Since 77=7·11 and 7+11=18, they are 7 and 11. The larger a is 11.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Converted to numeric response because the final choices are missing."}]}, {"id": "clean:HOA 192", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "2302b0d6-e0df-5e89-854e-debbda97b9d9", "stem": "If r<0 and 2r²−25=0, what is r rounded to the nearest tenth?", "choices": [{"key": "A", "text": "−1.5"}, {"key": "B", "text": "−0.5"}, {"key": "C", "text": "−2.5"}, {"key": "D", "text": "−3.5"}], "type": "mcq", "correct": "D", "explanation": "The equation gives r²=25/2. The negative root is r=−5/√2≈−3.5355, which rounds to −3.5.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Added the rounding instruction required by the original decimal choices. The separate graph and exponential questions are repeats already verified under MIX 055 and its Q8 part.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 112, "extra_sources": []}, {"id": "clean:HOA 194", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "4a3a1ef2-b745-526c-b956-abfce65184db", "stem": "What is the real solution of √(x+2)=2?", "choices": [{"key": "A", "text": "2"}, {"key": "B", "text": "4"}, {"key": "C", "text": "0"}, {"key": "D", "text": "No solution"}], "type": "mcq", "correct": "A", "explanation": "Squaring gives x+2=4, so x=2. It is in the domain and checks: √(2+2)=2.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 113, "extra_sources": []}]$payload$::jsonb) LOOP
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
