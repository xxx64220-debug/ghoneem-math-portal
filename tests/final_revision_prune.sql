begin;

do $test$
begin
 if (select count(*) from public.revision_items)<>2427
    or (select count(*) from public.revision_items where active)<>1344
    or (select count(*) from public.revision_items where not active)<>1083
 then raise exception 'representative catalogue totals are incorrect'; end if;

 if (select count(*) from public.audit_log where action='revision.final_revision_representatives.item.20260930')<>1083
    or (select count(*) from public.audit_log where action='revision.final_revision_representatives.20260930')<>1
 then raise exception 'representative release audit is incomplete'; end if;

 if exists(
  select 1 from public.revision_items r join public.questions q on q.id=r.question_id
  where r.active
  group by q.track_id,r.lesson,lower(trim(r.idea)),r.difficulty
  having count(*)>2
 ) then raise exception 'representative cap failed'; end if;

 if exists(
  select 1 from public.revision_items r
  join public.questions q on q.id=r.question_id
  join public.question_keys k on k.question_id=q.id
  where r.active and r.fingerprint<>public.revision_question_fingerprint(
   q.stem,q.choices,q.assets,k.correct,k.explanation
  )
 ) then raise exception 'a stale row remains active'; end if;

 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where r.active and q.track_id='sat')<>456
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where r.active and q.track_id='est')<>438
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where r.active and q.track_id='est2')<>450
 then raise exception 'track separation failed'; end if;

 if exists(
  select 1
  from (
   values
    ('sat'::text,20,326,84,294,78),
    ('est'::text,22,298,111,248,79),
    ('est2'::text,24,367,193,148,109)
  ) expected(track,lessons,ideas,easy,medium,hard)
  left join (
   select q.track_id track,count(distinct r.lesson)::int lessons,
    count(distinct (r.lesson,lower(trim(r.idea))))::int ideas,
    count(*) filter(where r.difficulty='easy')::int easy,
    count(*) filter(where r.difficulty='medium')::int medium,
    count(*) filter(where r.difficulty='hard')::int hard
   from public.revision_items r join public.questions q on q.id=r.question_id
   where r.active group by q.track_id
  ) actual using(track)
  where (actual.lessons,actual.ideas,actual.easy,actual.medium,actual.hard)
    is distinct from
    (expected.lessons,expected.ideas,expected.easy,expected.medium,expected.hard)
 ) then raise exception 'coverage distribution failed'; end if;
end $test$;

rollback;
