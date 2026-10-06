-- Keep the original worked-answer page hidden until a student checks that
-- question. It is deliberately excluded from the revision session snapshot.
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
    coalesce((select jsonb_build_object('solution_figure',a.assets->'solution_figure',
                                      'source_number',a.assets->'source_number')
              from public.questions a where a.id=(q->>'id')::uuid
                and a.track_id=q->>'source' and a.assets ? 'solution_figure'),'{}'::jsonb)
    else q->'assets' end,
  'response',s.answers->(q->>'id'),
  'feedback',case when s.answers ? (q->>'id') then jsonb_build_object(
   'correct',public.answer_matches(q->>'type',s.answers->(q->>'id'),q->'correct'),
   'answer',q->'correct','explanation',q->>'explanation','takeaway',q#>>'{focus,takeaway}') else null end) order by n)
 into qs from jsonb_array_elements(s.snapshot) with ordinality e(q,n) where q->>'source'=p_track or (p_track='sat' and q->>'source'='est');
 if qs is null then raise exception 'revision_session_not_found'; end if;
 return jsonb_build_object('id',s.id,'lesson',s.lesson,'collection',s.collection,'questions',qs,'completed',not exists(select 1 from jsonb_array_elements(qs) q where q->'feedback'='null'::jsonb));
end $function$;
