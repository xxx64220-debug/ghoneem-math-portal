DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid; p jsonb; pid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:MIX 040", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "4fae0dc7-0d10-5a91-9c28-5eb4cc568bf8", "stem": "Using the ticket table and unchanged prices within each section, how much additional revenue would selling all remaining tickets produce?", "choices": [{"key": "A", "text": "$1345"}, {"key": "B", "text": "$8010"}, {"key": "C", "text": "$9870"}, {"key": "D", "text": "$11255"}], "type": "mcq", "correct": "B", "explanation": "Prices are VIP $130, A $35, B $30, and C $50. Unsold counts are 20,100,62,10. Additional revenue is 20·130+100·35+62·30+10·50=2600+3500+1860+500=$8010.", "topic": "Statistics, Probability & Data Analysis", "note": "Corrected B from 8460 to 8010 because none of the original options matches the verified table. The repeated Q26 is published once under MIX 039.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 439, "extra_sources": [], "assets": {"html": "<table><tr><th>Section</th><th>Available</th><th>Sold</th><th>Revenue ($)</th></tr><tr><th>VIP</th><td>100</td><td>80</td><td>10400</td></tr><tr><th>A</th><td>350</td><td>250</td><td>8750</td></tr><tr><th>B</th><td>350</td><td>288</td><td>8640</td></tr><tr><th>C</th><td>120</td><td>110</td><td>5500</td></tr></table>"}}, {"id": "clean:PSD 175", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "98413dc0-fc15-5e9b-8f97-e4a5f50c607f", "stem": "Suppose exactly the numbers of tickets in the table’s Sold row are sold, but every ticket price is reduced by 60%. What would the total revenue be?", "choices": [{"key": "A", "text": "$13316"}, {"key": "B", "text": "$1265"}, {"key": "C", "text": "$19974"}, {"key": "D", "text": "$3384"}], "type": "mcq", "correct": "A", "explanation": "Original revenue is 10400+8750+8640+5500=$33290. A 60% reduction leaves 40%, so the new revenue is 0.4·33290=$13316.", "topic": "Statistics, Probability & Data Analysis", "note": "Clarified that the sold quantities remain unchanged; selling every available seat is a different scenario. This resolves the original ambiguous “all tickets sold” wording. Repeated Q26 is published under MIX 039.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 272, "extra_sources": [], "assets": {"html": "<table><tr><th>Section</th><th>Available</th><th>Sold</th><th>Revenue ($)</th></tr><tr><th>VIP</th><td>100</td><td>80</td><td>10400</td></tr><tr><th>A</th><td>350</td><td>250</td><td>8750</td></tr><tr><th>B</th><td>350</td><td>288</td><td>8640</td></tr><tr><th>C</th><td>120</td><td>110</td><td>5500</td></tr></table>"}}, {"id": "clean:MIX 041", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "351fa76b-61f0-57c1-ac7c-dcbf350f49f1", "stem": "With \\(i^2=-1\\), simplify \\((2i-1)/(i-4)+3i-1\\).", "choices": [{"key": "A", "text": "\\((51i-11)/17\\)"}, {"key": "B", "text": "\\((44i+11)/17\\)"}, {"key": "C", "text": "\\((44i-11)/17\\)"}, {"key": "D", "text": "\\((51i+11)/17\\)"}], "type": "mcq", "correct": "C", "explanation": "Multiply the fraction by (−4−i)/(−4−i): (2i−1)/(i−4)=(6−7i)/17. Adding (51i−17)/17 gives (44i−11)/17.", "topic": "Complex Numbers", "note": "Both source copies (pages 440 and 450) confirm that +3i−1 is outside the fraction.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 440, "extra_sources": []}, {"id": "clean:MIX 042", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "fa15f2ab-d30e-51c8-8a6f-63aa5af75c2a", "stem": "Let h(x)=2x+a. If h(3)=5, what is h(1)?", "choices": [{"key": "A", "text": "1"}, {"key": "B", "text": "−1"}, {"key": "C", "text": "2"}, {"key": "D", "text": "1/2"}], "type": "mcq", "correct": "A", "explanation": "Since h(3)=6+a=5, a=−1. Therefore h(1)=2−1=1.", "topic": "Functions, Transformations & Graphs", "note": "Verified the input 3 in both source copies; it is not an unreadable variable.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 440, "extra_sources": []}, {"id": "clean:MIX 044", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "1ae9f061-a1e5-5948-9e74-0ebb5bef4502", "stem": "When 5 is subtracted from one fifth of a number, the result is 10. What is the number?", "choices": [{"key": "A", "text": "−25"}, {"key": "B", "text": "10"}, {"key": "C", "text": "25"}, {"key": "D", "text": "75"}], "type": "mcq", "correct": "D", "explanation": "If the number is n, then n/5−5=10. Thus n/5=15 and n=75. Check: 75/5−5=10.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Recovered the printed coefficient 1/5.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 441, "extra_sources": []}, {"id": "clean:MIX 046", "old_status": "ocr_screened_not_verified", "status": "ready", "question_id": "efb1b4b4-2d83-5bd6-9699-e3ee433291e1", "stem": "If \\(t/(2u)=3\\), \\(2r/s=16\\), and \\(s/t=2\\), what is \\(u/r\\)?", "choices": [{"key": "A", "text": "6/16"}, {"key": "B", "text": "1/96"}, {"key": "C", "text": "8/3"}, {"key": "D", "text": "96"}], "type": "mcq", "correct": "B", "explanation": "The first relation gives t=6u. The third gives s=2t=12u. The second gives r=8s=96u, so u/r=1/96.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "All three numerators and denominators visually checked; the given ratios require nonzero denominators.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 442, "extra_sources": []}]$payload$::jsonb) LOOP
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
