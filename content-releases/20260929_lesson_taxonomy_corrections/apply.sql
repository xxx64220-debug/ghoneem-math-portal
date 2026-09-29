begin;
lock table public.questions, public.revision_items in share row exclusive mode;
do $taxonomy_corrections$
declare
 v_rows jsonb := $rows$[
  {"id":"12039edd-0ed2-4caf-847b-1f8b79633f6d","track_id":"sat","old_lesson":"Statistics and data analysis","new_lesson":"Functions and transformations"},
  {"id":"5f8bdfe2-cb1a-409e-b86a-1f4c6fd5c15a","track_id":"sat","old_lesson":"Triangles and similarity","new_lesson":"Trigonometry"},
  {"id":"98b55bd5-6947-41a1-8d69-5f942958b2f4","track_id":"sat","old_lesson":"Triangles and similarity","new_lesson":"Trigonometry"},
  {"id":"9d7495b1-b96a-431f-b79d-6d76a5a220a3","track_id":"sat","old_lesson":"Triangles and similarity","new_lesson":"Trigonometry"},
  {"id":"a443a041-cac2-43fb-89c5-19e7039d8f56","track_id":"sat","old_lesson":"Triangles and similarity","new_lesson":"Trigonometry"},
  {"id":"bffede21-7eb9-449a-9ff9-c8fff021ae10","track_id":"sat","old_lesson":"Triangles and similarity","new_lesson":"Trigonometry"},
  {"id":"ca2b3234-ea0e-4328-9cc7-ac8d9e9e32cf","track_id":"sat","old_lesson":"Triangles and similarity","new_lesson":"Trigonometry"},
  {"id":"ff6f428b-3bba-4c63-aa81-05c6afba57a6","track_id":"sat","old_lesson":"Triangles and similarity","new_lesson":"Trigonometry"},
  {"id":"086ff1ee-3885-4c3c-ab7d-cf4685e399e4","track_id":"sat","old_lesson":"Quadratics and polynomials","new_lesson":"Polynomial division and remainder"},
  {"id":"1acd1ade-28f1-4ee4-8c84-855f427629e2","track_id":"sat","old_lesson":"Quadratics and polynomials","new_lesson":"Polynomial division and remainder"},
  {"id":"61de8416-5bda-4d8c-aaf3-14f52feb16ff","track_id":"sat","old_lesson":"Quadratics and polynomials","new_lesson":"Polynomial division and remainder"},
  {"id":"e5897815-836d-4eb7-8da2-1d7873e5f913","track_id":"sat","old_lesson":"Quadratics and polynomials","new_lesson":"Polynomial division and remainder"},
  {"id":"da7220f9-fad9-570f-a8df-5500fe4f5823","track_id":"est","old_lesson":"Quadratics and polynomials","new_lesson":"Polynomial division and remainder"}
 ]$rows$::jsonb;
 v_before text;
 v_after text;
 v_count integer;
begin
 if not exists(select 1 from public.audit_log where action='question.lesson_taxonomy.20260929') then
  raise exception 'Base lesson taxonomy audit is missing; do not apply corrections out of order';
 end if;
 if exists(select 1 from public.audit_log where action='question.lesson_taxonomy_corrections.20260929') then
  raise exception 'Lesson taxonomy corrections already applied; do not rerun';
 end if;
 if (select count(*) from jsonb_to_recordset(v_rows) as x(id uuid,track_id text,old_lesson text,new_lesson text))<>13
    or (select count(distinct id) from jsonb_to_recordset(v_rows) as x(id uuid,track_id text,old_lesson text,new_lesson text))<>13 then
  raise exception 'Incomplete or duplicate correction mapping';
 end if;
 if exists(
  select 1 from jsonb_to_recordset(v_rows) as x(id uuid,track_id text,old_lesson text,new_lesson text)
  left join public.questions q on q.id=x.id
  where q.id is null or q.track_id<>x.track_id or q.topic<>x.old_lesson
     or q.assets->>'curriculum_lesson'<>x.old_lesson
     or q.assets->>'lesson_taxonomy_version'<>'20260929'
 ) then raise exception 'Correction target state changed; re-audit before applying'; end if;
 select md5(string_agg(md5((to_jsonb(q)-'topic'-'assets')::text ||
   (q.assets-'curriculum_lesson'-'lesson_taxonomy_version')::text),'' order by q.id)) into v_before
 from public.questions q join jsonb_to_recordset(v_rows) as x(id uuid,track_id text,old_lesson text,new_lesson text) on x.id=q.id;
 insert into public.audit_log(action,target_type,target_id,meta)
 select 'question.lesson_taxonomy_corrections.20260929','question',q.id::text,
  jsonb_build_object('old_lesson',x.old_lesson,'new_lesson',x.new_lesson,'old_taxonomy_version',q.assets->>'lesson_taxonomy_version')
 from jsonb_to_recordset(v_rows) as x(id uuid,track_id text,old_lesson text,new_lesson text)
 join public.questions q on q.id=x.id;
 get diagnostics v_count=row_count;
 if v_count<>13 then raise exception 'Correction audit is incomplete'; end if;
 update public.questions q
 set topic=x.new_lesson,
     assets=q.assets||jsonb_build_object('curriculum_lesson',x.new_lesson,'lesson_taxonomy_version','20260929.1')
 from jsonb_to_recordset(v_rows) as x(id uuid,track_id text,old_lesson text,new_lesson text)
 where q.id=x.id;
 update public.revision_items r set lesson=x.new_lesson
 from jsonb_to_recordset(v_rows) as x(id uuid,track_id text,old_lesson text,new_lesson text)
 where r.question_id=x.id;
 if exists(
  select 1 from jsonb_to_recordset(v_rows) as x(id uuid,track_id text,old_lesson text,new_lesson text)
  join public.questions q on q.id=x.id left join public.revision_items r on r.question_id=q.id
  where q.topic<>x.new_lesson or q.assets->>'curriculum_lesson'<>x.new_lesson
     or q.assets->>'lesson_taxonomy_version'<>'20260929.1'
     or (r.question_id is not null and r.lesson<>x.new_lesson)
 ) then raise exception 'Correction verification failed'; end if;
 select md5(string_agg(md5((to_jsonb(q)-'topic'-'assets')::text ||
   (q.assets-'curriculum_lesson'-'lesson_taxonomy_version')::text),'' order by q.id)) into v_after
 from public.questions q join jsonb_to_recordset(v_rows) as x(id uuid,track_id text,old_lesson text,new_lesson text) on x.id=q.id;
 if v_before is distinct from v_after then raise exception 'Unexpected non-taxonomy change'; end if;
end $taxonomy_corrections$;
commit;
select track_id,topic,count(*) questions
from public.questions
where id in (select (x->>'id')::uuid from jsonb_array_elements($rows$[
 {"id":"12039edd-0ed2-4caf-847b-1f8b79633f6d"},{"id":"5f8bdfe2-cb1a-409e-b86a-1f4c6fd5c15a"},{"id":"98b55bd5-6947-41a1-8d69-5f942958b2f4"},{"id":"9d7495b1-b96a-431f-b79d-6d76a5a220a3"},{"id":"a443a041-cac2-43fb-89c5-19e7039d8f56"},{"id":"bffede21-7eb9-449a-9ff9-c8fff021ae10"},{"id":"ca2b3234-ea0e-4328-9cc7-ac8d9e9e32cf"},{"id":"ff6f428b-3bba-4c63-aa81-05c6afba57a6"},{"id":"086ff1ee-3885-4c3c-ab7d-cf4685e399e4"},{"id":"1acd1ade-28f1-4ee4-8c84-855f427629e2"},{"id":"61de8416-5bda-4d8c-aaf3-14f52feb16ff"},{"id":"e5897815-836d-4eb7-8da2-1d7873e5f913"},{"id":"da7220f9-fad9-570f-a8df-5500fe4f5823"}
]$rows$::jsonb) x)
group by track_id,topic order by track_id,topic;
