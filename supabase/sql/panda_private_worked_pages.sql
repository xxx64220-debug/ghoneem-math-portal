-- Clean-environment support for the already-released private worked pages.
-- No question imports, image transfers, fingerprint updates or revision activation.
-- See content-releases/20261006_sat_pr6_reconciliation/README.md before use.
begin;
create table if not exists public.panda_solution_pages (
 page integer primary key check (page between 312 and 412),
 figure text not null check (figure like 'data:image/jpeg;base64,%')
);
alter table public.panda_solution_pages enable row level security;
revoke all on public.panda_solution_pages from public, anon, authenticated;
grant select, insert, update, delete on public.panda_solution_pages to service_role;

create or replace function public.final_revision_state(p_user uuid, p_track text, p_session uuid)
returns jsonb language plpgsql security invoker set search_path to 'public', 'pg_temp' as $function$
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
revoke all on function public.final_revision_state(uuid,text,uuid) from public, anon, authenticated;
grant execute on function public.final_revision_state(uuid,text,uuid) to service_role;
commit;
