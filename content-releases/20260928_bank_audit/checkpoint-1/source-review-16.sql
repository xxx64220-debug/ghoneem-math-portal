DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "est2-papers-2026-09-26:sample4:q49", "old_status": "needs_source_repair", "status": "ready", "question_id": "b277c856-c263-5cf9-b85b-58118b05a14c", "stem": "In quadrilateral ABCD, AB is parallel to CD and angle DAB=70°. Diagonals AC and BD intersect at E. Triangle AEB is isosceles with AE=BE and angle AEB=66°. What is angle BCE?", "choices": [{"key": "A", "text": "13°"}, {"key": "B", "text": "22°"}, {"key": "C", "text": "30°"}, {"key": "D", "text": "53°"}, {"key": "E", "text": "66°"}], "type": "mcq", "correct": "D", "explanation": "In triangle AEB, the base angles EAB and EBA are (180°−66°)/2=57°. Because AB∥CD, triangles AEB and CED are similar, so CE=DE. Triangles AED and BEC are then congruent by SAS: AE=BE, ED=EC, and the included angles at E are vertical angles. Thus AD=BC and the trapezoid is isosceles, so angle ABC=70°. Therefore angle EBC=70°−57°=13°. Angle BEC=180°−66°=114°, so angle BCE=180°−114°−13°=53°.", "topic": "Triangles, Trigonometry & Similarity", "note": "Original source image decrypted, hash checked, and visually inspected. Corrected a false hold: the original given angle DAB=70°, parallel bases, and AE=BE do determine the answer. No numerical assumption or choice was changed.", "source_document": "EST 2 Math Level 1 - Test Sample 4.pdf", "source_page": 13}, {"id": "est2-papers-2026-09-26:l1june:q05", "old_status": "needs_source_repair", "status": "needs_source_reconstruction", "note": "Original source image visually checked again. Original diagram has no numerical side length. From tanβ=2/3, the sides are 2k, 3k, k√13 for any k>0. Both √13 and 2√13 are possible hypotenuse lengths. A source side length is required; no unique answer can be verified.", "correct": null}, {"id": "est2-papers-2026-09-26:l1oct:q45", "old_status": "needs_source_repair", "status": "needs_source_reconstruction", "note": "Original source image visually checked again. For a real angle θ, cos(π/2−θ)=sinθ cannot equal 2/√3>1. There is no real solution. The formal value 4/3 is not a valid answer to the printed premise. Kept excluded pending correction of the source constant.", "correct": null}, {"id": "est2-papers-2026-09-26:l2oct:q04", "old_status": "needs_source_repair", "status": "needs_source_reconstruction", "note": "Original source image visually checked again. The source crop and PDF contain no shaded-region diagram or description. Curved hemisphere area is 2πr² and total area is 3πr², but neither defines an arbitrary shaded subset. An original diagram is required; no answer can be verified.", "correct": null}]$payload$::jsonb) LOOP
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
