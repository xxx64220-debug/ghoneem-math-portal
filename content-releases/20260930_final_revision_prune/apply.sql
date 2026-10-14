begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
select pg_advisory_xact_lock(hashtext('revision.final_revision_representatives.20260930'));
lock table public.revision_items in share row exclusive mode;
lock table public.questions, public.question_keys in share mode;
lock table public.audit_log in row exclusive mode;

do $preflight$
declare
 v_state text;
begin
 if exists(
  select 1 from public.audit_log
  where action='revision.final_revision_representatives.20260930'
 ) then raise exception 'Final Revision representative release already applied; do not rerun'; end if;

 if (select count(*) from public.revision_items)<>2427
    or (select count(*) from public.revision_items where active)<>2427
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1341
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>496
    or (select count(distinct (r.lesson,lower(trim(r.idea)))) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>326
    or (select count(distinct (r.lesson,lower(trim(r.idea)))) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>300
    or (select count(distinct (r.lesson,lower(trim(r.idea)))) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>368
    or exists(
      select 1 from public.revision_items r join public.questions q on q.id=r.question_id
      where q.track_id not in ('sat','est','est2')
    ) then
  raise exception 'Final Revision catalogue baseline changed; re-audit before pruning';
 end if;

 select md5(string_agg(
   q.track_id||'|'||r.question_id::text||'|'||r.lesson||'|'||r.idea||'|'||
   r.difficulty||'|'||r.programmes::text||'|'||r.fingerprint||'|'||
   r.active::text||'|'||r.focus::text,
   ';' order by r.question_id
 )) into v_state
 from public.revision_items r
 join public.questions q on q.id=r.question_id
 where r.active;
 if v_state<>'e7baafb3a3ce792eb2f7401ea4efba1b' then
  raise exception 'Final Revision active metadata fingerprint changed; re-audit before pruning';
 end if;
end $preflight$;

create temporary table final_revision_prune_snapshot on commit drop as
with base as (
 select
  q.track_id as track,
  r.question_id,
  r.lesson,
  r.idea,
  r.difficulty,
  r.programmes,
  r.fingerprint,
  r.focus,
  coalesce(r.focus->'collections','[]'::jsonb) as collections,
  nullif(r.focus->>'takeaway','') as takeaway,
  (
   nullif(q.assets->>'release_hold_reason','') is null
   and r.fingerprint=public.revision_question_fingerprint(
    q.stem,q.choices,q.assets,k.correct,k.explanation
   )
  ) as ready
 from public.revision_items r
 join public.questions q on q.id=r.question_id
 join public.question_keys k on k.question_id=q.id
 where r.active
)
select b.*,
 row_number() over(
  partition by track,lesson,lower(trim(idea)),difficulty
  order by
   ready desc,
   case when jsonb_typeof(collections)='array' then jsonb_array_length(collections) else 0 end desc,
   (collections ? 'unique') desc,
   (collections ? 'must_know') desc,
   (collections ? 'repeated') desc,
   (takeaway is not null and takeaway !~* '^(Key skill:|Review this source question)') desc,
   question_id
 ) as representative_rank
from base b;

do $snapshot_checks$
begin
 if (select count(*) from final_revision_prune_snapshot)<>2427
    or (select count(*) from final_revision_prune_snapshot where ready)<>2414
    or (select count(*) from final_revision_prune_snapshot where not ready)<>13
    or exists(select 1 from final_revision_prune_snapshot where jsonb_typeof(collections)<>'array')
 then raise exception 'Final Revision source fingerprints or focus metadata changed'; end if;
end $snapshot_checks$;

create temporary table final_revision_collection_before on commit drop as
select distinct
 s.track,s.lesson,lower(trim(s.idea)) as idea_key,s.difficulty,c.value#>>'{}' as collection
from final_revision_prune_snapshot s
cross join lateral jsonb_array_elements(s.collections) c
where s.ready;

create temporary table final_revision_protected_before on commit drop as
select 'questions'::text object_name,count(*)::bigint row_count,
 md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) digest from public.questions t
union all select 'question_keys',count(*)::bigint,
 md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.question_keys t
union all select 'exams',count(*)::bigint,
 md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.exams t
union all select 'revision_sessions',count(*)::bigint,
 md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.revision_sessions t
union all select 'attempts',count(*)::bigint,
 md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.attempts t
union all select 'attempt_answers',count(*)::bigint,
 md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.attempt_answers t
union all select 'attempt_results',count(*)::bigint,
 md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.attempt_results t
union all select 'daily_quizzes',count(*)::bigint,
 md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.daily_quizzes t
union all select 'daily_progress',count(*)::bigint,
 md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.daily_progress t
union all select 'practice_notebook',count(*)::bigint,
 md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.practice_notebook t;

create temporary table final_revision_metadata_before on commit drop as
select count(*)::bigint row_count,
 md5(string_agg(
  question_id::text||'|'||lesson||'|'||idea||'|'||difficulty||'|'||
  programmes::text||'|'||fingerprint||'|'||focus::text,
  ';' order by question_id
 )) digest
from public.revision_items;

update public.revision_items r
set active=false
from final_revision_prune_snapshot s
where r.question_id=s.question_id
 and (not s.ready or s.representative_rank>2);

do $updated_count$
begin
 if (select count(*) from public.revision_items where not active)<>1083
 then raise exception 'Final Revision deactivation count is incorrect'; end if;
end $updated_count$;

insert into public.audit_log(action,target_type,target_id,meta)
select
 'revision.final_revision_representatives.item.20260930',
 'question',
 s.question_id::text,
 jsonb_build_object(
  'track',s.track,
  'lesson',s.lesson,
  'idea',s.idea,
  'difficulty',s.difficulty,
  'fingerprint',s.fingerprint,
  'reason',case when not s.ready then 'source_not_ready' else 'representative_cap' end,
  'representative_rank',s.representative_rank,
  'cap_per_idea_difficulty',2,
  'reversible',true
 )
from final_revision_prune_snapshot s
where not s.ready or s.representative_rank>2;

do $postflight$
declare
 v_item_audits integer;
begin
 select count(*) into v_item_audits
 from public.audit_log
 where action='revision.final_revision_representatives.item.20260930';
 if v_item_audits<>1083 then raise exception 'Final Revision item audit is incomplete'; end if;

 if (select count(*) from public.revision_items)<>2427
    or (select count(*) from public.revision_items where active)<>1344
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where r.active and q.track_id='sat')<>456
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where r.active and q.track_id='est')<>438
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where r.active and q.track_id='est2')<>450
 then raise exception 'Final Revision post-release track counts are incorrect'; end if;

 if exists(
  select 1
  from (
   values
    ('sat'::text,20,326,84,294,78),
    ('est'::text,22,298,111,248,79),
    ('est2'::text,24,367,193,148,109)
  ) expected(track,lessons,ideas,easy,medium,hard)
  left join (
   select q.track_id track,
    count(distinct r.lesson)::int lessons,
    count(distinct (r.lesson,lower(trim(r.idea))))::int ideas,
    count(*) filter(where r.difficulty='easy')::int easy,
    count(*) filter(where r.difficulty='medium')::int medium,
    count(*) filter(where r.difficulty='hard')::int hard
   from public.revision_items r
   join public.questions q on q.id=r.question_id
   where r.active
   group by q.track_id
  ) actual using(track)
  where (actual.lessons,actual.ideas,actual.easy,actual.medium,actual.hard)
    is distinct from
    (expected.lessons,expected.ideas,expected.easy,expected.medium,expected.hard)
 ) then raise exception 'Final Revision lesson, idea, or difficulty coverage changed'; end if;

 if exists(
  select 1
  from public.revision_items r
  join public.questions q on q.id=r.question_id
  join public.question_keys k on k.question_id=q.id
  where r.active and (
   nullif(q.assets->>'release_hold_reason','') is not null
   or r.fingerprint<>public.revision_question_fingerprint(
    q.stem,q.choices,q.assets,k.correct,k.explanation
   )
  )
 ) then raise exception 'An active Final Revision row is not ready'; end if;

 if exists(
  select 1 from public.revision_items r
  join public.questions q on q.id=r.question_id
  where r.active
  group by q.track_id,r.lesson,lower(trim(r.idea)),r.difficulty
  having count(*)>2
 ) then raise exception 'The representative cap was not enforced'; end if;

 if exists(
  select b.* from final_revision_collection_before b
  except
  select distinct q.track_id,r.lesson,lower(trim(r.idea)),r.difficulty,c.value#>>'{}'
  from public.revision_items r
  join public.questions q on q.id=r.question_id
  cross join lateral jsonb_array_elements(coalesce(r.focus->'collections','[]'::jsonb)) c
  where r.active
 ) then raise exception 'A focused collection slice lost all representatives'; end if;

 if exists(
  select * from final_revision_metadata_before
  except
  select count(*)::bigint,
   md5(string_agg(
    question_id::text||'|'||lesson||'|'||idea||'|'||difficulty||'|'||
    programmes::text||'|'||fingerprint||'|'||focus::text,
    ';' order by question_id
   ))
  from public.revision_items
 ) then raise exception 'Revision metadata other than active was changed'; end if;

 if exists(
  select * from final_revision_protected_before
  except
  (
   select 'questions'::text,count(*)::bigint,md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.questions t
   union all select 'question_keys',count(*)::bigint,md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.question_keys t
   union all select 'exams',count(*)::bigint,md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.exams t
   union all select 'revision_sessions',count(*)::bigint,md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.revision_sessions t
   union all select 'attempts',count(*)::bigint,md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.attempts t
   union all select 'attempt_answers',count(*)::bigint,md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.attempt_answers t
   union all select 'attempt_results',count(*)::bigint,md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.attempt_results t
   union all select 'daily_quizzes',count(*)::bigint,md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.daily_quizzes t
   union all select 'daily_progress',count(*)::bigint,md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.daily_progress t
   union all select 'practice_notebook',count(*)::bigint,md5(string_agg(to_jsonb(t)::text,';' order by to_jsonb(t)::text)) from public.practice_notebook t
  )
 ) then raise exception 'Protected question, exam, session, or score data changed'; end if;
end $postflight$;

insert into public.audit_log(action,target_type,target_id,meta)
values (
 'revision.final_revision_representatives.20260930',
 'release',
 '20260930',
 jsonb_build_object(
  'rule','at most two ready questions per source track, lesson, normalized idea and difficulty',
  'before',jsonb_build_object('active',2427,'ready',2414),
  'after',jsonb_build_object('active',1344,'sat',456,'est',438,'est2',450),
  'deactivated',jsonb_build_object('representative_cap',1070,'source_not_ready',13),
  'collection_slice_loss',0,
  'classification_only',true,
  'new_answer_certification',false,
  'deleted_questions',0,
  'reversible',true
 )
);

commit;

select q.track_id,count(*) active,
 count(distinct (r.lesson,lower(trim(r.idea)))) ideas
from public.revision_items r
join public.questions q on q.id=r.question_id
where r.active
group by q.track_id
order by q.track_id;
