DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 020", "old_status": "partial_multi_question", "status": "needs_source_reconstruction", "note": "Original PDF visually rechecked. Page 18 confirms that the definition of f is missing, so the vertex height of g(x)=f(x−10) cannot be calculated. Q34 only displays x/(x+2)−1/2=x−2, without the requested quantity. Its solutions are 2 and −3/2 (both valid), but the missing question cannot be reconstructed faithfully.", "correct": null}, {"id": "clean:HOA 026", "old_status": "needs_source_reconstruction", "status": "needs_source_reconstruction", "note": "Original PDF visually rechecked. Page 22 leaves the commission rule above 10 TV sales ambiguous. For 12 sales, 1550 assumes continued commission on all 12; 1530 assumes commission capped at 10; 1430 assumes base plus bonus only. The following h(x) question is cut off. Retained hold rather than inventing a payment rule.", "correct": null}, {"id": "clean:HOA 029", "old_status": "needs_source_reconstruction", "status": "duplicate", "note": "Recovered gold table from PSD 040 page 177: 2013=1668.86, 2019=1393.34. Rate=(1393.34−1668.86)/6=−45.92 per year, A. Exact matching question already exists as DAP 056; no new duplicate published.", "correct": "A", "duplicate_of": "topic:DAP 056", "question_id": "338022f0-909a-52f9-86aa-271e2719bad9", "audit_action": "source_review_20260928_revision2", "before": {"stem": "Average closing gold price ($): 2020: 1,771.90; 2019: 1,393.34; 2018: 1,268.93; 2017: 1,251.92; 2016: 1,158.86; 2015: 1,266.06; 2014: 1,409.51; 2013: 1,668.86. Supposing that the relation is a linear function, what is the rate of change between the years 2013 and 2019?", "choices": [{"key": "A", "text": "−45.92"}, {"key": "B", "text": "−39.36"}, {"key": "C", "text": "39.36"}, {"key": "D", "text": "45.92"}], "correct": "A", "explanation": "The rate of change is (1,393.34 − 1,668.86)/(2019 − 2013) = −275.52/6 = −45.92 per year."}}, {"id": "clean:HOA 032", "old_status": "missing_stimulus", "status": "needs_source_reconstruction", "note": "Original PDF visually rechecked. Page 25 has no seasonal-ticket quantities/revenues or axis definitions. None of the four line equations can be selected from the surviving text.", "correct": null}, {"id": "clean:HOA 033", "old_status": "needs_source_reconstruction", "status": "duplicate", "note": "Recovered the laptop graph on PSD 046 page 182 and complete questions DAP 070/071 on topic page 46. Slope=(19−17.4)/(2015−2010)=0.32, rounded 0.3, C. The separate count question sums 67+61+70=198, C, and already exists at fecf4f9f-acea-5772-964c-dd4f1f2f8f3d. Both original fragments resolved by these canonical questions.", "correct": "C", "duplicate_of": "topic:DAP 070", "question_id": "6a1f631a-6320-5688-8fae-2f04082dba4b", "audit_action": "source_review_20260928_revision2", "before": {"stem": "Questions 44 and 45 refer to a scatterplot showing how many laptops for different companies were repaired by a computer engineer between years 2010 and 2015, with a dashed line of best fit rising from about (2010, 17.4) to (2015, 19). — Based on the line of best fit shown as a dashed line, what is the average yearly increase in the number of repaired laptops rounded to the nearest tenth?", "choices": [{"key": "A", "text": "0.1"}, {"key": "B", "text": "0.2"}, {"key": "C", "text": "0.3"}, {"key": "D", "text": "0.5"}], "correct": "C", "explanation": "The fitted increase is (19 − 17.4)/(2015 − 2010) = 0.32 per year, rounding to 0.3."}}, {"id": "clean:HOA 041", "old_status": "needs_source_reconstruction", "status": "ready", "question_id": "b3b3cf38-e180-56fb-98c1-a5300a8ddd5e", "stem": "For what nonzero value of b does the quadratic equation ba²+2a−3=0 have exactly one real solution for a?", "choices": [], "type": "grid_in", "correct": ["-1/3", "-0.3333333333333333"], "explanation": "Because b≠0 the equation is quadratic in a. Exactly one real root requires discriminant 2²−4b(−3)=4+12b=0, giving b=−1/3. Substitution yields −(a−3)²/3=0, with the single root a=3.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Completed the clipped phrase “single real solution” and explicitly required a quadratic/nonzero b. Without that restriction, b=0 is an additional linear case.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 29, "extra_sources": []}]$payload$::jsonb) LOOP
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
