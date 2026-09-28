-- Protect the active exam copy; use the corrected canonical question for future selection.
DO $closeout$
DECLARE q public.questions%rowtype;r public.portal_reports%rowtype;v jsonb;
BEGIN
 SELECT * INTO q FROM public.questions WHERE id='3556fa31-7c75-76db-d8d7-9ee22d7c3867' FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.audit_log WHERE action='active_copy_superseded_20260928' AND target_id=q.id::text) THEN
  IF NOT EXISTS(SELECT 1 FROM public.questions x JOIN public.question_keys k ON k.question_id=x.id WHERE x.id='10fab705-da9f-6719-ec0d-3297d5afae40' AND x.assets->>'answer_review'='2026-09-28-independent-solution-and-source-check' AND k.correct='"B"'::jsonb) THEN RAISE EXCEPTION 'Canonical repaired question unavailable'; END IF;
  INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES('active_copy_superseded_20260928','question',q.id::text,jsonb_build_object('before_assets',q.assets,'reason','Content and grading preserved for active exam; corrected canonical version used for future selection'));
  UPDATE public.questions SET assets=assets||jsonb_build_object('release_hold_reason','Duplicate of reviewed question 10fab705-da9f-6719-ec0d-3297d5afae40; old content retained for active exam','duplicate_of','10fab705-da9f-6719-ec0d-3297d5afae40','recheck_date','2026-09-28','recheck_outcome','superseded_active_copy') WHERE id=q.id;
 END IF;
 FOR v IN SELECT value FROM jsonb_array_elements($reports$[
  {"id":"a7c547aa-6cd2-4bba-a613-54766ec6c3c2","question":"771d0c68-8e92-24d9-1c4e-0e63488b4176","key":"C","status":"resolved","note":"Verified 2026-09-28: restored circle-and-tangent SVG and full shared setup for daily Q33. Similar triangles give OA/OE = OH/OB = 1.6/4, so OE = 10 cm, choice C. Cleaned options and topic."},
  {"id":"5e23d822-9dfb-429c-b658-cfc62a4f8893","question":"771d0c68-8e92-24d9-1c4e-0e63488b4176","key":"C","status":"resolved","note":"Verified 2026-09-28: missing shared question context and figure restored. OE = 10 cm (C), with the similar-triangle explanation included."},
  {"id":"95f63adc-ba78-4b38-8dbb-20411d791909","question":"10fab705-da9f-6719-ec0d-3297d5afae40","key":"B","status":"resolved","note":"Verified source page 48 and independent solution: restored 3^(x+2) − 3^x = 216. Factoring gives 8·3^x = 216, hence x = 3 (B). Full worked explanation now stored."},
  {"id":"0f8191f5-ceaf-4759-b136-10ff757e6ca6","question":"5cf35d24-e7fb-5083-17c9-e7dc4697a9de","key":"C","status":"resolved","note":"Original January 2026 page 8 checked: restored all five fraction-formatted choices and removed footer contamination. Solving |7−4x| > 3x+1 gives x < 6/7 or x > 8 (C)."},
  {"id":"a756f254-5446-408f-96a4-9579462130c3","question":"f0fdb1f5-7e1f-5a4d-859b-80c47e1c9f48","key":"C","status":"dismissed","note":"The message is praise rather than a defect report. The diagram and answer were nevertheless independently checked: y = x + z, so x = y − z (C)."},
  {"id":"e2bb04af-a3bb-4253-b3a6-d35d1af2b938","question":"4e5d0e24-836e-5e18-85af-6868807dc27e","key":"D","status":"resolved","note":"Source page 37 DAP 049 and solution independently verified. Count multiples using 25 + 10 − 5 = 30; probability is 30/50 = 0.60. The question asks for half this probability, giving 0.30 (D). Expanded explanation to show the overlap and final halving."}
 ]$reports$::jsonb) LOOP
  SELECT * INTO r FROM public.portal_reports WHERE id=(v->>'id')::uuid FOR UPDATE;
  IF r.status NOT IN ('open','in_review') THEN CONTINUE; END IF;
  IF r.question_id IS DISTINCT FROM (v->>'question')::uuid OR NOT EXISTS(SELECT 1 FROM public.question_keys WHERE question_id=r.question_id AND correct=to_jsonb(v->>'key') AND length(explanation)>60) THEN RAISE EXCEPTION 'Report verification mismatch %',r.id; END IF;
  IF r.question_id='771d0c68-8e92-24d9-1c4e-0e63488b4176' AND NOT EXISTS(SELECT 1 FROM public.questions WHERE id=r.question_id AND length(assets->>'svg')>300 AND stem LIKE '%OH = 1.6%') THEN RAISE EXCEPTION 'Missing daily diagram'; END IF;
  INSERT INTO public.audit_log(action,target_type,target_id,meta) VALUES('portal_report_review_20260928','portal_report',r.id::text,jsonb_build_object('before',to_jsonb(r),'verification',v));
  UPDATE public.portal_reports SET status=v->>'status',staff_note=v->>'note',updated_at=now() WHERE id=r.id;
 END LOOP;
END;$closeout$;
SELECT status,count(*) FROM public.portal_reports GROUP BY status ORDER BY status;
