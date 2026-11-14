"""Refresh reviewed Final Revision catalogue entries without changing saved sessions."""
import json
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'content-releases/20261114_bank_review'
rows=json.loads((out/'revision_sync_before.json').read_text())
literal="'"+json.dumps(rows,ensure_ascii=False,separators=(',',':')).replace("'","''")+"'"
sql=r'''begin isolation level repeatable read;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $sync$
declare data_ jsonb:=DATA_LITERAL::jsonb; p jsonb; h text; t text; old_history jsonb:='{}';
 protected_tables text[]:=array['attempts','attempt_answers','attempt_results','exams','assignments','revision_sessions','practice_bundle_items','practice_notebook'];
begin
 perform 1 from questions where id in(select (v->>'id')::uuid from jsonb_array_elements(data_) v) order by id for update;
 perform 1 from question_keys where question_id in(select (v->>'id')::uuid from jsonb_array_elements(data_) v) order by question_id for update;
 perform 1 from revision_items where question_id in(select (v->>'id')::uuid from jsonb_array_elements(data_) v) order by question_id for update;
 for p in select value from jsonb_array_elements(data_) loop
  if (select md5(to_jsonb(q)::text) from questions q where q.id=(p->>'id')::uuid) is distinct from p->>'question_hash'
   or (select md5(to_jsonb(k)::text) from question_keys k where k.question_id=(p->>'id')::uuid) is distinct from p->>'key_hash'
   or (select to_jsonb(r) from revision_items r where r.question_id=(p->>'id')::uuid) is distinct from p->'revision_before'
  then raise exception 'Concurrent revision content change: %',p->>'id'; end if;
  if not exists(select 1 from questions q join question_keys k on k.question_id=q.id where q.id=(p->>'id')::uuid
   and portal_private.question_eligible(q,k,q.track_id,false) and jsonb_typeof(k.correct) in ('string','array')
   and not exists(select 1 from question_catalogue c where c.question_id=q.id and c.reserve))
  then raise exception 'Reviewed revision question is no longer eligible: %',p->>'id';end if;
 end loop;
 foreach t in array protected_tables loop
  execute format('select md5(coalesce(string_agg(h,%L order by h),%L)) from (select md5(to_jsonb(x)::text) h from public.%I x) s','','',t) into h;
  old_history:=old_history||jsonb_build_object(t,h);
 end loop;
 update questions set topic='Angles and lines',assets=assets||jsonb_build_object('curriculum_lesson','Angles and lines','lesson_subtopic','Parallel lines and angle relationships') where id='2574795c-0842-5799-a7a6-9f318be55de6';
 update questions set topic='Inequalities and absolute value',assets=assets||jsonb_build_object('curriculum_lesson','Inequalities and absolute value','lesson_subtopic','Absolute-value equations') where id='38d27545-acab-51b6-8a5a-e5552566ff8c';
 update revision_items r set active=true,lesson=q.topic,idea=coalesce(nullif(q.assets->>'lesson_subtopic',''),r.idea),
  fingerprint=revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation),
  focus=coalesce(r.focus,'{}'::jsonb)||jsonb_build_object('takeaway',k.explanation)
 from questions q join question_keys k on k.question_id=q.id
 where r.question_id=q.id and q.id in(select (v->>'id')::uuid from jsonb_array_elements(data_) v);
 if (select count(*) from revision_items r join questions q on q.id=r.question_id join question_keys k on k.question_id=q.id
  where q.id in(select (v->>'id')::uuid from jsonb_array_elements(data_) v) and r.active and r.lesson=q.topic
  and r.fingerprint=revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>51
 then raise exception 'Reviewed Final Revision catalogue is incomplete'; end if;
 foreach t in array protected_tables loop
  execute format('select md5(coalesce(string_agg(h,%L order by h),%L)) from (select md5(to_jsonb(x)::text) h from public.%I x) s','','',t) into h;
  if h is distinct from old_history->>t then raise exception 'Protected history changed: %',t;end if;
 end loop;
end $sync$;
commit;
'''.replace('DATA_LITERAL',literal)
(out/'sync_final_revision.sql').write_text(sql)
