-- Resolve duplicate review flags only after checking their canonical records.
DO $review$
DECLARE b public.question_bank%rowtype;c public.question_bank%rowtype;q public.questions%rowtype;k public.question_keys%rowtype;cid text; n integer:=0;
BEGIN
 FOR b IN SELECT * FROM public.question_bank WHERE question_id IN ('est2_hs_level1_jan_2026-q00297','est2_hs_level1_jan_2026-q00037') FOR UPDATE LOOP
  IF EXISTS(SELECT 1 FROM public.audit_log WHERE action='staged_pay_sync_20260929' AND target_id=b.question_id) THEN CONTINUE; END IF;
  SELECT * INTO q FROM public.questions WHERE assets->>'source_question_id'=b.question_id AND NOT (assets ? 'release_hold_reason');
  SELECT * INTO k FROM public.question_keys WHERE question_id=q.id;
  IF q.id IS NULL OR k.explanation IS NULL OR q.assets->>'answer_review'<>'2026-09-29-independent-solution-and-source-check' THEN RAISE EXCEPTION 'Unverified pay record %',b.question_id;END IF;
  INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES('staged_pay_sync_20260929','question_bank',b.question_id,jsonb_build_object('before',to_jsonb(b),'live_question_id',q.id));
  UPDATE public.question_bank SET stem_text=q.stem,choices=(SELECT jsonb_object_agg(x->>'key',x->>'text') FROM jsonb_array_elements(q.choices)x),answer_key=k.correct#>>'{}',answer_explanation=k.explanation,answer_key_status='independently_verified_20260929',needs_review=false,review_reasons=jsonb_build_array('Rechecked 2026-09-29: explicit whole-day versus overtime-only pay rule; see verified canonical live question.') WHERE question_id=b.question_id;
 END LOOP;
 FOR b IN SELECT * FROM public.question_bank WHERE needs_review AND publication_status='duplicate' AND source_id='est2_hs_level1_jan_2026' FOR UPDATE LOOP
  cid=coalesce(substring(b.review_reasons::text from 'canonical source: ([a-z0-9_-]+)'),substring(b.review_reasons::text from 'Canonical record: ([a-z0-9_-]+)'));
  SELECT * INTO c FROM public.question_bank WHERE question_id=cid;
  IF c.question_id IS NULL OR c.publication_status<>'published' OR c.answer_key IS NULL OR coalesce(c.answer_explanation,'')='' THEN RAISE EXCEPTION 'Missing verified canonical % -> %',b.question_id,cid; END IF;
  IF b.answer_key IS DISTINCT FROM c.answer_key AND b.question_id<>'est2_hs_level1_jan_2026-q00337' THEN RAISE EXCEPTION 'Unexpected duplicate key conflict %',b.question_id;END IF;
  IF NOT EXISTS(SELECT 1 FROM public.questions qq JOIN public.question_keys kk ON kk.question_id=qq.id WHERE qq.assets->>'source_question_id'=cid AND (NOT (qq.assets ? 'release_hold_reason') OR qq.assets->>'release_hold_reason' ILIKE 'Duplicate%') AND kk.correct=to_jsonb(c.answer_key)) THEN RAISE EXCEPTION 'Canonical not linked to scored or verified duplicate record %',cid; END IF;
  INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES('staged_duplicate_recheck_20260929','question_bank',b.question_id,jsonb_build_object('before',to_jsonb(b),'canonical',cid));
  UPDATE public.question_bank SET needs_review=false,answer_key=c.answer_key,answer_explanation=c.answer_explanation,answer_key_status='verified_duplicate_rechecked_20260929',review_reasons=coalesce(review_reasons,'[]'::jsonb)||jsonb_build_array('Rechecked 2026-09-29: existing source identity evidence and independently worked canonical answer reconciled with the live key. Duplicate remains unpublished. Canonical: '||cid) WHERE question_id=b.question_id;
  n=n+1;
 END LOOP;
 IF n NOT IN (0,120) THEN RAISE EXCEPTION 'Unexpected duplicate count %',n;END IF;
 FOR b IN SELECT * FROM public.question_bank WHERE needs_review AND publication_status='excluded' AND source_id='est2_hs_level1_jan_2026' AND answer_key_status='not_a_question; source_answer_key_fragment' FOR UPDATE LOOP
  IF b.stem_text !~ 'ANS:.*PTS:' THEN RAISE EXCEPTION 'Unexpected answer fragment %',b.question_id;END IF;
  INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES('staged_fragment_review_20260929','question_bank',b.question_id,jsonb_build_object('before',to_jsonb(b)));
  UPDATE public.question_bank SET needs_review=false,answer_key_status='reviewed_not_a_question_20260929',review_reasons=review_reasons||jsonb_build_array('Rechecked 2026-09-29: answer-key/points fragment, not a student question. Exclusion confirmed.') WHERE question_id=b.question_id;
 END LOOP;
 FOR b IN SELECT * FROM public.question_bank WHERE needs_review AND publication_status='duplicate' AND source_id='revision_2_march_2026' FOR UPDATE LOOP
  SELECT * INTO c FROM public.question_bank WHERE question_id<>b.question_id AND source_id='revision_2_june_2026_a' AND publication_status='excluded' AND regexp_replace(stem_text,'\s+',' ','g')=regexp_replace(b.stem_text,'\s+',' ','g');
  IF c.question_id IS NULL THEN RAISE EXCEPTION 'No exact excluded OCR duplicate %',b.question_id;END IF;
  INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES('staged_ocr_duplicate_review_20260929','question_bank',b.question_id,jsonb_build_object('before',to_jsonb(b),'canonical',c.question_id));
  UPDATE public.question_bank SET needs_review=false,answer_key_status='exact_duplicate_of_excluded_ocr_20260929',answer_explanation=CASE WHEN b.question_id='revision_2_march_2026-p22-q25' THEN 'Complete original page 468 and verified HOA 195 give 3·6=6x+9, hence x=1.5. Use canonical live question 29b98515-a63e-50cb-b70a-638b1de4ad32; do not release this malformed OCR copy.' WHEN b.question_id='revision_2_march_2026-p23-q28' THEN 'Ahmed types 125 words/minute; Malak types 250 words/minute. In 3.5 minutes Malak types 875 words. Already represented by the verified live typing question; do not release this OCR duplicate.' ELSE 'Exact duplicate of excluded OCR record '||c.question_id||'. Mixed or incomplete source extraction remains excluded; no answer verification is asserted for the missing material.' END,review_reasons=review_reasons||jsonb_build_array('Rechecked 2026-09-29: exact normalized-text match to excluded record '||c.question_id||'. Duplicate identity resolved; not released as a question.') WHERE question_id=b.question_id;
 END LOOP;
END;$review$;
-- Repair already-established duplicate pointers now that their canonical source is available.
DO $links$
DECLARE r record;b public.est_source_review%rowtype;
BEGIN
 FOR r IN SELECT s.id,t.id target_id,t.question_id FROM public.est_source_review s JOIN public.est_source_review t ON (t.id=s.duplicate_of OR t.source_code=s.duplicate_of) AND t.track_id=s.track_id WHERE s.review_status='duplicate' AND s.question_id IS NULL AND t.review_status='ready' LOOP
  SELECT * INTO b FROM public.est_source_review WHERE id=r.id FOR UPDATE;
  IF b.question_id IS NOT NULL THEN CONTINUE; END IF;
  INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES('source_duplicate_link_20260929','source_review',b.id,jsonb_build_object('before',to_jsonb(b),'canonical_source',r.target_id));
  UPDATE public.est_source_review SET question_id=r.question_id,duplicate_of=r.target_id,updated_at=now(),review_note=coalesce(review_note,'')||E'\n2026-09-29: linked established duplicate to its verified canonical source '||r.target_id WHERE id=b.id;
 END LOOP;
END;$links$;
SELECT action,count(*) FROM public.audit_log WHERE action IN ('staged_pay_sync_20260929','staged_duplicate_recheck_20260929','staged_fragment_review_20260929','staged_ocr_duplicate_review_20260929','source_duplicate_link_20260929') GROUP BY action;
