DO $review$
DECLARE v jsonb; s public.est_source_review%rowtype; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; qid uuid;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "clean:HOA 003", "old_status": "worked_needs_crop", "status": "ready", "question_id": "946e1599-da2b-52ff-ace4-575d4a34fc58", "stem": "In 2017, 3.2 million people in a country had access to the internet. The number grows by 18% each year. Which expression models the number y, in millions, x years after 2017?", "choices": [{"key": "A", "text": "y = 0.18x + 32"}, {"key": "B", "text": "y = 1.18x + 32"}, {"key": "C", "text": "y = 3.2(0.18)^x"}, {"key": "D", "text": "y = 3.2(1.18)^x"}], "type": "mcq", "correct": "D", "explanation": "An 18% annual increase multiplies the previous amount by 1 + 0.18 = 1.18. Starting with 3.2 million gives y = 3.2(1.18)^x. At x = 0 this equals 3.2, and each additional year multiplies it by 1.18.", "topic": "Rational, Radical, Exponential & Logarithmic Functions", "note": "Source page 5 visually checked; restored the clipped opening sentence using the stated baseline and year.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 5, "extra_sources": []}, {"id": "clean:HOA 004", "old_status": "worked_missing_choice", "status": "ready", "question_id": "2e8da2f7-48aa-5857-9498-840bc506fd0a", "stem": "If \\(\\frac{2i^2-3i}{1-2i}=a+bi\\), where a and b are real and \\(i^2=-1\\), what is a?", "choices": [], "type": "grid_in", "correct": ["4/5", "0.8"], "explanation": "Use \\(i^2=-1\\) and multiply numerator and denominator by \\(1+2i\\): \\(\\frac{(-2-3i)(1+2i)}{(1-2i)(1+2i)}=\\frac{4-7i}{5}\\). The real part is \\(a=4/5\\).", "topic": "Sequences, Complex Numbers & Advanced Algebra", "note": "Source page 5 visually checked. Released as a numeric response; no invented options.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 5, "extra_sources": []}, {"id": "clean:HOA 011", "old_status": "worked_shared_stimulus", "status": "ready", "question_id": "7a4fef16-965a-5ab6-852b-41b0cb7404f0", "stem": "The system \\(13x-7y=12\\) and \\(7x-13y=6\\) holds. What is \\(4x+4y\\)?", "choices": [], "type": "grid_in", "correct": "4", "explanation": "Subtract the second equation from the first: \\(6x+6y=6\\), so \\(x+y=1\\). Therefore \\(4x+4y=4\\).", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Combined the two parts of original Q16 on page 10.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 10, "extra_sources": ["clean:HOA 012"]}, {"id": "clean:HOA 012", "old_status": "partial_multi_question", "status": "worked_shared_stimulus", "note": "Page 10 visually checked. The opening fragment completes HOA 011; linked there. The separate Q17 has sqrt(2^m)=8, so m=6 and sqrt(3^m)=27. It remains separate from Q16.", "correct": "27"}, {"id": "clean:HOA 047", "old_status": "worked_needs_crop", "status": "ready", "question_id": "c3aa8de2-bf8c-5c8b-b5d8-5dbe3f990cdd", "stem": "Which of these equations has a real solution? I. \\(\\sqrt{2x-1}=-x^2\\); II. \\(|x+1|=-3\\); III. \\((x+1)^2+3=0\\); IV. \\(\\sqrt{2x-1}=x\\).", "choices": [{"key": "A", "text": "I only"}, {"key": "B", "text": "IV only"}, {"key": "C", "text": "I, II, and III"}, {"key": "D", "text": "III and IV"}], "type": "mcq", "correct": "B", "explanation": "I requires \\(x\\ge1/2\\), but then its left side is nonnegative and its right side is negative. II is impossible because absolute values are nonnegative. III has a left side at least 3. For IV, squaring gives \\(2x-1=x^2\\), or \\((x-1)^2=0\\). The candidate x = 1 satisfies the original equation. Thus only IV has a real solution.", "topic": "Algebra Foundations, Equations & Inequalities", "note": "Source page 34 visually checked. Unrelated following parabola excluded.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 34, "extra_sources": []}, {"id": "clean:HOA 050", "old_status": "worked_needs_crop", "status": "ready", "question_id": "0e91c979-e233-5f97-9243-a39bccae2065", "stem": "If \\(h(x)=-x^2+3x-2\\) and \\(k(x)=-2x-5\\), what is \\(h(k(-2))\\)?", "choices": [{"key": "A", "text": "−6"}, {"key": "B", "text": "−4"}, {"key": "C", "text": "0"}, {"key": "D", "text": "2"}], "type": "mcq", "correct": "A", "explanation": "First \\(k(-2)=4-5=-1\\). Then \\(h(-1)=-(-1)^2+3(-1)-2=-1-3-2=-6\\).", "topic": "Functions, Transformations & Graphs", "note": "Source page 36 visually checked; removed the unrelated preceding fragment.", "source_document": "Math_Question_Bank_Ghoneem_Clean.pdf", "source_page": 36, "extra_sources": []}]$payload$::jsonb) LOOP
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
