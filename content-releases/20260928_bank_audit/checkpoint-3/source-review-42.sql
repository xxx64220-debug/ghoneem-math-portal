DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 232", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "353d0788-013a-5e99-9182-14c437557e7d", "stem": "Points B(3,3) and C(1,−1) have midpoint M(x,y). What is xy?", "choices": [{"key": "A", "text": "0"}, {"key": "B", "text": "2"}, {"key": "C", "text": "3"}, {"key": "D", "text": "4"}], "type": "mcq", "correct": "B", "explanation": "The midpoint is ((3+1)/2,(3−1)/2)=(2,1). Thus xy=2·1=2.", "topic": "Coordinate Geometry & Circles", "note": "Recovered and cross-checked coordinates on pages 140 and 415 (shared graph with GTC 073).", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 140, "extra_sources": []}, {"id": "clean:MIX 031", "old_status": "duplicate", "status": "duplicate", "note": "Repeated source image now linked to verified MIX 014. The eldest receives 1−3/5−1/4=3/20, so the full prize is 57/(3/20)=$380.", "correct": "A", "question_id": "0f936c8d-b2be-5974-8686-39ac98a729e7", "duplicate_of": "clean:MIX 014"}, {"id": "clean:GTC 056", "old_status": "duplicate", "status": "duplicate", "note": "Repeated source image now linked to verified GTC 040. Distance=42×2.3=96.6 km. The unrelated trigonometric fragment remains incomplete.", "correct": "96.6", "question_id": "b5ccdf03-f4ea-596c-904d-b86b463e085b", "duplicate_of": "clean:GTC 040"}, {"id": "clean:PAM 001", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "6f089e8f-7f30-59d8-aa32-511f1f874815", "stem": "Positive quantities satisfy \\(F=q_1q_2/(4\\pi\\varepsilon_0r^2)\\). Which expression gives r?", "choices": [{"key": "A", "text": "\\(4\\pi\\varepsilon_0F/(q_1q_2)\\)"}, {"key": "B", "text": "\\(\\sqrt{q_1q_2F/(4\\pi\\varepsilon_0)}\\)"}, {"key": "C", "text": "\\(\\frac12\\sqrt{q_1q_2/(\\pi\\varepsilon_0F)}\\)"}, {"key": "D", "text": "\\((q_1q_2/(4\\pi\\varepsilon_0))^2\\)"}], "type": "mcq", "correct": "C", "explanation": "Rearrange to r²=q₁q₂/(4πε₀F). Take the positive square root: r=(1/2)√[q₁q₂/(πε₀F)].", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Verified the printed formula and choice C; explicitly used positive quantities so the force magnitude and positive distance are consistent.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 309, "extra_sources": []}, {"id": "clean:PAM 004", "old_status": "ocr_screened_not_verified", "status": "needs_source_reconstruction", "note": "The original page contains four candidate expressions but no definition of y. Polynomial division cannot identify an equivalent expression without the missing numerator and denominator.", "correct": null}, {"id": "clean:PAM 006", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "014a0a7a-678c-5da8-ab02-20dcef1c9fb2", "stem": "For real x, let f(x)=5−2x and g(x)=x²/4. Which number is not in the range of f(g(x))?", "choices": [{"key": "A", "text": "−3"}, {"key": "B", "text": "0"}, {"key": "C", "text": "5"}, {"key": "D", "text": "6"}], "type": "mcq", "correct": "D", "explanation": "The composition is 5−2(x²/4)=5−x²/2. Since x²≥0, its range is (−∞,5]. Thus 6 is excluded; −3,0,5 are attained.", "topic": "Functions, Transformations & Graphs", "note": "Recovered g’s denominator 4 from the original image.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 311, "extra_sources": []}]$payload$::jsonb) LOOP
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
