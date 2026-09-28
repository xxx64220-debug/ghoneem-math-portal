DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 111", "old_status": "worked_needs_crop", "status": "ready", "question_id": "68a4152f-c7b1-5497-a16a-573914988d91", "stem": "Which ordered pair satisfies both \\(x+3y\\le8\\) and \\(2x-y>9\\)?", "choices": [{"key": "A", "text": "(0, 3)"}, {"key": "B", "text": "(1, 2)"}, {"key": "C", "text": "(1, −2)"}, {"key": "D", "text": "(1, −9)"}], "type": "mcq", "correct": "D", "explanation": "D gives x + 3y = 1 − 27 = −26 ≤ 8 and 2x − y = 2 + 9 = 11 > 9. A fails the first inequality; B and C fail the second. Therefore D is the unique correct choice.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original compiled PDF page 69 visually checked; complete question retyped separately from unrelated fragments.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 69, "extra_sources": []}, {"id": "clean:HOA 185", "old_status": "worked_needs_crop", "status": "ready", "question_id": "1d8d518e-4fc5-567d-852f-4087c6b51789", "stem": "If \\(6(x+5)=9(-8x+3)\\), what is 39x?", "choices": [{"key": "A", "text": "−0.0023"}, {"key": "B", "text": "−1.5"}, {"key": "C", "text": "−188"}, {"key": "D", "text": "195"}], "type": "mcq", "correct": "B", "explanation": "Expand: 6x + 30 = −72x + 27. Therefore 78x = −3 and 39x = −3/2 = −1.5.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original compiled PDF page 108 visually checked; complete question retyped separately from unrelated fragments.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 108, "extra_sources": []}, {"id": "clean:HOA 186", "old_status": "ocr_screened_not_verified", "status": "defective_choices", "note": "Visually checked page 108. 2(x+8)+3(x−5)=(x−2)(x+7) reduces to x²=15, whose exact solutions are ±sqrt(15). None of the listed choices is exact. −3.9 is only a one-decimal approximation to one root; the source does not request rounding or restrict the sign. Kept unscored pending a corrected source.", "correct": ["sqrt(15)", "-sqrt(15)"]}, {"id": "clean:HOA 076", "old_status": "worked_duplicate_candidate", "status": "duplicate", "note": "Visually checked page 50. t²−119t+3430=(t−49)(t−70), so the larger number is 70 and half is 35, choice B. Same complete question as topic FA 061.", "correct": "B", "duplicate_of": "topic:FA 061"}, {"id": "clean:HOA 083", "old_status": "worked_duplicate_candidate", "status": "duplicate", "note": "Visually checked page 53. The divisor 2x−3 vanishes at 3/2. Twice the remainder is 2[2(3/2)^3+3(3/2)^2−1]=25, choice C. Same complete question as topic AAF 033.", "correct": "C", "duplicate_of": "topic:AAF 033"}, {"id": "clean:HOA 008", "old_status": "worked_shared_stimulus", "status": "ready", "question_id": "47fe3508-69c6-5e35-9091-4ecb03ac0e26", "stem": "For what integer m does the system \\(\\frac25x-\\frac13y=7\\), \\(-\\frac m{10}x+\\frac56y=3\\) have no solution?", "choices": [{"key": "A", "text": "−2"}, {"key": "B", "text": "10"}, {"key": "C", "text": "6"}, {"key": "D", "text": "−10"}], "type": "mcq", "correct": "B", "explanation": "Multiply the first equation by −5/2: \\(-x+5y/6=-35/2\\). Matching the second left side requires m/10 = 1, so m = 10. The equal left sides then require different constants, −35/2 and 3, so the lines are parallel and distinct.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Combined HOA 008 page 7 with its actual system under PSD 014 page 155; both images visually checked.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 7, "extra_sources": []}]$payload$::jsonb) LOOP
  SELECT * INTO s FROM public.est_source_review WHERE id=v->>'id' FOR UPDATE;
  IF s.id IS NULL THEN RAISE EXCEPTION 'Missing source %',v->>'id'; END IF;
  IF EXISTS(SELECT 1 FROM public.audit_log WHERE action='source_review_20260928' AND target_id=s.id) THEN CONTINUE; END IF;
  IF s.review_status<>v->>'old_status' THEN RAISE EXCEPTION 'Source status changed %',s.id; END IF;
  qid=nullif(v->>'question_id','')::uuid;
  IF qid IS NOT NULL AND EXISTS(SELECT 1 FROM public.exams e JOIN public.attempts t ON t.exam_id=e.id
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
  INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES('source_review_20260928','source_review',s.id,
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
  END IF;
  UPDATE public.est_source_review SET review_status=v->>'status',question_id=coalesce(qid,question_id),
   worked_answer=coalesce(v->'correct',worked_answer),duplicate_of=coalesce(v->>'duplicate_of',duplicate_of),
   review_note='Rechecked 2026-09-28. '||coalesce(v->>'note','')||CASE WHEN v ? 'explanation' THEN E'\nWorked solution: '||(v->>'explanation') ELSE '' END,
   updated_at=now() WHERE id=s.id;
 END LOOP;
END;
$review$;
SELECT count(*) applied_source_decisions FROM public.audit_log WHERE action='source_review_20260928';
