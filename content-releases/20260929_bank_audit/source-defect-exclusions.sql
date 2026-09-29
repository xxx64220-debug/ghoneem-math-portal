-- Close completed mathematical reviews of three defective source questions.
-- Preserve source text and worked findings; do not publish or guess a key.
DO $review$
DECLARE v jsonb; b public.question_bank%rowtype;
BEGIN
 FOR v IN SELECT value FROM jsonb_array_elements($payload$[{"question_id":"est1_dec_2025-q00019","stem_text":"20. If 4x 2 12x 52 is written as 4(x n)2 m, what is the value of (m n)?","publication_status":"review_required","needs_review":true,"answer_key":null,"answer_key_status":"rechecked_blocked_20260929","answer_explanation":"Completing the square gives 4x² − 12x + 52 = 4(x − 3/2)² + 43. If the intended form were 4(x − n)² + m, mn would be 129/2. The printed form instead says 4(x − n)² = m; that does not define such an identity."},{"question_id":"est2_hs_level1_jan_2026-q00054","stem_text":"Given 4x² + 8xz + 4y² − 4y = 110, find 4r³ if x = y = z = r.","publication_status":"review_required","needs_review":true,"answer_key":null,"answer_key_status":"rechecked_blocked_20260929","answer_explanation":"Putting x = y = z = r gives 16r² − 4r − 110 = 0, or (4r − 11)(2r + 5) = 0. Thus r = 11/4 or −5/2 and 4r³ is 83.1875 or −62.5. Neither exact value is listed, and positivity is not specified."},{"question_id":"statistics_probability_hw_aug_2026-q00006","stem_text":"Q6. Three people: 160, 170, 180 cm. One leaves, another joins. New mean = 175. New\n person's height?","publication_status":"review_required","needs_review":true,"answer_key":null,"answer_key_status":"rechecked_blocked_20260929","answer_explanation":"The old total is 160 + 170 + 180 = 510 cm, and the new total is 3 × 175 = 525 cm. If the departing height is d and the newcomer has height h, then 510 − d + h = 525, so h = d + 15. The possible heights are 175, 185, and 195 cm."}]$payload$::jsonb) LOOP
  IF EXISTS(SELECT 1 FROM public.audit_log WHERE action='staged_source_defect_exclusion_20260929' AND target_id=v->>'question_id') THEN CONTINUE; END IF;
  SELECT * INTO b FROM public.question_bank WHERE question_id=v->>'question_id' FOR UPDATE;
  IF b.question_id IS NULL OR b.publication_status<>'review_required' OR NOT b.needs_review
   OR b.answer_key IS NOT NULL OR b.stem_text IS DISTINCT FROM v->>'stem_text'
   OR b.answer_explanation IS DISTINCT FROM v->>'answer_explanation' THEN
   RAISE EXCEPTION 'Reviewed source changed: %',v->>'question_id';
  END IF;
  IF EXISTS(SELECT 1 FROM public.questions q WHERE q.assets->>'source_question_id'=b.question_id AND nullif(q.assets->>'release_hold_reason','') IS NULL) THEN
   RAISE EXCEPTION 'Defective source unexpectedly linked to a released record: %',b.question_id;
  END IF;
  INSERT INTO public.audit_log(action,target_type,target_id,meta)
   VALUES('staged_source_defect_exclusion_20260929','question_bank',b.question_id,jsonb_build_object('before',to_jsonb(b),'finding','Mathematical review complete: no unique valid answer to the printed source. Excluded pending a corrected original.'));
  UPDATE public.question_bank SET publication_status='excluded',needs_review=false,
   answer_key_status='reviewed_excluded_source_defect_20260929',
   review_reasons=coalesce(review_reasons,'[]'::jsonb)||jsonb_build_array('Review completed 2026-09-29. Source is defective or underdetermined; exclusion confirmed. Original text and worked explanation retained. Reopen only when a corrected original is available.')
  WHERE question_id=b.question_id;
 END LOOP;
END $review$;
SELECT question_id,publication_status,needs_review,answer_key_status FROM public.question_bank WHERE question_id IN ('est1_dec_2025-q00019','est2_hs_level1_jan_2026-q00054','statistics_probability_hw_aug_2026-q00006');
