"""Compile a narrowly scoped, optimistic-concurrency-guarded content transaction."""
from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[1]
out=root/'content-releases/20261114_bank_review'
suffix='_supported' if len(sys.argv)>1 and sys.argv[1]=='supported' else ''
data=json.loads((out/f'manifest{suffix}.json').read_text())
literal="'"+json.dumps(data,ensure_ascii=False,separators=(',',':')).replace("'","''")+"'"
sql=r'''-- Content changes only: no schema, feature, exam, assignment, or score writes.
begin isolation level repeatable read;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
do $release$
declare
 data_ jsonb := MANIFEST_LITERAL::jsonb;
 p jsonb; before_q jsonb; before_k jsonb; h text; t text; old_history jsonb := '{}';
 protected_tables text[] := array['attempts','attempt_answers','attempt_results','exams','assignments','revision_sessions','practice_bundle_items','practice_notebook'];
 updated_count int := 0; added_count int := 0;
begin
 -- Lock only the affected question/key rows, in a stable order, before checking hashes.
 perform 1 from questions where id in (select (v->>'id')::uuid from jsonb_array_elements(data_->'updates') v) order by id for update;
 perform 1 from question_keys where question_id in (select (v->>'id')::uuid from jsonb_array_elements(data_->'updates') v) order by question_id for update;
 for p in select value from jsonb_array_elements(data_->'updates') loop
   select to_jsonb(x) into before_q from questions x where id=(p->>'id')::uuid;
   select to_jsonb(x) into before_k from question_keys x where question_id=(p->>'id')::uuid;
   if before_q is null or before_k is null or md5(before_q::text) is distinct from p->>'row_hash' or md5(before_k::text) is distinct from p->>'key_hash'
   then raise exception 'Concurrent content change: %',p->>'id'; end if;
 end loop;
 for p in select value from jsonb_array_elements(data_->'additions') loop
   if exists(select 1 from questions where id=(p->>'id')::uuid) then raise exception 'Adaptation already exists: %',p->>'id'; end if;
   if exists(select 1 from questions x where x.assets->'source_ids_adapted' ?| array(select jsonb_array_elements_text(p->'assets'->'source_ids_adapted')))
   then raise exception 'Source already has an adaptation: %',p->>'id'; end if;
 end loop;
 -- The three clarified statements had no submitted answers at review time.
 if exists(select 1 from attempt_answers where question_id=any(array['38b3ea7c-1a64-5d12-8944-dedd2448b7c9','2574795c-0842-5799-a7a6-9f318be55de6','df2132af-840a-501e-9268-3a64a7d75791']::uuid[]))
 then raise exception 'New answers require separate versioning before clarification'; end if;
 if exists(select 1 from attempts a join exams e on e.id=a.exam_id where a.status='in_progress' and e.question_ids && array['38b3ea7c-1a64-5d12-8944-dedd2448b7c9','2574795c-0842-5799-a7a6-9f318be55de6','df2132af-840a-501e-9268-3a64a7d75791']::uuid[])
 then raise exception 'Active exam requires separate versioning before clarification'; end if;
 foreach t in array protected_tables loop
   execute format('select md5(coalesce(string_agg(h, %L order by h),%L)) from (select md5(to_jsonb(x)::text) h from public.%I x) s','','',t) into h;
   old_history := old_history || jsonb_build_object(t,h);
 end loop;
 for p in select value from jsonb_array_elements(data_->'updates') loop
   update questions set
    stem=case when p->'fields' ? 'stem' then p->'fields'->>'stem' else stem end,
    choices=case when p->'fields' ? 'choices' then p->'fields'->'choices' else choices end,
    assets=(assets - array(select jsonb_array_elements_text(p->'assets_remove'))) || (p->'assets_merge')
   where id=(p->>'id')::uuid;
   if p->'fields' ? 'explanation' then
    update question_keys set explanation=p->'fields'->>'explanation' where question_id=(p->>'id')::uuid;
   end if;
   updated_count:=updated_count+1;
 end loop;
 for p in select value from jsonb_array_elements(data_->'additions') loop
   insert into questions(id,track_id,topic,difficulty,type,stem,choices,assets)
    values((p->>'id')::uuid,p->>'track_id',p->>'topic',p->>'difficulty',p->>'type',p->>'stem',p->'choices',p->'assets');
   insert into question_keys(question_id,correct,explanation) values((p->>'id')::uuid,p->'correct',p->>'explanation');
   added_count:=added_count+1;
 end loop;
 if updated_count<>EXPECTED_UPDATES or added_count<>EXPECTED_ADDITIONS then raise exception 'Unexpected release size'; end if;
 if exists(select 1 from questions q left join question_keys k on k.question_id=q.id
   where q.assets->>'verified_release'=data_->>'release' and not portal_private.question_eligible(q,k,q.track_id,false))
 then raise exception 'Release contains ineligible content'; end if;
 if (select count(*) from questions where assets->>'verified_release'=data_->>'release')<>EXPECTED_RELEASED then raise exception 'Unexpected verified release count'; end if;
 foreach t in array protected_tables loop
   execute format('select md5(coalesce(string_agg(h, %L order by h),%L)) from (select md5(to_jsonb(x)::text) h from public.%I x) s','','',t) into h;
   if h is distinct from old_history->>t then raise exception 'Protected assessment history changed: %',t; end if;
 end loop;
end $release$;
commit;
'''.replace('MANIFEST_LITERAL',literal).replace('EXPECTED_UPDATES',str(len(data['updates']))).replace('EXPECTED_ADDITIONS',str(len(data['additions']))).replace('EXPECTED_RELEASED',str(len(data['additions'])+sum(p['assets_merge'].get('verified_release')==data['release'] for p in data['updates'])))
(out/f'apply{suffix}.sql').write_text(sql)
print('Compiled guarded release SQL')
