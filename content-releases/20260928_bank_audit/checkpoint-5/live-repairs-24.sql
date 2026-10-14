-- Source and independent-solution verification; no historical scores changed.
-- Before-images are retained in audit_log; rows in active exams are deferred.
DO $review$
DECLARE v jsonb; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; f jsonb; patch jsonb;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "c46f2294-ba80-5847-9f99-f82db1572b10", "before": {"stem": "Which two transformations can be used to obtain the graph of g(x) = −√(x − c) from the graph of f(x) = √x if c > 0 ?", "choices": [{"key": "A", "text": "A translation to the right c units followed by a reflection across the x-axis"}, {"key": "B", "text": "A translation to the left c units followed by a reflection across the x-axis"}, {"key": "C", "text": "A translation to the right c units followed by a reflection across the y-axis"}, {"key": "D", "text": "A translation to the left c units followed by a reflection across the y-axis"}], "correct": "A", "explanation": "Source-keyed answer from moh.md (MA-17)."}, "source_question_id": "MA-17", "source": "Kimi supplied transcription, moh.md MA-17; complete formulas in stem", "review_note": "Structural flag is a false positive: both functions are explicitly defined, so no separate graph is needed. Independently checked both transformations.", "release": true, "fields": {}, "explanation": "Replacing x by x − c translates y = √x to the right by c units. Negating the entire output reflects that translated graph across the x-axis, giving y = −√(x − c). Thus A is correct.", "correct": "A"}, {"id": "065c9af9-a689-5887-8031-6ed01300d5f7", "before": {"stem": "Which type of transformation can be used to obtain the graph of g(x) = 4(2^x) from the graph of f(x) = 2^x ?", "choices": [{"key": "F", "text": "Vertical shrink"}, {"key": "G", "text": "Vertical shift down"}, {"key": "H", "text": "Vertical shift up"}, {"key": "J", "text": "Vertical stretch"}], "correct": "J", "explanation": "Source-keyed answer from moh.md (MA-46)."}, "source_question_id": "MA-46", "source": "Kimi supplied transcription, moh.md MA-46; complete formulas in stem", "review_note": "Structural flag is a false positive: both exponential functions are explicit. Independently checked the scaling.", "release": true, "fields": {}, "explanation": "Because g(x) = 4f(x), every y-coordinate is multiplied by 4 while x stays fixed. This is a vertical stretch by a factor of 4, choice J. It is not a vertical shift, which would add a constant.", "correct": "J"}, {"id": "45bccf82-49f4-5b2d-b55d-383451dcdaf2", "before": {"stem": "Which type of transformation can be used to obtain the graph of g(x) = 4(2^x) from the graph of f(x) = 2^x ?", "choices": [{"key": "F", "text": "Vertical shrink"}, {"key": "G", "text": "Vertical shift down"}, {"key": "H", "text": "Vertical shift up"}, {"key": "J", "text": "Vertical stretch"}], "correct": "J", "explanation": "Source-keyed answer from moh.md (MA-46)."}, "source_question_id": "MA-46", "source": "Kimi supplied transcription, moh.md MA-46; complete formulas in stem", "review_note": "Structural flag is a false positive: both exponential functions are explicit. Independently checked the scaling.", "release": true, "fields": {}, "explanation": "Because g(x) = 4f(x), every y-coordinate is multiplied by 4 while x stays fixed. This is a vertical stretch by a factor of 4, choice J. It is not a vertical shift, which would add a constant.", "correct": "J"}]$payload$::jsonb) LOOP
  SELECT * INTO q FROM public.questions WHERE id=(v->>'id')::uuid FOR UPDATE;
  SELECT * INTO k FROM public.question_keys WHERE question_id=q.id FOR UPDATE;
  IF q.id IS NULL OR k.question_id IS NULL THEN RAISE EXCEPTION 'Missing question/key %',v->>'id'; END IF;
  IF EXISTS(SELECT 1 FROM public.audit_log WHERE action='question_review_20260928' AND target_id=q.id::text) THEN CONTINUE; END IF;
  IF q.stem IS DISTINCT FROM v->'before'->>'stem' OR q.choices IS DISTINCT FROM v->'before'->'choices'
     OR k.correct IS DISTINCT FROM v->'before'->'correct' OR k.explanation IS DISTINCT FROM v->'before'->>'explanation' THEN
    RAISE EXCEPTION 'Concurrent question change %',q.id;
  END IF;
  IF EXISTS(SELECT 1 FROM public.exams e JOIN public.attempts t ON t.exam_id=e.id
      WHERE q.id=ANY(e.question_ids) AND t.status='in_progress' AND t.deadline_at>now()) THEN
    INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES('question_review_deferred_20260928','question',q.id::text,jsonb_build_object('reason','Active exam','proposed',v));
    CONTINUE;
  END IF;
  INSERT INTO public.audit_log(action,target_type,target_id,meta)
  VALUES('question_review_20260928','question',q.id::text,jsonb_build_object('before_question',to_jsonb(q),'before_key',to_jsonb(k),'verification',v-'before'));
  a=coalesce(q.assets,'{}'::jsonb); patch=coalesce(v->'fields','{}'::jsonb);
  IF v ? 'figure_from_id' THEN
   SELECT assets->'figure' INTO f FROM public.questions WHERE id=(v->>'figure_from_id')::uuid;
   IF f IS NULL THEN RAISE EXCEPTION 'Missing verified figure for %',q.id; END IF;
   a=(a-'figure_required')||jsonb_build_object('figure',f,'figure_verified_source',v->>'figure_from_id');
  END IF;
  a=a||coalesce(patch->'assets_patch','{}'::jsonb)||jsonb_build_object(
    'answer_review','2026-09-28-independent-solution-and-source-check','verification_source',v->>'source',
    'verification_note',v->>'review_note','content_audit','2026-09-28-all-bank-structural-audit');
  IF coalesce((v->>'release')::boolean,false) THEN
   a=(a-'release_hold_reason')||jsonb_build_object('verified_release','2026-09-28-independent-solution-and-source-check');
  ELSIF v ? 'duplicate_of' THEN
   a=a||jsonb_build_object('release_hold_reason','Duplicate of reviewed question','duplicate_of',v->>'duplicate_of');
  END IF;
  UPDATE public.questions SET stem=coalesce(patch->>'stem',q.stem),choices=coalesce(patch->'choices',q.choices),
   topic=coalesce(patch->>'topic',q.topic),type=coalesce(patch->>'type',q.type),assets=a WHERE id=q.id;
  UPDATE public.question_keys SET correct=coalesce(v->'correct',k.correct),explanation=coalesce(v->>'explanation',k.explanation) WHERE question_id=q.id;
  IF v->>'source_question_id' IS NOT NULL THEN
   INSERT INTO public.audit_log(action,target_type,target_id,meta)
   SELECT 'staged_question_review_20260928','question_bank',b.question_id,jsonb_build_object('before',to_jsonb(b)) FROM public.question_bank b WHERE b.question_id=v->>'source_question_id';
   UPDATE public.question_bank SET stem_text=coalesce(patch->>'stem',q.stem),choices=coalesce(patch->'choices',q.choices),
    answer_key=coalesce(v->'correct',k.correct)#>>'{}',answer_explanation=coalesce(v->>'explanation',k.explanation),
    answer_key_status='independently_verified',needs_review=false,review_reasons=jsonb_build_array(v->>'review_note')
   WHERE question_id=v->>'source_question_id' AND coalesce((v->>'release')::boolean,false);
  END IF;
 END LOOP;
END;
$review$;
SELECT jsonb_build_object('applied',(SELECT count(*) FROM public.audit_log WHERE action='question_review_20260928'),
 'deferred',(SELECT count(*) FROM public.audit_log WHERE action='question_review_deferred_20260928')) AS result;
