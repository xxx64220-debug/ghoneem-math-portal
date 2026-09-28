DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "est2-papers-2026-09-26:sample4:q49", "old_status": "needs_source_repair", "status": "ready", "question_id": "b277c856-c263-5cf9-b85b-58118b05a14c", "stem": "In quadrilateral ABCD, AB is parallel to CD and angle DAB=70°. Diagonals AC and BD intersect at E. Triangle AEB is isosceles with AE=BE and angle AEB=66°. What is angle BCE?", "choices": [{"key": "A", "text": "13°"}, {"key": "B", "text": "22°"}, {"key": "C", "text": "30°"}, {"key": "D", "text": "53°"}, {"key": "E", "text": "66°"}], "type": "mcq", "correct": "D", "explanation": "In triangle AEB, the base angles EAB and EBA are (180°−66°)/2=57°. Because AB∥CD, triangles AEB and CED are similar, so CE=DE. Triangles AED and BEC are then congruent by SAS: AE=BE, ED=EC, and the included angles at E are vertical angles. Thus AD=BC and the trapezoid is isosceles, so angle ABC=70°. Therefore angle EBC=70°−57°=13°. Angle BEC=180°−66°=114°, so angle BCE=180°−114°−13°=53°.", "topic": "Triangles, Trigonometry & Similarity", "note": "Original source image decrypted, hash checked, and visually inspected. Corrected a false hold: the original given angle DAB=70°, parallel bases, and AE=BE do determine the answer. No numerical assumption or choice was changed.", "source_document": "EST 2 Math Level 1 - Test Sample 4.pdf", "source_page": 13}, {"id": "est2-papers-2026-09-26:l1june:q05", "old_status": "needs_source_repair", "status": "needs_source_reconstruction", "note": "Original source image visually checked again. Original diagram has no numerical side length. From tanβ=2/3, the sides are 2k, 3k, k√13 for any k>0. Both √13 and 2√13 are possible hypotenuse lengths. A source side length is required; no unique answer can be verified.", "correct": null}, {"id": "est2-papers-2026-09-26:l1oct:q45", "old_status": "needs_source_repair", "status": "needs_source_reconstruction", "note": "Original source image visually checked again. For a real angle θ, cos(π/2−θ)=sinθ cannot equal 2/√3>1. There is no real solution. The formal value 4/3 is not a valid answer to the printed premise. Kept excluded pending correction of the source constant.", "correct": null}, {"id": "est2-papers-2026-09-26:l2oct:q04", "old_status": "needs_source_repair", "status": "needs_source_reconstruction", "note": "Original source image visually checked again. The source crop and PDF contain no shaded-region diagram or description. Curved hemisphere area is 2πr² and total area is 3πr², but neither defines an arbitrary shaded subset. An original diagram is required; no answer can be verified.", "correct": null}, {"id": "clean:HOA 006", "old_status": "ready", "status": "ready", "question_id": "03e59cec-06cd-5381-88ba-55d5aa24e47c", "stem": "A line of slope −2/3 passes through A(2−k,5) and B(−2k,−1). What is k?", "choices": [{"key": "A", "text": "11"}, {"key": "B", "text": "4"}, {"key": "C", "text": "−4"}, {"key": "D", "text": "−11"}], "type": "mcq", "correct": "D", "explanation": "The slope from B to A is [5−(−1)]/[(2−k)−(−2k)]=6/(k+2). Set 6/(k+2)=−2/3 to get 18=−2k−4, so k=−11. Substitution gives 6/(−9)=−2/3. The minus sign in the original slope was visually checked.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 6, "extra_sources": [], "before": {"stem": "A line with slope −2/3 passes through A(2 − k, 5) and B(−2k, −1). What is k?", "choices": [{"key": "A", "text": "11"}, {"key": "B", "text": "4"}, {"key": "C", "text": "−4"}, {"key": "D", "text": "−11"}], "correct": "D", "explanation": "The slope is (−1 − 5)/(−2k − (2 − k)) = 6/(k + 2). Equating to −2/3 gives k = −11. Check: A = (13, 5), B = (22, −1), whose slope is −6/9."}}, {"id": "clean:HOA 007", "old_status": "ready", "status": "ready", "question_id": "afee4921-ee14-551e-abe7-c86f4f3acb45", "stem": "If \\(5-\\frac32x\\ge3\\), what is the greatest possible value of \\(\\frac98x+1\\)?", "choices": [{"key": "A", "text": "2.5"}, {"key": "B", "text": "3.5"}, {"key": "C", "text": "4.5"}, {"key": "D", "text": "5.5"}], "type": "mcq", "correct": "A", "explanation": "The inequality gives −3x/2≥−2, hence x≤4/3 after reversing the inequality when dividing by a negative number. The expression 9x/8+1 increases with x, so its maximum occurs at x=4/3 and equals (9/8)(4/3)+1=2.5.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 6, "extra_sources": [], "before": {"stem": "HOA 007 — Answer the original question below.", "choices": [{"key": "A", "text": "Option A in the original question"}, {"key": "B", "text": "Option B in the original question"}, {"key": "C", "text": "Option C in the original question"}, {"key": "D", "text": "Option D in the original question"}], "correct": "A", "explanation": "5-(3/2)x>=3 gives x<=4/3. Since 9x/8+1 increases withx, its maximum is 9(4/3)/8+1=2.5."}}]$payload$::jsonb) LOOP
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
