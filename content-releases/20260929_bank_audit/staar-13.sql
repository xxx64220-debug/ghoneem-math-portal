-- Source and independent-solution verification; no historical scores changed.
-- Before-images are retained in audit_log; rows in active exams are deferred.
DO $review$
DECLARE v jsonb; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; f jsonb; patch jsonb;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "78d8d80b-02f7-5fed-838c-96c40934c99c", "source": "https://tea.texas.gov/student-assessment/staar/released-test-questions/2019-staar-algebra-i-test.pdf; physical p36", "review_note": "Original released test visually matched; all graph choices, labels and answer independently verified. Removed the unreliable text-only figure description.", "explanation": "Hours are nonnegative and their total satisfies x + y ≤ 48. In the first quadrant, this is the region on or below the solid line joining (0,48) and (48,0). Graph A shows that region, including its boundary.", "correct": "A", "release": true, "before": {"stem": "A college student has two different jobs. Her combined work schedules consist of no more than 48 hours in one week. Which graph best represents the solution set for all possible combinations of x, the number of hours she worked at her first job, and y, the number of hours she worked at her second job, in one week?\n[Figure: four \"Work Schedule\" grids. A: line from (0,48) to (48,0), shaded below the line. B: line from (0,48) to (48,0), shaded above. C: line from (0,0) to (54,54), shaded above. D: line from (0,0) to (54,54), shaded below.]", "choices": [{"key": "A", "text": "Graph A"}, {"key": "B", "text": "Graph B"}, {"key": "C", "text": "Graph C"}, {"key": "D", "text": "Graph D"}], "correct": "A", "explanation": "Source-keyed answer from book_t8.md (T8-47)."}, "fields": {"stem": "A college student has two jobs and works no more than 48 hours in total per week. Which graph represents all possible combinations of x hours at her first job and y hours at her second job?", "assets_patch": {"figure_required": false, "source_verification_date": "2026-09-29"}}, "figure_from_id": "fa4f1b8a-aa64-5a17-ae36-c2cb7bb5a237"}]$payload$::jsonb) LOOP
  SELECT * INTO q FROM public.questions WHERE id=(v->>'id')::uuid FOR UPDATE;
  SELECT * INTO k FROM public.question_keys WHERE question_id=q.id FOR UPDATE;
  IF q.id IS NULL OR k.question_id IS NULL THEN RAISE EXCEPTION 'Missing question/key %',v->>'id'; END IF;
  IF EXISTS(SELECT 1 FROM public.audit_log WHERE action='question_review_20260929' AND target_id=q.id::text) THEN CONTINUE; END IF;
  IF q.stem IS DISTINCT FROM v->'before'->>'stem' OR q.choices IS DISTINCT FROM v->'before'->'choices'
     OR k.correct IS DISTINCT FROM v->'before'->'correct' OR k.explanation IS DISTINCT FROM v->'before'->>'explanation' THEN
    RAISE EXCEPTION 'Concurrent question change %',q.id;
  END IF;
  IF EXISTS(SELECT 1 FROM public.exams e JOIN public.attempts t ON t.exam_id=e.id
      WHERE q.id=ANY(e.question_ids) AND t.status='in_progress' AND t.deadline_at>now()) THEN
    INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES('question_review_deferred_20260929','question',q.id::text,jsonb_build_object('reason','Active exam','proposed',v));
    CONTINUE;
  END IF;
  INSERT INTO public.audit_log(action,target_type,target_id,meta)
  VALUES('question_review_20260929','question',q.id::text,jsonb_build_object('before_question',to_jsonb(q),'before_key',to_jsonb(k),'verification',v-'before'));
  a=coalesce(q.assets,'{}'::jsonb); patch=coalesce(v->'fields','{}'::jsonb);
  IF v ? 'figure_from_id' THEN
   SELECT assets->'figure' INTO f FROM public.questions WHERE id=(v->>'figure_from_id')::uuid;
   IF f IS NULL THEN RAISE EXCEPTION 'Missing verified figure for %',q.id; END IF;
   a=(a-'figure_required')||jsonb_build_object('figure',f,'figure_verified_source',v->>'figure_from_id');
  END IF;
  a=a||coalesce(patch->'assets_patch','{}'::jsonb)||jsonb_build_object(
    'answer_review','2026-09-29-independent-solution-and-source-check','verification_source',v->>'source',
    'verification_note',v->>'review_note','content_audit','2026-09-29-all-bank-structural-audit');
  IF coalesce((v->>'release')::boolean,false) THEN
   a=(a-'release_hold_reason')||jsonb_build_object('verified_release','2026-09-29-independent-solution-and-source-check');
  ELSIF v ? 'duplicate_of' THEN
   a=a||jsonb_build_object('release_hold_reason','Duplicate of reviewed question','duplicate_of',v->>'duplicate_of');
  END IF;
  UPDATE public.questions SET stem=coalesce(patch->>'stem',q.stem),choices=coalesce(patch->'choices',q.choices),
   topic=coalesce(patch->>'topic',q.topic),type=coalesce(patch->>'type',q.type),assets=a WHERE id=q.id;
  UPDATE public.question_keys SET correct=coalesce(v->'correct',k.correct),explanation=coalesce(v->>'explanation',k.explanation) WHERE question_id=q.id;
  IF v->>'source_question_id' IS NOT NULL THEN
   INSERT INTO public.audit_log(action,target_type,target_id,meta)
   SELECT 'staged_question_review_20260929','question_bank',b.question_id,jsonb_build_object('before',to_jsonb(b)) FROM public.question_bank b WHERE b.question_id=v->>'source_question_id';
   UPDATE public.question_bank SET stem_text=coalesce(patch->>'stem',q.stem),choices=coalesce(patch->'choices',q.choices),
    answer_key=coalesce(v->'correct',k.correct)#>>'{}',answer_explanation=coalesce(v->>'explanation',k.explanation),
    answer_key_status='independently_verified',needs_review=false,review_reasons=jsonb_build_array(v->>'review_note')
   WHERE question_id=v->>'source_question_id' AND coalesce((v->>'release')::boolean,false);
  END IF;
 END LOOP;
END;
$review$;
SELECT jsonb_build_object('applied',(SELECT count(*) FROM public.audit_log WHERE action='question_review_20260929'),
 'deferred',(SELECT count(*) FROM public.audit_log WHERE action='question_review_deferred_20260929')) AS result;
