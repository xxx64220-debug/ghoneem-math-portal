-- Custom practice is isolated from exams, assignments, daily points and prior scores.
-- Service-only RPCs: the Edge Function derives p_user from a verified portal session.
create table portal_private.practice_bundle_rollout (
 singleton boolean primary key default true check(singleton), enabled boolean not null default false
);
insert into portal_private.practice_bundle_rollout(singleton,enabled) values(true,false);
alter table portal_private.practice_bundle_rollout enable row level security;
revoke all on portal_private.practice_bundle_rollout from public,anon,authenticated;
grant select on portal_private.practice_bundle_rollout to service_role;
create table public.practice_bundles (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 track_id text not null references public.tracks(id), request_id uuid not null,
 parent_id uuid references public.practice_bundles(id) on delete set null, settings jsonb not null,
 question_ids uuid[] not null check(cardinality(question_ids) between 1 and 100),
 answers jsonb not null default '{}' check(jsonb_typeof(answers)='object'),
 position integer not null default 0, revision integer not null default 0,
 score integer, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 completed_at timestamptz, unique(user_id,request_id)
);
create index practice_bundles_owner on public.practice_bundles(user_id,track_id,created_at desc,id);
create index practice_bundles_parent on public.practice_bundles(parent_id) where parent_id is not null;
create table public.practice_bundle_items (
 bundle_id uuid not null references public.practice_bundles(id) on delete cascade,
 -- Keep the historical snapshot if bank content is later removed.
 question_id uuid not null, ordinal integer not null, fingerprint text not null,
 payload jsonb not null, correct jsonb not null, explanation text not null,
 primary key(bundle_id,question_id), unique(bundle_id,ordinal)
);
create index practice_bundle_items_question on public.practice_bundle_items(question_id);
alter table public.practice_bundles enable row level security;
alter table public.practice_bundle_items enable row level security;
revoke all on public.practice_bundles,public.practice_bundle_items from public,anon,authenticated;
grant select,insert,update,delete on public.practice_bundles,public.practice_bundle_items to service_role;
-- Avoid repeatedly decompressing diagram payloads while listing bank metadata.
create index practice_bundle_released_questions on public.questions(track_id,id)
 where nullif(assets->>'verified_release','') is not null;
grant select on portal_private.question_eligibility_cache to service_role;

create or replace function portal_private.bundle_section(p_track text,p_topic text) returns text
language sql immutable set search_path='' as $$
 select case
 when p_topic ~* 'unclassified|unknown' then 'Other bank lessons'
 when p_track in ('est_eng','sat_eng') then case
  when p_topic ilike 'SEC%' then 'Standard English conventions'
  when p_topic ilike 'EoI%' then 'Expression of ideas'
  when p_topic ilike '%vocabulary%' or p_topic ilike '%structure%' or p_topic ilike '%purpose%' then 'Craft and structure'
  when p_topic ilike 'RC%' then 'Reading comprehension'
  else 'English skills' end
 when p_topic ~* 'trigonometry' then 'Trigonometry'
 when p_topic ~* 'triangle|angle|circle|area|perimeter|volume|geometry|conic|polygon' then 'Geometry'
 when p_topic ~* 'statistics|probability|ratio|percent|scatterplot|data|sampling' then 'Statistics, probability and data analysis'
 when p_topic ~* 'quadratic|polynomial|function.*transformation|exponent|radical|logarithm|complex|absolute value$|sequence' and p_topic <> 'Inequalities and absolute value' then 'Advanced algebra'
 when p_topic ~* 'matri|vector|limit|logic|set|polar|parametric' then 'Additional mathematics'
 when p_topic ~* 'desmos' then 'Calculator skills'
 else 'Algebra' end;
$$;

create or replace function portal_private.bundle_guard(p_user uuid,p_track text) returns void
language plpgsql stable set search_path='' as $$
begin
 if not exists(select 1 from public.profiles where id=p_user and status='active' and role='student') then raise exception 'student_account_required'; end if;
 if not public.is_enrolled(p_user,p_track) or not exists(select 1 from public.tracks where id=p_track and is_active) then raise exception 'not_enrolled_in_track'; end if;
 if not coalesce((select enabled from portal_private.practice_bundle_rollout where singleton),false)
 and not exists(select 1 from public.profiles where id=p_user and is_test) then raise exception 'practice_bundles_not_released'; end if;
end $$;

-- Exact bank IDs already answered, including saved partial bundles. Blanks do not count.
create or replace function portal_private.bundle_answered(p_user uuid) returns table(question_id text)
language sql stable set search_path='' as $$
 select aa.question_id::text from public.attempts a join public.attempt_answers aa on aa.attempt_id=a.id
 where a.user_id=p_user and nullif(btrim(aa.response#>>'{}'),'') is not null and aa.response<>'null'::jsonb
 union select n.question_id::text from public.practice_notebook n where n.user_id=p_user and n.tries>0
 union select x.key from public.daily_progress d cross join lateral jsonb_each(d.answers) x where d.user_id=p_user and jsonb_typeof(x.value) in ('string','number') and nullif(btrim(x.value#>>'{}'),'') is not null
 union select x.key from public.practice_drills d cross join lateral jsonb_each(d.answers) x where d.user_id=p_user and jsonb_typeof(x.value) in ('string','number') and nullif(btrim(x.value#>>'{}'),'') is not null
 union select x.key from public.revision_sessions d cross join lateral jsonb_each(d.answers) x where d.user_id=p_user and jsonb_typeof(x.value) in ('string','number') and nullif(btrim(x.value#>>'{}'),'') is not null
 union select x.key from public.practice_bundles d cross join lateral jsonb_each(d.answers) x where d.user_id=p_user and jsonb_typeof(x.value)='string' and nullif(btrim(x.value#>>'{}'),'') is not null;
$$;

create or replace function portal_private.bundle_pool(p_user uuid,p_track text)
returns table(id uuid,topic text,section text,difficulty text,answered boolean)
-- Match the cache writer's search_path: pg_get_functiondef qualifies types differently otherwise.
language sql stable set search_path=public,pg_temp as $$
 with seen as materialized (select question_id from portal_private.bundle_answered(p_user)),
 rule as materialized (select md5(pg_get_functiondef('portal_private.question_eligible(public.questions,public.question_keys,text,boolean)'::regprocedure)) as version),
 released as materialized (
  select q.id from public.questions q where q.track_id=p_track and nullif(q.assets->>'verified_release','') is not null
  union select unnest(e.question_ids) from public.exams e where e.track_id=p_track and e.is_published
 )
 select q.id,q.topic,portal_private.bundle_section(q.track_id,q.topic),q.difficulty,exists(select 1 from seen where question_id=q.id::text)
 from released r join public.questions q on q.id=r.id
 where q.track_id=p_track and coalesce(
  (select c.exam_eligible and c.track_id=p_track from portal_private.question_eligibility_cache c where c.question_id=q.id and c.rule_version=(select version from rule)),
  (select portal_private.question_eligible(live,k,p_track,false) from public.questions live left join public.question_keys k on k.question_id=live.id where live.id=q.id offset 0))
 and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve)
 ;
$$;

create or replace function public.practice_bundle_catalog(p_user uuid,p_track text) returns jsonb
language plpgsql set search_path='' as $$
declare items jsonb;
begin
 perform portal_private.bundle_guard(p_user,p_track);
 select coalesce(jsonb_agg(to_jsonb(t) order by section,topic,difficulty),'[]') into items from (
 select section,topic,difficulty,count(*)::int as total,count(*) filter(where not answered)::int as unseen
 from portal_private.bundle_pool(p_user,p_track) group by section,topic,difficulty) t;
 return jsonb_build_object('track',p_track,'topics',items,'max_questions',100,
 'test_account',(select is_test from public.profiles where id=p_user),
 'account_name',(select full_name from public.profiles where id=p_user));
end $$;

create function portal_private.bundle_ready(p_id uuid,p_track text) returns boolean
language sql stable set search_path='' as $$
 select not exists(select 1 from public.practice_bundle_items i
 left join public.questions q on q.id=i.question_id left join public.question_keys k on k.question_id=q.id
 where i.bundle_id=p_id and (q.id is null or k.question_id is null or not portal_private.question_eligible(q,k,p_track,false)
 or exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve)
 or i.fingerprint is distinct from md5(jsonb_build_array(q.stem,q.type,q.choices,q.assets,k.correct,k.explanation)::text)));
$$;

create or replace function public.practice_bundle_state(p_user uuid,p_track text,p_bundle uuid) returns jsonb
language plpgsql set search_path='' as $$
declare b public.practice_bundles%rowtype; items jsonb;
begin
 perform portal_private.bundle_guard(p_user,p_track);
 select * into b from public.practice_bundles where id=p_bundle and user_id=p_user and track_id=p_track;
 if not found then raise exception 'bundle_not_found'; end if;
 select jsonb_agg(i.payload || case when b.completed_at is not null then
 jsonb_build_object('correct',i.correct,'explanation',i.explanation,'is_correct',public.answer_matches(i.payload->>'type',b.answers->i.question_id::text,i.correct)) else '{}'::jsonb end order by i.ordinal)
 into items from public.practice_bundle_items i where i.bundle_id=b.id;
 return (to_jsonb(b)-'user_id'-'request_id') || jsonb_build_object('questions',items,'under_review',b.completed_at is null and not portal_private.bundle_ready(b.id,p_track));
end $$;

create or replace function public.practice_bundle_history(p_user uuid,p_track text,p_offset integer default 0) returns jsonb
language plpgsql set search_path='' as $$
declare items jsonb;
begin
 perform portal_private.bundle_guard(p_user,p_track);
 if p_offset<0 or p_offset>10000 then raise exception 'invalid_page'; end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc,t.id),'[]') into items from (
 select id,settings,parent_id,created_at,updated_at,completed_at,score,cardinality(question_ids) as total,
 (select count(*) from jsonb_each_text(answers) a where nullif(btrim(a.value),'') is not null) as answered
 from public.practice_bundles where user_id=p_user and track_id=p_track order by created_at desc,id limit 20 offset p_offset) t;
 return jsonb_build_object('items',items,'offset',p_offset);
end $$;

create or replace function public.practice_bundle_create(p_user uuid,p_track text,p_request uuid,p_settings jsonb,p_parent uuid default null) returns jsonb
language plpgsql set search_path='' as $$
declare ids uuid[]; bid uuid; wanted integer; available integer; selected_topics text[]; section_ text; level_ text; unseen_ boolean; original public.practice_bundles%rowtype;
begin
 perform portal_private.bundle_guard(p_user,p_track);
 if p_request is null then raise exception 'request_id_required'; end if;
 -- Serialize starts per student to make retries idempotent and apply the open-bundle cap.
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,6281));
 select id into bid from public.practice_bundles where user_id=p_user and request_id=p_request;
 if found then return public.practice_bundle_state(p_user,p_track,bid); end if;
 if (select count(*) from public.practice_bundles where user_id=p_user and completed_at is null)>=20 then raise exception 'finish_an_open_bundle_first'; end if;
 if p_parent is not null then
  select * into original from public.practice_bundles where id=p_parent and user_id=p_user and track_id=p_track and completed_at is not null;
  if not found then raise exception 'completed_bundle_required'; end if;
  ids:=original.question_ids; p_settings:=original.settings||jsonb_build_object('retake',true,'exclude_answered',false);
  if not portal_private.exam_content_ready(ids,p_track) or exists(select 1 from public.question_catalogue c where c.question_id=any(ids) and c.reserve) then raise exception 'question_content_under_review'; end if;
 else
  if jsonb_typeof(p_settings) is distinct from 'object' or coalesce(p_settings->>'count','') !~ '^[0-9]{1,3}$' then raise exception 'invalid_settings'; end if;
  wanted:=(p_settings->>'count')::int; section_:=nullif(p_settings->>'section',''); level_:=p_settings->>'difficulty';
  if wanted not between 1 and 100 or level_ not in ('easy','medium','hard','mixed') or level_ is null or jsonb_typeof(p_settings->'exclude_answered') is distinct from 'boolean' or jsonb_typeof(p_settings->'topics') is distinct from 'array' then raise exception 'invalid_settings'; end if;
  unseen_:=(p_settings->>'exclude_answered')::boolean;
  if jsonb_array_length(p_settings->'topics')>100 or exists(select 1 from jsonb_array_elements(p_settings->'topics') t where jsonb_typeof(t)<>'string') then raise exception 'invalid_topics'; end if;
  select array_agg(value) into selected_topics from jsonb_array_elements_text(p_settings->'topics');
  select array_agg(id),count(*) into ids,available from (
   select id from portal_private.bundle_pool(p_user,p_track) p
   where (section_ is null or p.section=section_) and (cardinality(selected_topics) is null or p.topic=any(selected_topics))
   and (level_='mixed' or p.difficulty=level_) and (not unseen_ or not p.answered)
   order by random() limit wanted) chosen;
  if available<wanted then return jsonb_build_object('error','not_enough_questions','available',available,'requested',wanted); end if;
 end if;
 -- Recheck selected rows at the point of creation; no held/reserved items may enter.
 if not portal_private.exam_content_ready(ids,p_track) then raise exception 'question_content_under_review'; end if;
 insert into public.practice_bundles(user_id,track_id,request_id,parent_id,settings,question_ids)
 values(p_user,p_track,p_request,p_parent,p_settings,ids) returning id into bid;
 insert into public.practice_bundle_items(bundle_id,question_id,ordinal,fingerprint,payload,correct,explanation)
 select bid,q.id,ord.n,md5(jsonb_build_array(q.stem,q.type,q.choices,q.assets,k.correct,k.explanation)::text),jsonb_build_object('id',q.id,'stem',q.stem,'topic',q.topic,'difficulty',q.difficulty,'type',q.type,'choices',q.choices,
 'assets',(select coalesce(jsonb_object_agg(a.key,a.value),'{}') from jsonb_each(coalesce(q.assets,'{}')) a where a.key=any(array['figure','figure_caption','figspec','html','svg','image','image_alt','passage_title','source_question','instructions','reference']))),k.correct,k.explanation
 from unnest(ids) with ordinality ord(id,n) join public.questions q on q.id=ord.id join public.question_keys k on k.question_id=q.id;
 return public.practice_bundle_state(p_user,p_track,bid);
end $$;

create or replace function public.practice_bundle_save(p_user uuid,p_track text,p_bundle uuid,p_revision integer,p_answers jsonb,p_position integer,p_submit boolean default false) returns jsonb
language plpgsql set search_path='' as $$
declare b public.practice_bundles%rowtype; score_ integer;
begin
 perform portal_private.bundle_guard(p_user,p_track);
 select * into b from public.practice_bundles where id=p_bundle and user_id=p_user and track_id=p_track for update;
 if not found then raise exception 'bundle_not_found'; end if;
 if b.completed_at is not null then return public.practice_bundle_state(p_user,p_track,p_bundle); end if;
 if p_revision is distinct from b.revision then
  if not p_submit and p_answers=b.answers and p_position=b.position then return jsonb_build_object('revision',b.revision,'updated_at',b.updated_at); end if;
  raise exception 'bundle_changed_elsewhere';
 end if;
 if not portal_private.bundle_ready(b.id,p_track) then raise exception 'question_content_under_review'; end if;
 if jsonb_typeof(p_answers) is distinct from 'object' or octet_length(p_answers::text)>40000 or p_position is null or p_position not between 0 and cardinality(b.question_ids)-1 then raise exception 'invalid_answers'; end if;
 if exists(select 1 from jsonb_each(p_answers) a where a.key<>all(select unnest(b.question_ids)::text) or jsonb_typeof(a.value)<>'string' or length(a.value#>>'{}')>250) then raise exception 'invalid_answers'; end if;
 if exists(select 1 from public.practice_bundle_items i where i.bundle_id=b.id and i.payload->>'type'='mcq'
 and nullif(btrim(p_answers->>i.question_id::text),'') is not null and not exists(select 1 from jsonb_array_elements(i.payload->'choices') c where c->>'key'=p_answers->>i.question_id::text)) then raise exception 'invalid_answers'; end if;
 if p_submit then
  if exists(select 1 from unnest(b.question_ids) qid where nullif(btrim(p_answers->>qid::text),'') is null) then raise exception 'answer_all_questions_or_save'; end if;
  -- Freeze grading against the version the learner actually answered.
  select count(*) into score_ from public.practice_bundle_items i where i.bundle_id=b.id and public.answer_matches(i.payload->>'type',p_answers->i.question_id::text,i.correct);
 end if;
 update public.practice_bundles set answers=p_answers,position=p_position,revision=revision+1,updated_at=now(),
 score=case when p_submit then score_ else null end,completed_at=case when p_submit then now() else null end where id=b.id;
 if p_submit then return public.practice_bundle_state(p_user,p_track,p_bundle); end if;
 return jsonb_build_object('revision',b.revision+1,'updated_at',now());
end $$;

revoke all on function portal_private.bundle_ready(uuid,text),portal_private.bundle_section(text,text),portal_private.bundle_guard(uuid,text),portal_private.bundle_answered(uuid),portal_private.bundle_pool(uuid,text),public.practice_bundle_catalog(uuid,text),public.practice_bundle_state(uuid,text,uuid),public.practice_bundle_history(uuid,text,integer),public.practice_bundle_create(uuid,text,uuid,jsonb,uuid),public.practice_bundle_save(uuid,text,uuid,integer,jsonb,integer,boolean) from public,anon,authenticated;
grant execute on function portal_private.bundle_ready(uuid,text),portal_private.bundle_section(text,text),portal_private.bundle_guard(uuid,text),portal_private.bundle_answered(uuid),portal_private.bundle_pool(uuid,text),public.practice_bundle_catalog(uuid,text),public.practice_bundle_state(uuid,text,uuid),public.practice_bundle_history(uuid,text,integer),public.practice_bundle_create(uuid,text,uuid,jsonb,uuid),public.practice_bundle_save(uuid,text,uuid,integer,jsonb,integer,boolean) to service_role;
