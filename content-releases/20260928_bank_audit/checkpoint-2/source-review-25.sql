DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:PSD 069", "old_status": "missing_stimulus", "status": "needs_source_reconstruction", "note": "Original full PDF page visually rechecked. The tops of the transport and salary bars are clipped. Required salary/transport ratio is unavailable; salary budget would be 200000 times that ratio.", "correct": null}, {"id": "clean:PSD 100", "old_status": "missing_stimulus", "status": "needs_source_reconstruction", "note": "Original full PDF page visually rechecked. The two-brand car-sales series is absent. Neither the percentage decline nor the elapsed time to a 50-car difference can be verified from this fragment.", "correct": null}, {"id": "clean:PSD 119", "old_status": "missing_stimulus_and_choices", "status": "needs_source_reconstruction", "note": "Original full PDF page visually rechecked. The shared line graph and choices C/D are missing. Surviving A/B cannot identify the intended pair of lines.", "correct": null}, {"id": "clean:PSD 126", "old_status": "missing_choices", "status": "needs_source_reconstruction", "note": "Original full PDF page visually rechecked. Only graph choice A survives. For x³+x+1, f′=3x²+1>0, so A’s two turning points disqualify it. The correct original graph choice is unavailable.", "correct": null}, {"id": "clean:PSD 127", "old_status": "needs_source_reconstruction", "status": "needs_source_reconstruction", "note": "Original full PDF page visually rechecked. The original grayscale legend does not distinguish several sectors reliably. If mango=17.6%, apple=21.5%, oranges=13.2%, the answer is about 250 and 118, B; however this mapping has not been verified independently of the choices. Keep held pending the color/original chart.", "correct": null}, {"id": "clean:PSD 136", "old_status": "needs_source_reconstruction", "status": "needs_source_reconstruction", "note": "Original full PDF page visually rechecked. The source line predicts about 48 chart units at x=2, but the axis unit is obscured. Answer 0.48 m requires centimeters; the original unit is unverified. Kept held rather than silently convert.", "correct": null}]$payload$::jsonb) LOOP
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
