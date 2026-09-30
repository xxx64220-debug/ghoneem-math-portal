-- Read-only contract for this review's intended exact coverage.
do $$ begin
 if exists(
  with expected(id,lesson,idea,difficulty,collection) as(values
   ('afee4921-ee14-551e-abe7-c86f4f3acb45'::uuid,'Inequalities and absolute value','Optimising a linear expression','hard','unique'),
   ('b515a6ed-1c6f-5848-b2b4-12c02a5d4524'::uuid,'Quadratics and polynomials','Reading a parabola graph','medium','all'),
   ('4e5d0e24-836e-5e18-85af-6868807dc27e'::uuid,'Probability and conditional probability','Union and overlapping events','medium','all'),
   ('97a4e8db-e914-5a56-a4c6-f3b6efe36600'::uuid,'Systems of equations','No-solution conditions','medium','must_know'))
  select 1 from expected e left join revision_items r on r.question_id=e.id
  left join questions q on q.id=e.id left join question_keys k on k.question_id=e.id
  where r.question_id is null or not r.active or q.track_id<>'est'
   or r.lesson<>e.lesson or r.idea<>e.idea or r.difficulty<>e.difficulty
   or nullif(q.assets->>'release_hold_reason','') is not null
   or r.fingerprint<>revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)
   or not(r.programmes @> array['est'])
   or (e.collection<>'all' and not(r.focus->'collections' ? e.collection))
 ) then raise exception 'Reviewed intended Final Revision coverage disappeared';end if;
 if exists(select 1 from revision_items r join questions q on q.id=r.question_id
  where r.active group by q.track_id,r.lesson,lower(trim(r.idea)),r.difficulty having count(*)>2)
 then raise exception 'Representative cap violated';end if;
 if exists(select 1 from questions q where q.id in
  ('25341cd9-57d3-529c-bd83-36eae2d1f3a7','be507dd8-d608-59a3-970e-10e05284131b',
   'd734bf83-7cbd-5bd2-b857-db3656c5018d','c5b39981-f58c-5d56-b5b2-79f1702ad1da',
   'fa4af000-7c2b-5a7c-a0f2-222016a9d1e9')
  and nullif(q.assets->>'release_hold_reason','') is null)
 then raise exception 'Documented defective source exclusion was removed';end if;
end $$;
