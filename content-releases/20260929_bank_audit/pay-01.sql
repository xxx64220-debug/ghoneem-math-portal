-- Source and independent-solution verification; no historical scores changed.
-- Before-images are retained in audit_log; rows in active exams are deferred.
DO $review$
DECLARE v jsonb; q public.questions%rowtype; k public.question_keys%rowtype; a jsonb; f jsonb; patch jsonb;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"id": "0ab8381f-506f-0110-de66-8b58e150435e", "before": {"stem": "Question 37. A craftsman who works 6 hours per day can complete a given project in 15 days,\n receiving $8 per hour. He is asked to finish the project in 10 days. Knowing that\n he will get a 50% increase on his hourly rate for each day he works more than\n 6 hours, what is the maximum he will be paid for the project?", "choices": [{"key": "A", "text": "$480"}, {"key": "B", "text": "$840"}, {"key": "C", "text": "$960"}, {"key": "D", "text": "$1,080"}, {"key": "E", "text": "$1,320"}], "correct": "B", "explanation": "The work is 6*15=90 hours, requiring 9 hours per day for 10 days. The first six hours pay 6*$8 and the three overtime hours pay 3*$12 per day: 10(48+36)=$840."}, "correct": "D", "explanation": "The project requires 6×15=90 hours. The highest hourly rate is 8×1.5=$12, so payment cannot exceed 90×12=$1,080. Working 9 hours on each of 10 days qualifies every day for this rate, achieving $1,080 (D). The former $840 key applied an overtime-only rule, which is different from the whole-day rate specified here.", "release": true, "source": "EST 2 HS Math Level 1 Jan 2026, physical page 181", "review_note": "Full original visually checked. Made the whole-day rate rule explicit and corrected B to D; preserved distinct overtime-only variant with an explicit rule.", "fields": {"stem": "A craftsman can finish a project by working 6 hours per day for 15 days at $8 per hour. He must finish in 10 days. On any day he works more than 6 hours, his hourly rate for that entire day increases by 50%. What is the maximum total payment for the project?", "assets_patch": {"source_verification_date": "2026-09-29"}}}, {"id": "edfcbf1b-55f0-4476-94bb-8b2e12a57c89", "before": {"stem": "Question 37. A craftsman works 6 hours per day and finishes a project in 15 days at $8 per hour. To finish it in 10 days, he works extra hours each day at 50% above the regular hourly rate. How much will he earn?", "choices": [{"key": "A", "text": "$480"}, {"key": "B", "text": "$840"}, {"key": "C", "text": "$960"}, {"key": "D", "text": "$1,080"}, {"key": "E", "text": "$1,320"}], "correct": "B", "explanation": "The project takes 6×15=90 hours. Over 10 days, 60 hours are paid at 8 per hour and 30 overtime hours at 12 per hour. Total=60×8+30×12=840."}, "correct": "B", "explanation": "The project takes 6×15=90 hours. Equal days over 10 days require 9 hours per day. Each day, the first 6 hours earn $8/hour and the next 3 earn $12/hour. Total pay is 10(6×8+3×12)=$840 (B).", "release": true, "source": "Existing explicitly adapted overtime-only variant; independent arithmetic verification", "review_note": "Explicit overtime-only variant checked; clarified equal-length days and which hours receive the higher rate. Source fidelity of this adapted variant is not asserted.", "fields": {"stem": "A craftsman can finish a project by working 6 hours per day for 15 days at $8 per hour. He instead works equal-length days to finish in 10 days. Each day, only the hours beyond the first 6 are paid at 50% above the regular hourly rate. How much will he earn?", "assets_patch": {"source_verification_date": "2026-09-29"}}}]$payload$::jsonb) LOOP
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
