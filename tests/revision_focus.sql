-- Requires the reviewed 378-question release. Leaves no student progress behind.
begin;
set local role service_role;
do $$
declare u uuid; d jsonb; s jsonb; a jsonb; q jsonb; key_ jsonb; c text; sid uuid; lesson_ text;
begin
 select id into u from public.profiles where role='student' and status='active' and public.is_enrolled(id,'est') order by id limit 1;
 assert u is not null,'eligible student required';
 d:=public.final_revision(u,'est','catalogue');
 assert not exists(select 1 from jsonb_array_elements(d->'items') x where x->'focus' ? 'takeaway'),'catalogue hint leak';
 assert (select count(*) from jsonb_array_elements(d->'items') x where x#>'{focus,collections}' ? 'must_know')=88,'must know count';
 assert (select count(*) from jsonb_array_elements(d->'items') x where x#>'{focus,collections}' ? 'repeated')=110,'repeated count';
 assert (select count(*) from jsonb_array_elements(d->'items') x where x#>'{focus,collections}' ? 'unique')=32,'unique count';
 foreach c in array array['priority','must_know','repeated','unique'] loop
  s:=public.final_revision(u,'est','start',jsonb_build_object('collection',c,'count',20,'scope','both'));
  assert s->>'collection'=c,'collection not persisted';
  assert jsonb_array_length(s->'questions')=20,'focused set size';
  assert (select count(distinct (x->>'lesson',x->>'idea')) from jsonb_array_elements(s->'questions') x)=20,'duplicate idea';
  assert not exists(select 1 from jsonb_array_elements(s->'questions') x where x->'focus' ? 'takeaway' or x ?| array['correct','explanation'] or x->'feedback'<>'null'::jsonb),'preanswer leak';
  assert not exists(select 1 from jsonb_array_elements(s->'questions') x where not (case when c='priority' then jsonb_array_length(x#>'{focus,collections}')>0 else x#>'{focus,collections}' ? c end)),'collection membership';
 end loop;
 -- The unique collection's method hint appears only in checked feedback.
 sid:=(s->>'id')::uuid;q:=s->'questions'->0;
 select correct into key_ from public.question_keys where question_id=(q->>'id')::uuid;
 if jsonb_typeof(key_)='array' then key_:=key_->0;end if;
 a:=public.final_revision(u,'est','answer',jsonb_build_object('session',sid,'question',q->>'id','answer',key_));
 assert length(a#>>'{questions,0,feedback,takeaway}')>0,'missing checked method';
 assert not exists(select 1 from jsonb_array_elements(a->'questions') with ordinality e(x,n) where n>1 and (x->'feedback'<>'null'::jsonb or x->'focus' ? 'takeaway')),'other question hint leak';
 assert public.final_revision(u,'est','state',jsonb_build_object('session',sid))=a,'resume lost focus';
 -- One repeated idea under this lesson must produce one question, not duplicates.
 select x->>'lesson' into lesson_ from jsonb_array_elements(d->'items') x where x#>'{focus,collections}' ? 'repeated'
 group by x->>'lesson' having count(distinct x->>'idea')=1 limit 1;
 assert lesson_ is not null,'single idea fixture missing';
 s:=public.final_revision(u,'est','start',jsonb_build_object('collection','repeated','count',20,'scope','both','lesson',lesson_));
 assert jsonb_array_length(s->'questions')=1,'focused lesson not capped';
 s:=public.final_revision(u,'est','start','{"collection":"priority","scope":"sat","source":"sat","difficulty":"easy"}');
 assert not exists(select 1 from jsonb_array_elements(s->'questions') x where x->>'source'<>'sat' or x->>'difficulty'<>'easy' or not (x->'programmes' ? 'sat')),'focused filters';
 begin perform public.final_revision(u,'est','start','{"collection":"invalid"}');raise exception 'invalid collection accepted';
 exception when others then if sqlerrm<>'invalid_revision_filter' then raise;end if;end;
end $$;
rollback;
