-- Staff-only source documents. Keys never appear in public assets or list RPCs.
begin;
create table public.act2_collection_documents (
 id text primary key,
 filename text not null,
 relative_path text not null,
 category text not null,
 subject text not null,
 notes text not null default '',
 source_url text not null default '',
 sha256 text not null unique check (sha256 ~ '^[0-9a-f]{64}$'),
 page_count integer not null check(page_count>0),
 size_bytes bigint not null check(size_bytes>0),
 page_text jsonb not null check(jsonb_typeof(page_text)='array'),
 download_manifest jsonb not null check(jsonb_typeof(download_manifest)='array'),
 created_at timestamptz not null default now()
);
create function public.act2_collection_staff() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and p.status='active'
 and (p.role='admin' or (p.role='instructor' and exists(select 1 from public.instructor_tracks t where t.user_id=p.id and t.track_id='act2'))));
$$;
revoke all on function public.act2_collection_staff() from public,anon;
grant execute on function public.act2_collection_staff() to authenticated;
alter table public.act2_collection_documents enable row level security;
revoke all on public.act2_collection_documents from public,anon,authenticated;
grant select on public.act2_collection_documents to authenticated;
grant all on public.act2_collection_documents to service_role;
create policy act2_collection_staff_only on public.act2_collection_documents for select to authenticated
 using ((select public.act2_collection_staff()));
create function public.act2_collection_search(p_search text default '',p_category text default '',p_subject text default '')
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result_ jsonb;
begin
 if not public.act2_collection_staff() then raise exception 'forbidden'; end if;
 if length(coalesce(p_search,''))>200 then raise exception 'invalid_search'; end if;
 select coalesce(jsonb_agg(to_jsonb(r) order by r.category,r.filename),'[]'::jsonb) into result_ from (
 select d.id,d.filename,d.category,d.subject,d.notes,d.page_count,d.size_bytes,
 coalesce((select jsonb_agg((v->>'page')::int order by (v->>'page')::int)
 from jsonb_array_elements(d.page_text) v where coalesce(p_search,'')<>'' and strpos(lower(v->>'text'),lower(p_search))>0),'[]'::jsonb) matching_pages
 from public.act2_collection_documents d
 where (coalesce(p_category,'')='' or d.category=p_category) and (coalesce(p_subject,'')='' or d.subject=p_subject)
 and (coalesce(p_search,'')='' or strpos(lower(concat_ws(' ',d.filename,d.notes,d.category,d.subject)),lower(p_search))>0
 or exists(select 1 from jsonb_array_elements(d.page_text) v where strpos(lower(v->>'text'),lower(p_search))>0))
 ) r;
 return result_;
end $$;
revoke all on function public.act2_collection_search(text,text,text) from public,anon;
grant execute on function public.act2_collection_search(text,text,text) to authenticated;
commit;
