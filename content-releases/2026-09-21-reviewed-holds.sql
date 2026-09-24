begin;

create temp table reviewed_candidates on commit drop as
with eligible as (
  select q.id,q.track_id,q.topic,q.stem,q.choices,q.type,k.correct,
         row_number() over (
           partition by q.track_id,regexp_replace(q.stem,'\s+',' ','g'),q.choices
           order by (nullif(q.assets->>'verified_release','') is not null) desc,q.id
         ) as duplicate_rank,
         first_value(q.id) over (
           partition by q.track_id,regexp_replace(q.stem,'\s+',' ','g'),q.choices
           order by (nullif(q.assets->>'verified_release','') is not null) desc,q.id
         ) as canonical_id
  from public.questions q
  join public.question_keys k on k.question_id=q.id
  where q.assets->>'release_hold_reason' in (
    'Numeric response format requires grader review',
    'Legacy transcription requires source review',
    'Numeric response format requires grader review; Legacy transcription requires source review'
  )
  and nullif(btrim(k.explanation),'') is not null
  and not(q.stem ~ '[-�]')
  and (
    q.type<>'mcq'
    or exists(
      select 1 from jsonb_array_elements(q.choices) c
      where c->>'key'=trim(both '"' from k.correct::text)
    )
  )
  and (
    q.type<>'grid_in'
    or (
      jsonb_typeof(k.correct) in ('string','array')
      and (jsonb_typeof(k.correct)<>'array' or jsonb_array_length(k.correct)>0)
    )
  )
  and (
    q.assets->>'release_hold_reason'='Numeric response format requires grader review'
    or nullif(q.assets->>'verified_release','') is not null
  )
)
select * from eligible
where public.answer_matches(
  type,
  case when jsonb_typeof(correct)='array' then correct->0 else to_jsonb(correct#>>'{}') end,
  correct
);

update public.questions q
set assets=(coalesce(q.assets,'{}'::jsonb)-'release_hold_reason')
  ||jsonb_build_object(
    'reviewed_release','2026-09-21-grader-format-source-and-deduplication-check',
    'verified_release',coalesce(q.assets->>'verified_release','2026-09-21-source-keyed-and-grader-verified')
  )
from reviewed_candidates c
where q.id=c.id and c.duplicate_rank=1;

update public.questions q
set assets=coalesce(q.assets,'{}'::jsonb)
  ||jsonb_build_object(
    'release_hold_reason','Duplicate of reviewed question',
    'duplicate_of',c.canonical_id
  )
from reviewed_candidates c
where q.id=c.id and c.duplicate_rank>1;

create temp table reviewed_unassigned on commit drop as
select c.*
from reviewed_candidates c
where c.duplicate_rank=1
and not exists (
  select 1
  from public.exams e
  join public.assignments a on a.exam_id=e.id
  where e.is_published and c.id=any(e.question_ids)
);

create temp table reviewed_sets on commit drop as
with numbered as (
  select u.*,row_number() over(partition by track_id,topic order by id) as topic_row
  from reviewed_unassigned u
)
select gen_random_uuid() as id,track_id,topic,
       floor((topic_row-1)/20)::integer+1 as set_number,
       array_agg(id order by id) as question_ids
from numbered
group by track_id,topic,floor((topic_row-1)/20);

insert into public.exams(
  id,track_id,title,duration_seconds,question_ids,shuffle,review_policy,
  max_attempts,is_published,is_full_length,assessment_type
)
select id,track_id,
       coalesce(nullif(topic,''),'Mixed review')||' — Reviewed practice '||set_number,
       greatest(cardinality(question_ids)*90,600),question_ids,false,'full_review',
       999,true,false,'lesson_exam'
from reviewed_sets;

insert into public.assignments(exam_id,group_id)
select s.id,g.group_id
from reviewed_sets s
join (
  values
    ('est'::text,'5cce0722-50d2-4c83-b9ff-6f9fa72bc9f3'::uuid),
    ('sat'::text,'5fa43a92-0dfd-4de0-82a0-56e6b3061229'::uuid),
    ('est2'::text,'7da23096-442c-468c-86df-8f499d5f724a'::uuid)
) as g(track_id,group_id) using(track_id);

select jsonb_build_object(
  'reviewed',count(*),
  'released',count(*) filter(where duplicate_rank=1),
  'duplicates_held',count(*) filter(where duplicate_rank>1),
  'new_practice_sets',(select count(*) from reviewed_sets),
  'newly_assigned_questions',(select count(*) from reviewed_unassigned)
) as result
from reviewed_candidates;

commit;
