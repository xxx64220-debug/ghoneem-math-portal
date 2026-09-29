begin;
-- These service-only tables deliberately keep revision progress separate from
-- official exam attempts, grades, retake limits and daily challenge points.
create table if not exists public.revision_items (
 question_id uuid primary key references public.questions(id),
 lesson text not null, idea text not null,
 difficulty text not null check(difficulty in ('easy','medium','hard')),
 programmes text[] not null check(cardinality(programmes)>0 and programmes <@ array['sat','est']::text[]),
 fingerprint text not null,
 active boolean not null default true
);
alter table public.revision_items enable row level security;
revoke all on public.revision_items from public,anon,authenticated;
grant all on public.revision_items to service_role;
create table if not exists public.revision_sessions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 access_track text not null references public.tracks(id),
 lesson text not null default '',
 snapshot jsonb not null check(jsonb_typeof(snapshot)='array' and jsonb_array_length(snapshot) between 1 and 20),
 answers jsonb not null default '{}',
 created_at timestamptz not null default now(),
 completed_at timestamptz
);
create index if not exists revision_sessions_owner_idx on public.revision_sessions(user_id,access_track,created_at desc);
create index if not exists revision_sessions_track_idx on public.revision_sessions(access_track);
alter table public.revision_sessions enable row level security;
revoke all on public.revision_sessions from public,anon,authenticated;
grant all on public.revision_sessions to service_role;

-- Lesson labels are classification metadata. They must not invalidate a
-- reviewed question when the student-visible content is unchanged.
create or replace function public.revision_question_fingerprint(
 p_stem text,p_choices jsonb,p_assets jsonb,p_correct jsonb,p_explanation text
) returns text language sql immutable security invoker set search_path=public,pg_temp as $$
 select md5(jsonb_build_array(
  p_stem,p_choices,
  coalesce(p_assets,'{}'::jsonb)-'curriculum_lesson'-'lesson_subtopic'-'lesson_original_topic'-'lesson_taxonomy_version',
  p_correct,p_explanation
 )::text)
$$;
revoke all on function public.revision_question_fingerprint(text,jsonb,jsonb,jsonb,text) from public,anon,authenticated;
grant execute on function public.revision_question_fingerprint(text,jsonb,jsonb,jsonb,text) to service_role;

create or replace function public.final_revision_state(p_user uuid,p_track text,p_session uuid)
returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare s public.revision_sessions%rowtype; qs jsonb;
begin
 if p_track not in ('sat','est') or not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
 select * into s from public.revision_sessions where id=p_session and user_id=p_user and access_track=p_track;
 if not found then raise exception 'revision_session_not_found'; end if;
 select jsonb_agg((q - 'correct' - 'explanation' - 'fingerprint') || jsonb_build_object(
  'response',s.answers->(q->>'id'),
  'feedback',case when s.answers ? (q->>'id') then jsonb_build_object(
   'correct',public.answer_matches(q->>'type',s.answers->(q->>'id'),q->'correct'),
   'answer',q->'correct','explanation',q->>'explanation') else null end) order by n)
 into qs from jsonb_array_elements(s.snapshot) with ordinality e(q,n);
 return jsonb_build_object('id',s.id,'lesson',s.lesson,'questions',qs,'completed',s.completed_at is not null);
end $$;

create or replace function public.final_revision(p_user uuid,p_track text,p_action text,p_options jsonb default '{}')
returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare
 items jsonb; candidates jsonb; picked jsonb:='[]'; chosen jsonb; seen jsonb;
 s public.revision_sessions%rowtype; sid uuid; qid text; response text;
 scope_ text:=coalesce(p_options->>'scope',p_track);
 source_ text:=coalesce(p_options->>'source','both');
 level_ text:=coalesce(p_options->>'difficulty','mixed');
 lesson_ text:=coalesce(p_options->>'lesson','');
 total_ int; n int; easy_ int; medium_ int; need_ text; retry_ uuid;
begin
 if p_track not in ('sat','est') or not public.is_enrolled(p_user,p_track)
  or not exists(select 1 from public.profiles where id=p_user and role='student' and status='active')
 then raise exception 'not_enrolled_in_track'; end if;
 if p_action='state' then return public.final_revision_state(p_user,p_track,(p_options->>'session')::uuid); end if;
 if p_action='answer' then
  select * into s from public.revision_sessions where id=(p_options->>'session')::uuid and user_id=p_user and access_track=p_track for update;
  if not found then raise exception 'revision_session_not_found'; end if;
  qid:=p_options->>'question'; response:=btrim(p_options->>'answer');
  select q into chosen from jsonb_array_elements(s.snapshot) q where q->>'id'=qid;
  if chosen is null or response is null or length(response) not between 1 and 250
    or jsonb_typeof(p_options->'answer') is distinct from 'string'
    or (chosen->>'type'='mcq' and not exists(select 1 from jsonb_array_elements(chosen->'choices') c where c->>'key'=response))
  then raise exception 'invalid_answer'; end if;
  -- A checked answer is immutable. Network retries return the first result.
  if not s.answers ? qid then
   s.answers:=s.answers||jsonb_build_object(qid,response);
   update public.revision_sessions set answers=s.answers,
    completed_at=case when (select count(*) from jsonb_object_keys(s.answers))=jsonb_array_length(s.snapshot) then now() else null end
    where id=s.id;
  end if;
  return public.final_revision_state(p_user,p_track,s.id);
 end if;
 if p_action not in ('catalogue','start') then raise exception 'invalid_action'; end if;
 -- Hide source edits until reviewed again; holds also take effect immediately.
 select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'lesson',r.lesson,'idea',r.idea,
  'difficulty',r.difficulty,'programmes',r.programmes,'source',q.track_id,
  'stem',q.stem,'type',q.type,'choices',q.choices,
  'assets',(select coalesce(jsonb_object_agg(a.key,a.value),'{}') from jsonb_each(coalesce(q.assets,'{}')) a
     where a.key=any(array['figure','figure_caption','figspec','html','svg','image','image_alt','source_code','source_document','source_question','instructions','reference'])),
  'correct',k.correct,'explanation',k.explanation)),'[]') into candidates
 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
 where r.active and nullif(q.assets->>'release_hold_reason','') is null
 and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation);
 select coalesce(jsonb_object_agg(a.key,true),'{}') into seen
 from (select distinct a.key from public.revision_sessions rs cross join lateral jsonb_each(rs.answers) a
       where rs.user_id=p_user) a;
 if p_action='catalogue' then
  select coalesce(jsonb_agg((q-'stem'-'type'-'choices'-'assets'-'correct'-'explanation')||jsonb_build_object('practised',seen ? (q->>'id'))),'[]') into items from jsonb_array_elements(candidates) q;
  select id into sid from public.revision_sessions where user_id=p_user and access_track=p_track and completed_at is null order by created_at desc limit 1;
  return jsonb_build_object('items',items,'session',case when sid is not null then public.final_revision_state(p_user,p_track,sid) else null end);
 end if;
 if scope_ not in ('sat','est','both') or source_ not in ('sat','est','both') or level_ not in ('easy','medium','hard','mixed')
   or coalesce(p_options->>'count','10') not in ('10','20') then raise exception 'invalid_revision_filter'; end if;
 total_:=coalesce(p_options->>'count','10')::int;
 retry_:=(p_options->>'retry')::uuid;
 if retry_ is not null then
  select * into s from public.revision_sessions where id=retry_ and user_id=p_user and access_track=p_track and completed_at is not null;
  if not found then raise exception 'revision_session_not_found'; end if;
  select coalesce(jsonb_agg(q),'[]') into candidates from jsonb_array_elements(candidates) q
  where exists(select 1 from jsonb_array_elements(s.snapshot) old where old->>'id'=q->>'id'
   and not public.answer_matches(old->>'type',s.answers->(old->>'id'),old->'correct'));
  lesson_:='Retry mistakes';level_:='mixed';
 else
  select coalesce(jsonb_agg(q),'[]') into candidates from jsonb_array_elements(candidates) q
  where (scope_='both' or q->'programmes' ? scope_) and (source_='both' or q->>'source'=source_)
    and (level_='mixed' or q->>'difficulty'=level_) and (lesson_='' or q->>'lesson'=lesson_);
 end if;
 total_:=least(total_,jsonb_array_length(candidates));
 if total_=0 then raise exception 'no_revision_questions'; end if;
 easy_:=round(total_*0.3);medium_:=round(total_*0.4);
 for n in 1..total_ loop
  need_:=case when n<=easy_ then 'easy' when n<=easy_+medium_ then 'medium' else 'hard' end;
  select q into chosen from jsonb_array_elements(candidates) q
   where not exists(select 1 from jsonb_array_elements(picked) p where p->>'id'=q->>'id')
   order by case when level_='mixed' and q->>'difficulty'=need_ then 0 else 1 end,
    (select count(*) from jsonb_array_elements(picked) p where p->>'lesson'=q->>'lesson'),
    (select count(*) from jsonb_array_elements(picked) p where p->>'idea'=q->>'idea'),
    case when seen ? (q->>'id') then 1 else 0 end,
    (select count(*) from jsonb_array_elements(picked) p where p->>'source'=q->>'source'),random() limit 1;
  picked:=picked||jsonb_build_array(chosen);
 end loop;
 -- Mix the chosen levels so the answer position never hints at difficulty.
 select jsonb_agg(q order by random()) into picked from jsonb_array_elements(picked) q;
 insert into public.revision_sessions(user_id,access_track,lesson,snapshot) values(p_user,p_track,lesson_,picked) returning id into sid;
 return public.final_revision_state(p_user,p_track,sid);
end $$;
revoke all on function public.final_revision(uuid,text,text,jsonb),public.final_revision_state(uuid,text,uuid) from public,anon,authenticated;
grant execute on function public.final_revision(uuid,text,text,jsonb),public.final_revision_state(uuid,text,uuid) to service_role;
commit;
