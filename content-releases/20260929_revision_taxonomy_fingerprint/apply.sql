begin;
lock table public.questions, public.question_keys, public.revision_items, public.audit_log in share row exclusive mode;

create or replace function public.revision_question_fingerprint(
 p_stem text,p_choices jsonb,p_assets jsonb,p_correct jsonb,p_explanation text
) returns text language sql immutable security invoker set search_path=public,pg_temp as $$
 select md5(jsonb_build_array(
  p_stem,p_choices,
  coalesce(p_assets,'{}'::jsonb)-'curriculum_lesson'-'lesson_subtopic'-'lesson_original_topic'-'lesson_taxonomy_version',
  p_correct,p_explanation
 )::text)
$$;
revoke all on function public.revision_question_fingerprint(text,jsonb,jsonb,jsonb,text) from public,anon,authenticated;
grant execute on function public.revision_question_fingerprint(text,jsonb,jsonb,jsonb,text) to service_role;

do $revision_taxonomy_fingerprint$
declare
 v_rows integer;
 v_reviewed integer:=0;
 v_oid oid;
 v_definition text;
 v_old constant text:='md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text)';
 v_new constant text:='public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)';
begin
 if exists(select 1 from public.audit_log where action='revision.fingerprint_taxonomy_repair.20260929') then
  raise exception 'Revision taxonomy fingerprint repair already applied; do not rerun';
 end if;
 if (select count(*) from public.audit_log where action='question.lesson_taxonomy.20260929' and target_type='question')<>6916
    or (select count(distinct target_id) from public.audit_log where action='question.lesson_taxonomy.20260929' and target_type='question')<>6916 then
  raise exception 'Base taxonomy audit is incomplete; do not repair fingerprints';
 end if;
 if (select count(*) from public.audit_log where action='question.lesson_taxonomy_corrections.20260929')<>13 then
  raise exception 'Taxonomy correction audit is incomplete; do not repair fingerprints';
 end if;
 if (select count(*) from public.revision_items)<>2207 then
  raise exception 'Revision catalogue changed; re-review before repairing fingerprints';
 end if;

 create temporary table revision_taxonomy_verified on commit drop as
 with base as (
  select r.question_id,q.track_id,r.fingerprint,q.stem,q.choices,q.assets,k.correct,k.explanation,a.meta
  from public.revision_items r
  join public.questions q on q.id=r.question_id
  join public.question_keys k on k.question_id=q.id
  join public.audit_log a on a.action='question.lesson_taxonomy.20260929'
   and a.target_type='question' and a.target_id=q.id::text
 ), restored as (
  select *,
   (assets-'curriculum_lesson'-'lesson_subtopic'-'lesson_original_topic'-'lesson_taxonomy_version')
   ||case when coalesce(meta->'old_curriculum_lesson','null'::jsonb)<>'null'::jsonb then jsonb_build_object('curriculum_lesson',meta->'old_curriculum_lesson') else '{}'::jsonb end
   ||case when coalesce(meta->'old_lesson_subtopic','null'::jsonb)<>'null'::jsonb then jsonb_build_object('lesson_subtopic',meta->'old_lesson_subtopic') else '{}'::jsonb end
   ||case when coalesce(meta->'old_lesson_original_topic','null'::jsonb)<>'null'::jsonb then jsonb_build_object('lesson_original_topic',meta->'old_lesson_original_topic') else '{}'::jsonb end
   ||case when coalesce(meta->'old_lesson_taxonomy_version','null'::jsonb)<>'null'::jsonb then jsonb_build_object('lesson_taxonomy_version',meta->'old_lesson_taxonomy_version') else '{}'::jsonb end old_assets
  from base
 )
 select question_id,track_id,fingerprint old_fingerprint,
  public.revision_question_fingerprint(stem,choices,assets,correct,explanation) new_fingerprint,
  fingerprint=md5(jsonb_build_array(stem,choices,old_assets,correct,explanation)::text) old_match
 from restored;

 select count(*) into v_rows from revision_taxonomy_verified;
 if v_rows<>2207 then raise exception 'Revision rows are missing taxonomy audit or answer-key data'; end if;
 if (select count(*) from revision_taxonomy_verified where track_id='sat' and old_match)<>1261
    or (select count(*) from revision_taxonomy_verified where track_id='est' and old_match)<>518
    or (select count(*) from revision_taxonomy_verified where track_id='est2' and old_match)<>415
    or (select count(*) from revision_taxonomy_verified where track_id='est' and not old_match)<>12
    or (select count(*) from revision_taxonomy_verified where track_id='est2' and not old_match)<>1
    or exists(select 1 from revision_taxonomy_verified where track_id='sat' and not old_match) then
  raise exception 'Pre-taxonomy revision fingerprint evidence changed; re-review before applying';
 end if;

 insert into public.audit_log(action,target_type,target_id,meta)
 select 'revision.fingerprint_taxonomy_repair.item.20260929','question',question_id::text,
  jsonb_build_object('old_fingerprint',old_fingerprint,'new_fingerprint',new_fingerprint)
 from revision_taxonomy_verified where old_match;
 get diagnostics v_rows=row_count;
 if v_rows<>2194 then raise exception 'Revision repair audit is incomplete'; end if;

 update public.revision_items r set fingerprint=v.new_fingerprint
 from revision_taxonomy_verified v where v.old_match and r.question_id=v.question_id;
 get diagnostics v_rows=row_count;
 if v_rows<>2194 then raise exception 'Revision fingerprint repair is incomplete'; end if;

 for v_oid in
  select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prokind='f' and p.proname in ('final_revision','portal_manage')
 loop
  v_definition:=pg_get_functiondef(v_oid);
  if position(v_old in v_definition)>0 then
   execute replace(v_definition,v_old,v_new);
   v_reviewed:=v_reviewed+1;
  elsif position(v_new in v_definition)>0 then
   v_reviewed:=v_reviewed+1;
  end if;
 end loop;
 if v_reviewed<>2 then raise exception 'Expected revision runtime functions were not in the reviewed state'; end if;

 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
     where q.track_id='sat' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>1261
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
     where q.track_id='est' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>518
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
     where q.track_id='est2' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>415 then
  raise exception 'Repaired revision catalogue count is incorrect';
 end if;
 if exists(
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prokind='f' and p.proname in ('final_revision','portal_manage')
   and position(v_old in pg_get_functiondef(p.oid))>0
 ) then raise exception 'Legacy revision fingerprint check remains active'; end if;

 insert into public.audit_log(action,target_type,target_id,meta)
 values ('revision.fingerprint_taxonomy_repair.20260929','release','20260929',
  jsonb_build_object('repaired',2194,'preserved_stale',13,
   'ready_by_track',jsonb_build_object('sat',1261,'est',518,'est2',415)));
end $revision_taxonomy_fingerprint$;
commit;

select q.track_id,count(*) ready
from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
where r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)
group by q.track_id order by q.track_id;
