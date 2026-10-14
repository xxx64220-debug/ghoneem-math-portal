-- Two source-verified grid-ins. Apply only after the tested numeric_range_keys.sql grader.
-- All expected question, key, and review states are guarded; reruns are idempotent.
DO $release$
DECLARE v jsonb; b public.question_bank%rowtype; qid uuid; response jsonb;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id":"college_panda_10_practice_tests-test01-s3-q16","stem":"If |1 − x| > 4 and x is positive, what is one possible value of x?","correct":"(5, ∞)","topic":"Absolute value","explanation":"The inequality |1 − x| > 4 means 1 − x > 4 or 1 − x < −4, so x < −3 or x > 5. Since x is positive, only x > 5 remains. Any finite real number greater than 5 is correct, for example 6 or 21/4. The endpoint 5 is excluded because |1 − 5| = 4.","valid":["6","21/4","5.00001"],"invalid":["5","0","-4"],"source_page":8},{"id":"college_panda_10_practice_tests-test01-s4-q33","stem":"For g(x) = √[(x − 1)(x − 2)], what is one possible value of x for which g is undefined over the real numbers?","correct":"(1, 2)","topic":"Functions: domain, range, inverse, and transformations","explanation":"A real square root is defined exactly when its radicand is nonnegative. The product (x − 1)(x − 2) is negative precisely between its roots, so g is undefined for 1 < x < 2. Any real number strictly between 1 and 2, such as 3/2, is correct. At either endpoint the radicand is zero and g is defined.","valid":["1.5","5/4","1.99999"],"invalid":["1","2","0"],"source_page":18}]$payload$::jsonb) LOOP
  IF EXISTS(SELECT 1 FROM public.audit_log WHERE action='staged_interval_release_20260929' AND target_id=v->>'id') THEN CONTINUE; END IF;
  SELECT * INTO b FROM public.question_bank WHERE question_id=v->>'id' FOR UPDATE;
  IF b.question_id IS NULL OR b.publication_status<>'review_required' OR NOT b.needs_review
     OR b.answer_key IS NOT NULL OR b.stem_text IS DISTINCT FROM v->>'stem'
     OR b.source_page_start<>(v->>'source_page')::integer THEN
   RAISE EXCEPTION 'Reviewed source changed: %',v->>'id';
  END IF;
  IF EXISTS(SELECT 1 FROM public.questions WHERE assets->>'source_question_id'=b.question_id) THEN
   RAISE EXCEPTION 'Question already linked: %',b.question_id;
  END IF;
  FOR response IN SELECT value FROM jsonb_array_elements(v->'valid') LOOP
   IF public.answer_matches('grid_in',response,v->'correct') IS DISTINCT FROM true THEN RAISE EXCEPTION 'Grader rejects valid source answer %',response; END IF;
  END LOOP;
  FOR response IN SELECT value FROM jsonb_array_elements(v->'invalid') LOOP
   IF public.answer_matches('grid_in',response,v->'correct') IS DISTINCT FROM false THEN RAISE EXCEPTION 'Grader accepts invalid source answer %',response; END IF;
  END LOOP;
  qid=gen_random_uuid();
  INSERT INTO public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
  VALUES(qid,'sat',v->>'topic','medium','grid_in',b.stem_text,'[]'::jsonb,
   jsonb_build_object('source','The College Panda — 10 Practice Tests','source_question_id',b.question_id,
    'source_code',b.source_question_reference,'source_page',b.source_page_start,
    'figure_required',false,'verified_release','2026-09-29-independent-solution-and-source-check',
    'answer_review','2026-09-29-independent-solution-and-source-check',
    'verification_source','Original College Panda PDF: '||b.source_question_reference||', physical page '||b.source_page_start,
    'verification_note','Original source reviewed in the bank audit; independently solved. Accept every finite numeric response inside the verified open interval. No reconstructed visual is needed.'));
  INSERT INTO public.question_keys(question_id,correct,explanation) VALUES(qid,v->'correct',v->>'explanation');
  INSERT INTO public.audit_log(action,target_type,target_id,meta)
  VALUES('staged_interval_release_20260929','question_bank',b.question_id,
   jsonb_build_object('before',to_jsonb(b),'question_id',qid,'correct',v->'correct','explanation',v->>'explanation','grader_ci_run',36548320052));
  UPDATE public.question_bank SET publication_status='published',needs_review=false,
   answer_key=v->>'correct',answer_key_status='verified_interval_answer_20260929',
   answer_explanation=v->>'explanation',visual_source_required=false,
   review_reasons=coalesce(review_reasons,'[]'::jsonb)||jsonb_build_array('Released 2026-09-29 after complete interval grading passed isolated CI; every valid response is accepted and open endpoints are rejected.')
  WHERE question_id=b.question_id;
 END LOOP;
END $release$;
SELECT q.id,q.track_id,q.stem,k.correct,k.explanation,b.question_id source_question_id,b.publication_status,b.needs_review
FROM public.questions q JOIN public.question_keys k ON k.question_id=q.id JOIN public.question_bank b ON b.question_id=q.assets->>'source_question_id'
WHERE b.question_id IN ('college_panda_10_practice_tests-test01-s3-q16','college_panda_10_practice_tests-test01-s4-q33');
