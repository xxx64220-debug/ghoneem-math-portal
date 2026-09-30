-- Read-only audit of the original catalogue, reconstructed from retained rows.
-- Explicit exclusions are exact track/lesson/idea/difficulty/collection slices.
-- Never filter the intended catalogue to ready rows before measuring losses.
do $coverage$
begin
 if exists (
  with intended as (
   select q.track_id track,r.lesson,lower(trim(r.idea)) idea,r.difficulty,
    c.collection
   from revision_items r join questions q on q.id=r.question_id
   cross join lateral (
    select 'all'::text collection union
    select jsonb_array_elements_text(r.focus->'collections')
   ) c
  ), retained as (
   select q.track_id track,r.lesson,lower(trim(r.idea)) idea,r.difficulty,
    c.collection
   from revision_items r join questions q on q.id=r.question_id
   cross join lateral (
    select 'all'::text collection union
    select jsonb_array_elements_text(r.focus->'collections')
   ) c where r.active
  ), excluded(track,lesson,idea,difficulty,collection) as (
   values
    ('est','Inequalities and absolute value','optimising a linear expression','hard','all'),
    ('est','Inequalities and absolute value','optimising a linear expression','hard','unique'),
    ('est','Quadratics and polynomials','reading a parabola graph','medium','all'),
    ('est','Probability and conditional probability','union and overlapping events','medium','all'),
    ('est2','Quadratics and polynomials','common polynomial factor','hard','all'),
    ('est2','Quadratics and polynomials','common polynomial factor','hard','unique')
  )
  select * from intended except select * from retained except select * from excluded
 ) then raise exception 'An intended Final Revision slice disappeared without an explicit exclusion'; end if;

 -- An exclusion never grants permission to discard a ready candidate.
 if exists (
  select 1 from revision_items r join questions q on q.id=r.question_id
  join question_keys k on k.question_id=q.id
  where not r.active
   and nullif(q.assets->>'release_hold_reason','') is null
   and r.fingerprint=revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)
   and not exists (
    select 1 from revision_items a join questions aq on aq.id=a.question_id
    where a.active and aq.track_id=q.track_id and a.lesson=r.lesson
     and lower(trim(a.idea))=lower(trim(r.idea)) and a.difficulty=r.difficulty
   )
 ) then raise exception 'A ready Final Revision idea lost every representative'; end if;
end $coverage$;
