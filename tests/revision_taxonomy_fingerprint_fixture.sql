insert into public.tracks(id,name,is_active) values('est2','EST II',true) on conflict(id) do nothing;

with source as (
 select g,md5('revision-taxonomy-'||g)::uuid id,
  case when g<=1261 then 'sat' when g<=1791 then 'est' else 'est2' end track_id,
  jsonb_build_object('figure','https://example.test/figure-'||g||'.png','source_code','fixture-'||g) old_assets
 from generate_series(1,2207) g
)
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select id,track_id,'Legacy lesson','medium','mcq','Revision fingerprint fixture '||g,
 '[{"key":"A","text":"1"},{"key":"B","text":"2"},{"key":"C","text":"3"},{"key":"D","text":"4"}]'::jsonb,
 old_assets||jsonb_build_object('curriculum_lesson','Canonical lesson','lesson_subtopic','Detailed skill',
  'lesson_original_topic','Legacy lesson','lesson_taxonomy_version','20260929')
 ||case when g between 1262 and 1273 or g=1792 then jsonb_build_object('review_note','pre-existing uncatalogued edit') else '{}'::jsonb end
from source;

insert into public.question_keys(question_id,correct,explanation)
select id,'"A"'::jsonb,'Fixture explanation' from public.questions where stem like 'Revision fingerprint fixture %';

with source as (
 select g,md5('revision-taxonomy-'||g)::uuid id,
  case when g<=1261 then 'sat' when g<=1791 then 'est' else 'est2' end track_id,
  jsonb_build_object('figure','https://example.test/figure-'||g||'.png','source_code','fixture-'||g) old_assets
 from generate_series(1,2207) g
)
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint)
select id,'Canonical lesson','Detailed skill','medium',array[case when track_id='sat' then 'sat' else 'est' end],
 md5(jsonb_build_array('Revision fingerprint fixture '||g,
  '[{"key":"A","text":"1"},{"key":"B","text":"2"},{"key":"C","text":"3"},{"key":"D","text":"4"}]'::jsonb,
  old_assets,'"A"'::jsonb,'Fixture explanation')::text)
from source;

insert into public.audit_log(action,target_type,target_id,meta)
select 'question.lesson_taxonomy.20260929','question',md5('revision-taxonomy-'||g)::uuid::text,
 jsonb_build_object('old_curriculum_lesson',null,'old_lesson_subtopic',null,
  'old_lesson_original_topic',null,'old_lesson_taxonomy_version',null)
from generate_series(1,2207) g;
insert into public.audit_log(action,target_type,target_id,meta)
select 'question.lesson_taxonomy.20260929','question','fixture-extra-'||g,'{}'::jsonb
from generate_series(2208,6916) g;
insert into public.audit_log(action,target_type,target_id,meta)
select 'question.lesson_taxonomy_corrections.20260929','question',md5('revision-taxonomy-'||g)::uuid::text,'{}'::jsonb
from generate_series(1,13) g;

create or replace function public.portal_manage(p_actor uuid,p_action text,p_data jsonb default '{}')
returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare data_ jsonb;
begin
 select jsonb_build_object('ready',r.fingerprint=md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text)) into data_
 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id limit 1;
 return data_;
end $$;
