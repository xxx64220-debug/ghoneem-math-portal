-- Make the school-sample questions self-contained in every renderer and export.
-- Portal exam: EST I-HS Math — May 2026 (user described May 2025, Q37–38).
-- Exact match is source M036/M037; retain all IDs, choices, keys and release holds.
BEGIN;
UPDATE questions
SET stem='A school has 2,400 students. A random sample of 100 students is chosen. In this sample, 4 students are in their final year, 20 students are aged between 10 and 12 years, and the remaining students are in kindergarten.' || E'\n\n' || stem,
    assets=(assets-'html'-'figure_type'-'figure_count'-'figure_caption'-'figure_source') ||
      jsonb_build_object('shared_stimulus_html',assets->>'html',
       'shared_stimulus_in_stem',true,
       'display_repair','2026-09-26-shared-school-sample-context',
       'display_repair_provenance','Context copied verbatim in meaning from the already stored, reviewed shared stimulus; original PDF not reverified.')
WHERE track_id='est'
  AND assets->>'session'='May 2026'
  AND assets->>'question_number' IN ('36','37')
  AND assets->>'html'='<p>A school has 2,400 students. A random sample of 100 students is chosen. In this sample:</p><ul><li>4 students are in their final year.</li><li>20 students are aged between 10 and 12 years.</li><li>The remaining students are in kindergarten.</li></ul>'
  AND coalesce(assets->>'shared_stimulus_in_stem','false')<>'true';
COMMIT;
SELECT q.id,q.assets->>'question_number' AS source_question,q.stem,k.correct,
 q.assets->>'release_hold_reason' AS existing_hold
FROM questions q LEFT JOIN question_keys k ON k.question_id=q.id
WHERE q.assets->>'display_repair'='2026-09-26-shared-school-sample-context'
ORDER BY source_question,q.id;
