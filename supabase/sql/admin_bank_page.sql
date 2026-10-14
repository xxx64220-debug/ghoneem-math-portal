-- Staff-only metadata catalogue. Full assets and keys stay behind existing RLS/detail reads.
begin;
-- Fresh installation: refuse to overwrite an independently deployed catalogue.
do $$begin if to_regprocedure('public.admin_bank_page(text,text,text,text,text,text,integer,integer)') is not null then raise exception 'admin_bank_page already exists; review before replacing'; end if; end $$;
create or replace function public.admin_bank_page(
 p_track text,p_scope text default 'questions',p_search text default '',
 p_lesson text default '',p_status text default '',p_sort text default 'priority',
 p_page integer default 0,p_size integer default 50
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare role_ text; result_ jsonb;
begin
 select role into role_ from public.profiles where id=auth.uid() and status='active';
 if auth.uid() is null or role_ is null or role_ not in ('admin','instructor') then raise exception 'forbidden'; end if;
 if nullif(p_track,'') is null then raise exception 'choose_track'; end if;
 if role_='instructor' and not exists(select 1 from public.instructor_tracks where user_id=auth.uid() and track_id=p_track) then raise exception 'forbidden_track'; end if;
 if p_scope is null or p_sort is null or p_status is null or p_scope not in ('questions','source') or p_sort not in ('priority','topic','code','type','difficulty')
  or p_status not in ('','ready','review','unclassified','pending','independently_solved','source_checked')
  or p_page is null or p_page not between 0 and 100000 or p_size is null or p_size not between 1 and 100
  or length(coalesce(p_search,''))>200 then raise exception 'invalid_bank_filter'; end if;
 with usage_ as materialized (
  select qid,count(distinct e.id)::int uses from public.exams e cross join lateral unnest(e.question_ids) qid
  where e.track_id=p_track and e.is_published group by qid
 ), bank_ as materialized (
  select q.id,q.track_id,q.topic,q.type,q.difficulty,left(q.stem,180) stem,
   coalesce(nullif(q.assets->>'source_code',''),nullif(q.assets->>'source_question_id',''),q.id::text) code,
   coalesce(q.assets->>'source_document',q.assets->>'source_file',q.assets->>'source','') source,
   coalesce(nullif(btrim(q.assets->>'lesson_subtopic'),''),q.assets->>'skill','') skill,
   coalesce(q.assets->>'release_hold_reason','') hold_reason,
   coalesce(q.assets->>'verified_release','') verified_release,
   coalesce(q.assets->>'answer_review_status','') answer_review_status,
   portal_private.question_eligible(q,k,p_track,false) ready,
   nullif(btrim(q.topic),'') is null or q.topic ilike '%classification%' or coalesce(nullif(btrim(q.assets->>'lesson_subtopic'),''),nullif(btrim(q.assets->>'skill'),'')) is null or coalesce(q.assets->>'lesson_subtopic'='Needs classification',false) unclassified,
   coalesce(u.uses,0) published_uses,
   lower(concat_ws(' ',q.id::text,q.topic,q.stem,q.assets->>'lesson_subtopic',q.assets->>'skill',q.assets->>'source_file',q.assets->>'source_code',q.assets->>'source_question_id',q.assets->>'source',q.assets->>'source_document',q.assets->>'release_hold_reason')) search_text
  from public.questions q left join public.question_keys k on k.question_id=q.id left join usage_ u on u.qid=q.id
  where q.track_id=p_track and lower(coalesce(q.assets->>'bank_removed','false'))<>'true'
 ), labelled_ as materialized (
  select b.*,case when not ready then 'review' when answer_review_status='independently_solved' then 'independently_solved'
   when verified_release<>'' then 'source_checked' else 'pending' end review_status,
   case when not ready then 1 when unclassified then 2 when answer_review_status<>'independently_solved' then 3 else 4 end priority
  from bank_ b
 ), entries_ as materialized (
  select b.id::text entry_id,b.id question_id,b.code,b.source,null::int source_page,b.topic,b.stem,b.type,b.difficulty,b.skill,
   b.ready,b.unclassified,b.hold_reason,b.review_status,b.priority,b.published_uses,b.verified_release,b.search_text,''::text duplicate_of
  from labelled_ b where p_scope='questions'
  union all
  select s.id::text,b.id,s.source_code,s.source_document,s.source_page,coalesce(b.topic,s.source_section,''),coalesce(b.stem,''),coalesce(b.type,''),coalesce(b.difficulty,''),coalesce(b.skill,''),
   coalesce(b.ready,false),coalesce(b.unclassified,true),coalesce(nullif(b.hold_reason,''),case when not coalesce(b.ready,false) then s.review_status else '' end),
   case when coalesce(b.ready,false) then b.review_status else 'review' end,
   case when not coalesce(b.ready,false) then 1 else b.priority end,coalesce(b.published_uses,0),coalesce(b.verified_release,''),
   lower(concat_ws(' ',s.id::text,s.source_code,s.source_section,s.source_document,b.search_text)),coalesce(s.duplicate_of::text,'')
  from public.est_source_review s left join labelled_ b on b.id=s.question_id where p_scope='source' and s.track_id=p_track
 ), filtered_ as materialized (
  select * from entries_ where (coalesce(p_lesson,'')='' or topic=p_lesson)
   and (coalesce(p_search,'')='' or strpos(search_text,lower(p_search))>0)
   and (p_status='' or (p_status='ready' and ready) or (p_status='unclassified' and unclassified) or review_status=p_status)
 ), page_ as (
  select * from filtered_ order by
   case when p_sort='priority' then priority end,case when p_sort='priority' then published_uses end desc,
   case when p_sort='code' then code when p_sort='type' then type when p_sort='difficulty' then difficulty else topic end,code,entry_id
  limit p_size offset p_page*p_size
 ) select jsonb_build_object('total',(select count(*) from filtered_),'page',p_page,'size',p_size,
  'items',coalesce((select jsonb_agg(to_jsonb(p)-'search_text' order by
   case when p_sort='priority' then priority end,case when p_sort='priority' then published_uses end desc,
   case when p_sort='code' then code when p_sort='type' then type when p_sort='difficulty' then difficulty else topic end,code,entry_id) from page_ p),'[]'::jsonb),
  'lessons',coalesce((select jsonb_agg(topic order by topic) from (select distinct topic from entries_ where topic<>'') l),'[]'::jsonb),
  'summary',jsonb_build_object('total',(select count(*) from entries_),'held',(select count(*) from entries_ where not ready),
   'unclassified',(select count(*) from entries_ where unclassified),'independently_solved',(select count(*) from entries_ where review_status='independently_solved')))
 into result_;
 return result_;
end $$;
revoke all on function public.admin_bank_page(text,text,text,text,text,text,integer,integer) from public,anon;
grant execute on function public.admin_bank_page(text,text,text,text,text,text,integer,integer) to authenticated;
comment on function public.admin_bank_page(text,text,text,text,text,text,integer,integer) is 'Bounded staff catalogue with live structural readiness; source checking is not mathematical certification.';
commit;
