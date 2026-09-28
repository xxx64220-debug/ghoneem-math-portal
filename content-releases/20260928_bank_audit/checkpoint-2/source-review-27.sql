DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:GTC 007", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "62a970a5-1471-5c2d-acfd-6a63ecdd0c1a", "stem": "Positive quantities satisfy \\(R=2GM/c^2\\). Which expression equals c?", "choices": [{"key": "A", "text": "\\(\\sqrt{R/(2GM)}\\)"}, {"key": "B", "text": "\\(\\sqrt{2GMR}\\)"}, {"key": "C", "text": "\\(\\sqrt{GMR/2}\\)"}, {"key": "D", "text": "\\(\\sqrt{2GM/R}\\)"}], "type": "mcq", "correct": "D", "explanation": "Multiply by c² and divide by R to obtain c²=2GM/R. Since c is positive, c=√(2GM/R).", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Kept the supplied formula and corrected the inaccurate physical description by presenting the algebraic relation directly.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 371, "extra_sources": []}, {"id": "clean:GTC 008", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "d6630a67-bf59-51bb-9376-12f24aad088c", "stem": "Angles x and y are acute. If sin(x−20°)=cos(y+12°), what is x+y in degrees?", "choices": [], "type": "grid_in", "correct": "98", "explanation": "Use cos(y+12°)=sin(78°−y). Both x−20° and 78°−y lie strictly between −90° and 90°, where sine is one-to-one. Hence x−20=78−y, giving x+y=98.", "topic": "Coordinate Geometry & Circles", "note": "Verified acute-angle conditions; omitted preceding incomplete b/c fragment.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 371, "extra_sources": []}, {"id": "clean:GTC 009", "old_status": "ocr_screened_not_verified", "status": "duplicate", "note": "Recovered the graph: the given line passes through (−3,4) and (5,−3), slope −7/8. Its perpendicular through (1,1/2) is y=(8/7)x−9/14. This is D in the clean source but C in canonical FA 031 because choice order differs. Reused that existing question.", "correct": "D", "duplicate_of": "topic:FA 031", "question_id": "294f45d5-b3c3-5268-86ef-2b78f4f27251", "before": {"stem": "What is the equation of the line passing through A(1, 0.5) and perpendicular to the graphed line?", "choices": [{"key": "A", "text": "y = (1/2)x"}, {"key": "B", "text": "y = (7/8)x − 3/8"}, {"key": "C", "text": "y = (8/7)x − 9/14"}, {"key": "D", "text": "y = 2x − 3/2"}], "correct": "C", "explanation": "The graph's slope is −7/8, so a perpendicular line has slope 8/7. Through (1, 1/2), its equation is y − 1/2 = (8/7)(x − 1)."}}, {"id": "clean:GTC 010", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "c48eb06d-2fc3-542c-9535-6450678ed75c", "stem": "A circle has center E(−1,2) and passes through F(−3,0). What is its circumference?", "choices": [{"key": "A", "text": "π√2"}, {"key": "B", "text": "2π√2"}, {"key": "C", "text": "4π√2"}, {"key": "D", "text": "4√2"}], "type": "mcq", "correct": "C", "explanation": "The radius EF=√[(-3+1)²+(0−2)²]=√8=2√2. The circumference is 2πr=4π√2.", "topic": "Coordinate Geometry & Circles", "note": "Coordinates checked from the original plot. Reused existing GT 003 and separately published the complete following rational-equation question.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 373, "extra_sources": [], "parts": [{"label": "Q9", "question_id": "5b10750f-e199-58d5-ad4d-7df5bfd842c8", "stem": "What is the greatest solution of \\(-1/(2x)=(x-3)/4\\)?", "choices": [{"key": "A", "text": "2"}, {"key": "B", "text": "1"}, {"key": "C", "text": "0"}, {"key": "D", "text": "−1"}], "type": "mcq", "correct": "A", "explanation": "The domain excludes x=0. Multiplying by 4x gives −2=x(x−3), or (x−1)(x−2)=0. Both 1 and 2 satisfy the original equation, so the greater solution is 2.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Split from the original shared crop; original PDF visually checked and solution independently verified."}], "before": {"stem": "Using the figure, what is the circumference of the circle with center E and passing through point F?", "choices": [{"key": "A", "text": "π√2"}, {"key": "B", "text": "2π√2"}, {"key": "C", "text": "4π√2"}, {"key": "D", "text": "4√2"}], "correct": "C", "explanation": "The radius is the distance between the given center and point: √(2² + 2²) = 2√2. Circumference = 2πr = 4π√2."}}, {"id": "clean:GTC 013", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "60f3e92c-7eac-5f5d-ae7a-79535a3e6cd7", "stem": "A substance has density 14.2 g/cm³. What is the mass, in kilograms, of 6 liters of this substance?", "choices": [], "type": "grid_in", "correct": "85.2", "explanation": "Six liters is 6000 cm³. Mass=density×volume=14.2×6000=85200 g=85.2 kg.", "topic": "Coordinate Geometry & Circles", "note": "Isolated the complete density question. The preceding trigonometric fragment has no given relation; its related GT 022 transcription is mathematically inconsistent and remains excluded.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 375, "extra_sources": []}, {"id": "clean:GTC 016", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "4b507ed9-6b97-5dfb-858a-fa5eaefe609d", "stem": "Which quantities are discrete? I. Number of players; II. Speed of a car; III. Academic rank; IV. Height of a building; V. Body weight.", "choices": [{"key": "A", "text": "I and II"}, {"key": "B", "text": "I, II, and III"}, {"key": "C", "text": "IV and V"}, {"key": "D", "text": "I and III"}], "type": "mcq", "correct": "D", "explanation": "Player counts and ranks take separated, countable values. Speed, height, and weight are modeled as continuous measurements. Thus I and III are discrete.", "topic": "Statistics, Probability & Data Analysis", "note": "Recovered the clipped opening from the visible word discrete and the full list on page 377.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 377, "extra_sources": []}]$payload$::jsonb) LOOP
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
