-- One copy of each worked-answer page. Students cannot select this table;
-- final_revision_state reveals a page only for a checked question.
begin;
create table if not exists public.panda_solution_pages (
 page integer primary key check (page between 312 and 412),
 figure text not null check (figure like 'data:image/jpeg;base64,%')
);
alter table public.panda_solution_pages enable row level security;
revoke all on public.panda_solution_pages from public, anon, authenticated;

do $$ begin
 if exists (
   select 1 from public.questions q
   where (q.assets->>'code') ~ '^PANDA-CH(1[4-9]|2[0-6])-'
   group by q.assets->>'solution_page'
   having count(distinct q.assets->>'solution_figure') <> 1
 ) then raise exception 'conflicting_panda_solution_page_images'; end if;
end $$;
insert into public.panda_solution_pages(page,figure)
select distinct (q.assets->>'solution_page')::integer,q.assets->>'solution_figure'
from public.questions q
where (q.assets->>'code') ~ '^PANDA-CH(1[4-9]|2[0-6])-'
  and q.assets ? 'solution_figure'
on conflict(page) do nothing;

do $$ begin
 if (select count(*) from public.panda_solution_pages where page between 365 and 412) <> 48
 or exists (select 1 from public.questions q
     join public.panda_solution_pages p on p.page=(q.assets->>'solution_page')::integer
     where (q.assets->>'code') ~ '^PANDA-CH(1[4-9]|2[0-6])-'
       and q.assets->>'solution_figure' is distinct from p.figure)
 then raise exception 'panda_solution_pages_incomplete'; end if;
end $$;

update public.questions q set assets=q.assets-'solution_figure'
where (q.assets->>'code') ~ '^PANDA-CH(1[4-9]|2[0-6])-'
 and q.assets ? 'solution_figure';
update public.revision_items r
set fingerprint=md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text)
from public.questions q join public.question_keys k on k.question_id=q.id
where r.question_id=q.id and (q.assets->>'code') ~ '^PANDA-CH(1[4-9]|2[0-6])-';

create or replace function public.final_revision_state(p_user uuid, p_track text, p_session uuid)
returns jsonb language plpgsql set search_path to 'public', 'pg_temp' as $function$
declare s public.revision_sessions%rowtype; qs jsonb;
begin
 if p_track not in ('sat','est','est2') or not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
 if not exists(select 1 from public.portal_track_controls where track_id=p_track and revision_visible) then raise exception 'revision_hidden';end if;
 select * into s from public.revision_sessions where id=p_session and user_id=p_user and access_track=p_track;
 if not found then raise exception 'revision_session_not_found'; end if;
 select jsonb_agg(((q - 'correct' - 'explanation' - 'fingerprint') #- '{focus,takeaway}') || jsonb_build_object(
  'assets',case when s.answers ? (q->>'id') then coalesce(q->'assets','{}'::jsonb) ||
    coalesce((select jsonb_build_object('solution_figure',sp.figure,
                                      'source_number',a.assets->'source_number')
              from public.questions a join public.panda_solution_pages sp
                on sp.page=(a.assets->>'solution_page')::integer
              where a.id=(q->>'id')::uuid and a.track_id=q->>'source'),'{}'::jsonb)
    else q->'assets' end,
  'response',s.answers->(q->>'id'),
  'feedback',case when s.answers ? (q->>'id') then jsonb_build_object(
   'correct',public.answer_matches(q->>'type',s.answers->(q->>'id'),q->'correct'),
   'answer',q->'correct','explanation',q->>'explanation','takeaway',q#>>'{focus,takeaway}') else null end) order by n)
 into qs from jsonb_array_elements(s.snapshot) with ordinality e(q,n) where q->>'source'=p_track or (p_track='sat' and q->>'source'='est');
 if qs is null then raise exception 'revision_session_not_found'; end if;
 return jsonb_build_object('id',s.id,'lesson',s.lesson,'collection',s.collection,'questions',qs,'completed',not exists(select 1 from jsonb_array_elements(qs) q where q->'feedback'='null'::jsonb));
end $function$;
commit;
