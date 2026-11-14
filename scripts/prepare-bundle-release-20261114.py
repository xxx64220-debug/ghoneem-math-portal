"""Compose reviewed upgrades with preservation checks and a rollback-only live rehearsal."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
out = root / 'content-releases/20261114_bundle_integration'
out.mkdir(parents=True, exist_ok=True)
tables = ['public.attempts','public.attempt_answers','public.attempt_results','public.exams',
          'public.assignments','public.revision_sessions','public.practice_bundles',
          'public.practice_bundle_items','public.daily_progress','portal_private.notebook_activity']
snapshot = "\nunion all\n".join(f"select '{t}' as name, md5(coalesce(string_agg(h,'' order by h),'')) as hash from (select md5(to_jsonb(t)::text) h from {t} t) s" for t in tables)
start = """-- Reviewed all-course practice integration. Never replay after successful installation.
begin isolation level repeatable read;
set local lock_timeout='5s';
set local statement_timeout='60s';
create temporary table bundle_release_before on commit drop as
""" + snapshot + ";\n"
upgrades = ''
for name in ['practice_bundle_hierarchy.sql','practice_bundle_integration.sql']:
    sql = (root/'supabase/sql'/name).read_text()
    upgrades += re.sub(r'^(begin;|commit;)\s*$', '', sql, flags=re.M) + '\n'
check = """
do $preserve$
begin
 if exists(select * from bundle_release_before except select * from (
""" + snapshot + """
 ) after) then raise exception 'bundle_release_changed_protected_history'; end if;
 if exists(select 1 from pg_proc p where p.oid in (
 'public.practice_bundle_catalog(uuid,text)'::regprocedure,
 'public.practice_bundle_create(uuid,text,uuid,jsonb,uuid)'::regprocedure,
 'portal_private.diagnosis_lessons(uuid,text)'::regprocedure,
 'portal_private.diagnosis_lessons_batch(uuid[],text)'::regprocedure,
 'portal_private.bundle_evidence(uuid[],text)'::regprocedure)
 and (has_function_privilege('anon',p.oid,'execute') or has_function_privilege('authenticated',p.oid,'execute')))
 then raise exception 'bundle_release_exposed_private_function'; end if;
 if has_table_privilege('anon','portal_private.bundle_subtopics','select')
 or has_table_privilege('authenticated','portal_private.bundle_subtopics','select')
 then raise exception 'bundle_release_exposed_private_metadata'; end if;
end $preserve$;
"""
rehearsal = """
-- Uses only the existing isolated test profile; all work below is rolled back.
do $smoke$
declare u uuid; t text; b jsonb; saved jsonb; nextb jsonb; q uuid; settings jsonb;
 answers jsonb; catalogue jsonb; c bigint; before_unseen bigint; after_unseen bigint;
 batch jsonb; student jsonb; started timestamptz;
begin
 select p.id into strict u from public.profiles p where p.is_test and p.role='student' and p.status='active'
 and (select count(*) from public.enrollments e where e.user_id=p.id and e.status='active')>=5 order by p.id limit 1;
 for t in select e.track_id from public.enrollments e where e.user_id=u and e.status='active' loop
  started:=clock_timestamp();
  catalogue:=public.practice_bundle_catalog(u,t);
  if not (catalogue->>'subtopics_supported')::boolean or jsonb_array_length(catalogue->'topics')=0 then raise exception 'empty_hierarchy_%',t; end if;
  if clock_timestamp()-started>interval '8 seconds' then raise exception 'slow_catalogue_%',t; end if;
  select coalesce(sum((x->>'unseen')::int),0) into before_unseen from jsonb_array_elements(catalogue->'topics') x;
  settings:=jsonb_build_object('count',2,'difficulty','mixed','topics','[]'::jsonb,'subtopics','[]'::jsonb,'exclude_answered',true);
  b:=public.practice_bundle_create(u,t,gen_random_uuid(),settings,null);
  if b ? 'error' or jsonb_array_length(b->'question_ids')<>2 then raise exception 'cannot_create_%',t; end if;
  select jsonb_object_agg(i.question_id::text,case when i.payload->>'type'='mcq' then i.payload->'choices'->0->>'key' else '0' end)
   into answers from public.practice_bundle_items i where i.bundle_id=(b->>'id')::uuid;
  saved:=public.practice_bundle_save(u,t,(b->>'id')::uuid,0,answers,0,false);
  if public.practice_bundle_state(u,t,(b->>'id')::uuid)->'answers' is distinct from answers then raise exception 'resume_failed_%',t; end if;
  catalogue:=public.practice_bundle_catalog(u,t);
  select coalesce(sum((x->>'unseen')::int),0) into after_unseen from jsonb_array_elements(catalogue->'topics') x;
  if after_unseen<>before_unseen-2 then raise exception 'saved_history_count_failed_%',t; end if;
  nextb:=public.practice_bundle_create(u,t,gen_random_uuid(),settings,null);
  if exists(select 1 from jsonb_array_elements_text(b->'question_ids') a join jsonb_array_elements_text(nextb->'question_ids') c on a.value=c.value)
   then raise exception 'repeated_saved_answer_%',t; end if;
  saved:=public.practice_bundle_save(u,t,(b->>'id')::uuid,1,answers,0,true);
  if saved->>'completed_at' is null or saved->>'score' is null then raise exception 'grading_failed_%',t; end if;
  if exists(select 1 from portal_private.bundle_evidence(array[u],t) e where e.bundle_id=(b->>'id')::uuid and not e.is_correct
   and not exists(select 1 from public.practice_notebook n where n.user_id=u and n.question_id=e.question_id)) then raise exception 'missing_mistake_%',t; end if;
  student:=portal_private.diagnosis_lessons(u,t);
  select lessons into batch from portal_private.diagnosis_lessons_batch(array[u],t);
  if student is distinct from batch then raise exception 'diagnosis_disagrees_%',t; end if;
  select count(*) into c from public.practice_bundles where user_id=u;
  nextb:=public.practice_bundle_create(u,t,gen_random_uuid(),settings||'{"topics":["nonexistent-release-test-lesson"],"count":100}'::jsonb,null);
  if nextb->>'error'<>'not_enough_questions' or (nextb->>'available')::int<>0 or c<>(select count(*) from public.practice_bundles where user_id=u)
   then raise exception 'shortage_changed_work_%',t; end if;
 end loop;
end $smoke$;
rollback;
"""
(out/'apply.sql').write_text(start+upgrades+check+'commit;\n')
(out/'rehearse.sql').write_text(start+upgrades+check+rehearsal)
print(out)
