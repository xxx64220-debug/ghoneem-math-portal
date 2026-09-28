DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:GTC 076", "old_status": "worked_needs_crop", "status": "ready", "question_id": "5984b17b-c5c8-57cb-a175-d93ee9434270", "stem": "Each side of a square with perimeter 20 is increased by 2%. Which statement gives the exact resulting change?", "choices": [{"key": "A", "text": "Area increases by 4%"}, {"key": "B", "text": "Area increases by 2%"}, {"key": "C", "text": "Perimeter increases by 2%"}, {"key": "D", "text": "Perimeter increases by 4%"}], "type": "mcq", "correct": "C", "explanation": "The original side length is 20/4 = 5; the new side length is 5 × 1.02 = 5.1, so the perimeter is 20.4, exactly 2% greater. The area factor is 1.02² = 1.0404, an increase of 4.04%, not exactly 4%.", "topic": "Plane Geometry, Measurement & Transformations", "note": "Source page 417 visually checked; isolated complete question and verified all options.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 417, "extra_sources": []}, {"id": "clean:MIX 024", "old_status": "worked", "status": "ready", "question_id": "e4167d99-19d1-59af-b140-ec2d88fff6b5", "stem": "Which listed number satisfies 2x + 3 > 8?", "choices": [{"key": "A", "text": "1"}, {"key": "B", "text": "1.5"}, {"key": "C", "text": "2.5"}, {"key": "D", "text": "3.5"}], "type": "mcq", "correct": "D", "explanation": "Subtract 3 and divide by 2: x > 2.5. Only 3.5 satisfies this strict inequality. The endpoint 2.5 does not.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Page 432 visually checked. Completed the clipped prompt as “satisfies 2x + 3 > 8”; no missing numerical information was inferred.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 432, "extra_sources": []}, {"id": "clean:MIX 028", "old_status": "worked_needs_crop", "status": "ready", "question_id": "1c2db7a6-c234-5701-a93d-5980dcef27c2", "stem": "If 30 is 26% of t, what is t, rounded to the nearest hundredth?", "choices": [{"key": "A", "text": "100.7"}, {"key": "B", "text": "90.7"}, {"key": "C", "text": "45.9"}, {"key": "D", "text": "115.38"}], "type": "mcq", "correct": "D", "explanation": "The equation is 0.26t = 30, giving t = 30/0.26 = 1500/13 ≈ 115.384615. Rounded to the nearest hundredth, this is 115.38.", "topic": "Statistics, Probability & Data Analysis", "note": "Page 433 visually checked. Explicit rounding added to match the printed numerical choices.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 433, "extra_sources": []}, {"id": "clean:PSD 094", "old_status": "worked_duplicate_candidate", "status": "duplicate", "note": "Visually checked page 220. There are 9 red-or-yellow balls out of 20; the squared probability is (9/20)² = 81/400 = 0.2025, A. Same question as DAP 051.", "correct": "A", "duplicate_of": "topic:DAP 051"}, {"id": "clean:PSD 005", "old_status": "worked_missing_choice", "status": "worked_missing_choice", "note": "Visually checked page 149. 1/(x−y)=3/(5y) gives 5y=3x−3y, hence x/y=8/3, B. The denominator of choice D remains cut off in the supplied compiled PDF. Keep held until complete original choices are recovered.", "correct": "B"}, {"id": "clean:PSD 037", "old_status": "worked_missing_choice", "status": "worked_missing_choice", "note": "Visually checked page 174. The multiplier is 0.80×0.74×1.30=0.7696, a 23.04% decrease, B. Choice D is cut off in the supplied PDF; no complete alternative is invented.", "correct": "B"}]$payload$::jsonb) LOOP
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
