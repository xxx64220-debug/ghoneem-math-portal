begin;
set local lock_timeout='5s';
do $recovery$
declare p jsonb;q questions%rowtype;k question_keys%rowtype;e exams%rowtype;new_id uuid;h text;attempt_snapshot jsonb;answer_snapshot jsonb;result_snapshot jsonb; affected uuid[];
begin
 perform pg_advisory_xact_lock(hashtextextended('source_recovery_20261004',0));
 if exists(select 1 from audit_log where action='question.source_recovery_20261004') then raise exception 'Source recovery already applied'; end if;
 affected:=array['4ab54efe-2260-eeb3-dbf2-9909db0b4845','a62bb4f1-6a6d-46af-b5d3-72929458bc2b','f30234c6-7d80-1640-054d-97b86fde38ad']::uuid[];
 -- Locks prevent a new attempt or concurrent grading while history is checked.
 perform 1 from exams where question_ids && affected for update;
 perform 1 from attempts where exam_id in(select id from exams where question_ids && affected) for update;
 if exists(select 1 from attempts where exam_id in(select id from exams where question_ids && affected) and status='in_progress') then raise exception 'Affected exam has an active attempt; retry after completion'; end if;
 select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]') into attempt_snapshot from attempts a where exam_id in(select id from exams where question_ids && affected);
 select coalesce(jsonb_agg(to_jsonb(a) order by a.attempt_id,a.question_id),'[]') into answer_snapshot from attempt_answers a where attempt_id in(select id from attempts where exam_id in(select id from exams where question_ids && affected));
 select coalesce(jsonb_agg(to_jsonb(a) order by a.attempt_id,a.question_id),'[]') into result_snapshot from attempt_results a where attempt_id in(select id from attempts where exam_id in(select id from exams where question_ids && affected));
 for p in select value from jsonb_array_elements('[{"id":"4ab54efe-2260-eeb3-dbf2-9909db0b4845","track_id":"sat","before_hash":"2d3e7997a62ffcd683f5ea936b44b6fa","correct":"A","asset_patch":{"source_recovery_release":"20261004","verified_release":"20261004-source-recovery","figure_caption":"Original graph choices A–D from College Panda Test 1, section 4, Q3, page 11.","figure":"https://math.portal.ghoneem.com/assets/question-figures/maya-choice-graphs-20261004.png","source_image_sha256":"31b16c1ca897b52a0edee0f2ff6e12555b5cd6fa520ff9e2a57b2d23a81c079a"},"choices":[{"key":"A","text":"Graph A in the figure"},{"key":"B","text":"Graph B in the figure"},{"key":"C","text":"Graph C in the figure"},{"key":"D","text":"Graph D in the figure"}],"explanation":"A. Distance from home starts at 0, increases during the drive to the bookstore, remains constant for the several hours spent there, and returns to 0 on the drive home. Original graph A has all four features. B ends farther from home, C starts away from home, and D has no horizontal interval for the stop.","expected_hold":"20261004: Required graph choices are only referenced by an unrendered source PDF pointer. Recover and attach the original graph choices."},{"id":"a62bb4f1-6a6d-46af-b5d3-72929458bc2b","track_id":"sat","before_hash":"dfc3fd5f37c116ec5426491f4b80842f","correct":"A","asset_patch":{"source_recovery_release":"20261004","verified_release":"20261004-source-recovery","source_page":14,"source_drive_id":"1sO50D2SCGnRzldtlNqXsdYuo9eVn1zkS","figure_caption":"Authentic soft-drinks scatterplot from MSET006 Q49, page 14; choices continue on page 15 and key is on page 16.","figure":"https://math.portal.ghoneem.com/assets/question-figures/mset006-q49-20261004.png","source_image_sha256":"5fedca2f8fe381df0328e939d524b8087f1eebe513cf7d37fa80a4d4725ed800"},"explanation":"A. The original scatterplot decreases from about 455 thousand gallons at year 1 to a minimum near years 7–10, then rises to about 423 at year 16. This requires positive quadratic curvature and a positive intercept. Only A has both. Its vertex occurs at x = 38.44/(2×2.138) ≈ 8.99 with y ≈ 310.49; it predicts y(1) ≈ 446.97 and y(16) ≈ 415.56, consistent with the plotted trend. B and C predict negative initial values, and D curves downward and decreases for x ≥ 0. Independently verified; the printed MSET006 key also marks Q49 A.","expected_hold":"20261004: Required soft-drinks scatterplot is absent. Recover the source graph before certifying the model/key."},{"id":"f30234c6-7d80-1640-054d-97b86fde38ad","track_id":"est","before_hash":"43c9be1ba63e89c7e6dfef325582948a","correct":"D","asset_patch":{"source_recovery_release":"20261004","verified_release":"20261004-source-recovery"},"choices":[{"key":"A","text":"29"},{"key":"B","text":"$\\sqrt{29}$"},{"key":"C","text":"$\\sqrt{40}$"},{"key":"D","text":"$\\sqrt{41}$"}],"explanation":"D. The original December 2025 EST I Q8 choices are A: 29, B: √29, C: √40, D: √41. The horizontal difference is 3 − (−1) = 4 and the vertical difference is 7 − 2 = 5. Therefore AB = √(4² + 5²) = √41. The import omitted the radical signs; the answer letter D is unchanged.","expected_hold":"20261004: No correct stored distance option. Points (3,7) and (−1,2) have distance √41; stored options29,29,40,41 omit it. Original source required before repair."}]'::jsonb) loop
  select * into q from questions where id=(p->>'id')::uuid for update;
  select * into k from question_keys where question_id=q.id for update;
  if q.id is null or q.track_id is distinct from p->>'track_id' or k.correct is distinct from p->'correct'
   or (q.assets ? 'release_hold_reason' and q.assets->>'release_hold_reason' is distinct from p->>'expected_hold')
   or md5(jsonb_build_array(q.stem,q.choices,q.assets-'release_hold_reason',k.correct,k.explanation)::text) is distinct from p->>'before_hash'
  then raise exception 'Concurrent content change: %',p->>'id'; end if;
  update questions set choices=coalesce(p->'choices',choices),assets=(assets-'release_hold_reason')||(p->'asset_patch') where id=q.id;
  update question_keys set explanation=p->>'explanation' where question_id=q.id;
  select md5(jsonb_build_array(q2.stem,q2.choices,q2.assets,k2.correct,k2.explanation)::text) into h from questions q2 join question_keys k2 on k2.question_id=q2.id where q2.id=q.id;
  -- Do not reactivate any curated revision membership as a side effect.
  update revision_items r set fingerprint=revision_question_fingerprint(q2.stem,q2.choices,q2.assets,k2.correct,k2.explanation)
   from questions q2 join question_keys k2 on k2.question_id=q2.id where r.question_id=q2.id and q2.id=q.id;
  insert into audit_log(action,target_type,target_id,meta) values('question.source_recovery_20261004','question',q.id::text,
   jsonb_build_object('before_choices',q.choices,'before_assets',q.assets,'before_explanation',k.explanation,'correct',k.correct,'after_hash',h,'track_id',q.track_id));
 end loop;
 for e in select * from exams where is_published and question_ids && affected order by id for update loop
  -- Lock every sibling question/key before accepting a clean replacement.
  perform 1 from questions where id=any(e.question_ids) for share;
  perform 1 from question_keys where question_id=any(e.question_ids) for share;
  if cardinality(e.question_ids) not between 1 and 200 or (select count(distinct x) from unnest(e.question_ids) x)<>cardinality(e.question_ids)
   or (select count(*) from questions q2 join question_keys k2 on k2.question_id=q2.id where q2.id=any(e.question_ids))<>cardinality(e.question_ids)
   or exists(select 1 from questions q2 join question_keys k2 on k2.question_id=q2.id where q2.id=any(e.question_ids) and (
    q2.track_id<>e.track_id or nullif(btrim(q2.stem),'') is null or nullif(btrim(k2.explanation),'') is null
    or nullif(btrim(q2.assets->>'release_hold_reason'),'') is not null or coalesce(q2.assets->>'bank_removed','false')='true' or coalesce(k2.correct->>'void','false')='true'
    or (q2.type='mcq' and (jsonb_typeof(q2.choices)<>'array' or not exists(select 1 from jsonb_array_elements(q2.choices) c where c->>'key'=k2.correct#>>'{}')))))
  then raise exception 'Replacement exam has incomplete or held sibling content: %',e.id; end if;
  new_id:=gen_random_uuid();
  insert into exams(id,track_id,title,duration_seconds,question_ids,shuffle,review_policy,max_attempts,is_published,is_full_length,scoring_map,assessment_type,exam_set_code,module_number,module_count)
   values(new_id,e.track_id,e.title||' — Source-corrected v2 (Oct 2026)',e.duration_seconds,e.question_ids,e.shuffle,e.review_policy,e.max_attempts,true,e.is_full_length,e.scoring_map,e.assessment_type,e.exam_set_code,e.module_number,e.module_count);
  insert into assignments(exam_id,group_id,user_id,open_at,close_at) select new_id,group_id,user_id,open_at,close_at from assignments where exam_id=e.id;
  update exams set is_published=false where id=e.id;
  insert into audit_log(action,target_type,target_id,meta) values('exam.source_recovery_20261004','exam',new_id::text,jsonb_build_object('original_exam',to_jsonb(e),'replacement_exam_id',new_id));
 end loop;
 if attempt_snapshot is distinct from(select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]') from attempts a where exam_id in(select id from exams where question_ids && affected))
  or answer_snapshot is distinct from(select coalesce(jsonb_agg(to_jsonb(a) order by a.attempt_id,a.question_id),'[]') from attempt_answers a where attempt_id in(select id from attempts where exam_id in(select id from exams where question_ids && affected)))
  or result_snapshot is distinct from(select coalesce(jsonb_agg(to_jsonb(a) order by a.attempt_id,a.question_id),'[]') from attempt_results a where attempt_id in(select id from attempts where exam_id in(select id from exams where question_ids && affected)))
 then raise exception 'Historical attempt, answer or score changed'; end if;
end $recovery$;
commit;
