DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:GTC 065", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "49c53c43-048b-55c5-940b-a60f7d69f6c0", "stem": "Triangle ABC is isosceles with AB=AC. The internal bisectors of its base angles meet at D, and ∠BDC=100°. If x is the measure of ∠A in degrees, what is x?", "choices": [{"key": "A", "text": "20"}, {"key": "B", "text": "60"}, {"key": "C", "text": "100"}, {"key": "D", "text": "120"}], "type": "mcq", "correct": "A", "explanation": "Let each base angle be β. Triangle BDC has angles β/2, β/2, and 100°, so β+100°=180° and β=80°. Hence ∠A=180°−2·80°=20°.", "topic": "Coordinate Geometry & Circles", "note": "The original omits x from its drawing. Corrected adaptation explicitly defines x as the vertex angle A; all supplied geometry and the 100° angle are preserved.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 408, "extra_sources": []}, {"id": "clean:GTC 066", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "de07f274-f0a8-5a47-982a-be737a77b16a", "stem": "A circle’s circumference increases from π cm to 2π cm. What happens to its area?", "choices": [{"key": "A", "text": "It remains the same."}, {"key": "B", "text": "It is halved."}, {"key": "C", "text": "It is doubled."}, {"key": "D", "text": "It is quadrupled."}], "type": "mcq", "correct": "D", "explanation": "Since C=2πr, doubling circumference doubles radius. Area πr² therefore scales by 2²=4.", "topic": "Coordinate Geometry & Circles", "note": "Confirmed that the printed symbols are π and 2π, not OCR digits 7 and 27.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 409, "extra_sources": []}, {"id": "clean:GTC 067", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "90926789-7803-50e0-b0d4-6085abd345c9", "stem": "A right triangle sits above a rectangle of width 10 units. Its horizontal leg spans the rectangle’s width and extends 2 more units to the right; its hypotenuse is 13 units. What is the triangle’s vertical leg?", "choices": [{"key": "A", "text": "5"}, {"key": "B", "text": "8"}, {"key": "C", "text": "10"}, {"key": "D", "text": "13"}], "type": "mcq", "correct": "A", "explanation": "The horizontal leg is 10+2=12. Pythagoras gives the vertical leg √(13²−12²)=√25=5.", "topic": "Coordinate Geometry & Circles", "note": "Corrected adaptation: the original asks for AB but labels A and B are absent. The revised wording explicitly identifies the intended vertical triangle leg and preserves all visible lengths.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 410, "extra_sources": []}, {"id": "clean:GTC 068", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "dcb17b80-995e-5ff9-a963-2b4e15304100", "stem": "Three equal circles of radius 3 cm lie in a row inside a rectangle, tangent to its top and bottom. The first and last circles are tangent to the left and right sides. Adjacent circles overlap horizontally by 1 cm along the line through their centers. What is the rectangle’s perimeter?", "choices": [{"key": "A", "text": "32 cm"}, {"key": "B", "text": "44 cm"}, {"key": "C", "text": "48 cm"}, {"key": "D", "text": "96 cm"}], "type": "mcq", "correct": "B", "explanation": "The height is one diameter, 6 cm. The width is three diameters minus the two 1-cm overlaps: 18−2=16 cm. Hence the perimeter is 2(16+6)=44 cm.", "topic": "Coordinate Geometry & Circles", "note": "Clarified the meaning of x=1 in the two overlapping regions as horizontal overlap along the centers; supplied all geometry in text.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 411, "extra_sources": []}, {"id": "clean:GTC 069", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "b78ad125-d321-5af9-9124-de8d7bb2f687", "stem": "A car’s fuel gauge rises from 1/3 full to 5/9 full when 4 gallons are added. What is the tank’s total capacity in gallons?", "choices": [{"key": "A", "text": "4"}, {"key": "B", "text": "4.5"}, {"key": "C", "text": "7.2"}, {"key": "D", "text": "18"}], "type": "mcq", "correct": "D", "explanation": "The added fraction is 5/9−1/3=2/9. If capacity is C, then (2/9)C=4, so C=18 gallons.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Original PDF visually checked; isolated complete question and independently verified the solution.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 412, "extra_sources": []}, {"id": "clean:GTC 070", "old_status": "ocr_screened_not_verified", "status": "duplicate", "note": "Exact repeated pair on pages 404 and 413. Reused GTC 061 and its separately published Q6: equal right-triangle leg 5√2, and least integer third side 6. The ambiguous radical distractor was repaired in the canonical copy.", "correct": ["A", "A"], "duplicate_of": "clean:GTC 061", "question_id": "1b73cea9-812f-5166-b047-53fde56c8da0"}]$payload$::jsonb) LOOP
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
