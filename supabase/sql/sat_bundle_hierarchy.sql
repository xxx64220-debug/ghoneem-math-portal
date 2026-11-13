-- SAT hierarchy upgrade to the existing Practice Bundles service. NOT APPLIED.
-- Existing exam, assignment, Today, revision and bundle records are read-only here.
begin;
do $guard$ begin
 if md5(pg_get_functiondef('portal_private.bundle_section(text,text)'::regprocedure))<>'e8590a1ef0003f28e6d8c2404d3dd397' then raise exception 'Changed since review: portal_private.bundle_section(text,text)'; end if;
 if md5(pg_get_functiondef('portal_private.bundle_pool(uuid,text)'::regprocedure))<>'4e851ed6defdd55aca50380e253f32f9' then raise exception 'Changed since review: portal_private.bundle_pool(uuid,text)'; end if;
 if md5(pg_get_functiondef('public.practice_bundle_catalog(uuid,text)'::regprocedure))<>'80db5e6ce0d09fb0de9e07d46b575fdc' then raise exception 'Changed since review: public.practice_bundle_catalog(uuid,text)'; end if;
 if md5(pg_get_functiondef('public.practice_bundle_create(uuid,text,uuid,jsonb,uuid)'::regprocedure))<>'22688d9945e05ac17ec00db90b906eb7' then raise exception 'Changed since review: public.practice_bundle_create(uuid,text,uuid,jsonb,uuid)'; end if;
end $guard$;
-- Lightweight metadata: avoid decompressing diagrams for every filter/count request.
create table portal_private.bundle_subtopics (
 question_id uuid primary key references public.questions(id) on delete cascade on update cascade,
 subtopic text
);
alter table portal_private.bundle_subtopics enable row level security;
revoke all on portal_private.bundle_subtopics from public,anon,authenticated;
grant select on portal_private.bundle_subtopics to service_role;
create function portal_private.refresh_bundle_subtopic() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.track_id='sat' then
  insert into portal_private.bundle_subtopics(question_id,subtopic)
  values(new.id,nullif(nullif(left(btrim(new.assets->>'lesson_subtopic'),500),''),new.topic))
  on conflict(question_id) do update set subtopic=excluded.subtopic;
 else delete from portal_private.bundle_subtopics where question_id=new.id;
 end if;
 return new;
end $$;
revoke all on function portal_private.refresh_bundle_subtopic() from public,anon,authenticated;
create trigger refresh_bundle_subtopic after insert or update of id,track_id,topic,assets on public.questions
 for each row execute function portal_private.refresh_bundle_subtopic();
insert into portal_private.bundle_subtopics(question_id,subtopic)
 select id,nullif(nullif(left(btrim(assets->>'lesson_subtopic'),500),''),topic) from public.questions where track_id='sat';

create or replace function portal_private.bundle_section(p_track text,p_topic text) returns text
language sql immutable set search_path='' as $$
 select case
 when p_track='sat' then case
  when p_topic=any(array['Algebraic expressions and equations','Linear functions and slope','Systems of equations','Inequalities and absolute value','Inequalities','Systems of inequalities','Absolute value','Coordinate geometry']) then 'Algebra'
  when p_topic=any(array['Quadratics and polynomials','Polynomial division and remainder','Functions and transformations','Exponents, radicals and growth','Polynomials and rational expressions','Radicals and inequalities']) then 'Advanced Math'
  when p_topic=any(array['Ratios, percentages and unit conversion','Statistics and data analysis','Probability and conditional probability','Statistics and data','Scatterplots and lines of best fit']) then 'Problem-Solving and Data Analysis'
  when p_topic=any(array['Triangles and similarity','Trigonometry','Angles and polygons','Circles','Area and perimeter','Volume and surface area','Angles and lines','Plane geometry','Area and volume']) then 'Geometry and Trigonometry'
  else null end
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
 where q.track_id=p_track and (p_track<>'sat' or portal_private.bundle_section(p_track,q.topic) is not null) and coalesce(
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
 select coalesce(jsonb_agg(to_jsonb(t) order by section,topic,subtopic,difficulty),'[]') into items from (
 select p.section,p.topic,p.difficulty,case when p_track='sat' then coalesce(s.subtopic,'General lesson practice') else null end as subtopic,count(*)::int as total,count(*) filter(where not answered)::int as unseen
 from portal_private.bundle_pool(p_user,p_track) p left join portal_private.bundle_subtopics s on s.question_id=p.id
 group by p.section,p.topic,p.difficulty,case when p_track='sat' then coalesce(s.subtopic,'General lesson practice') else null end) t;
 return jsonb_build_object('track',p_track,'topics',items,'max_questions',100,'subtopics_supported',p_track='sat',
 'test_account',(select is_test from public.profiles where id=p_user),
 'account_name',(select full_name from public.profiles where id=p_user));
end $$;

create or replace function public.practice_bundle_create(p_user uuid,p_track text,p_request uuid,p_settings jsonb,p_parent uuid default null) returns jsonb
language plpgsql set search_path='' as $$
declare ids uuid[]; bid uuid; wanted integer; available integer; selected_topics text[]; section_ text; level_ text; unseen_ boolean; original public.practice_bundles%rowtype; subtopics_ jsonb:=coalesce(p_settings->'subtopics','[]');
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
  if jsonb_typeof(subtopics_) is distinct from 'array' then raise exception 'invalid_subtopics'; end if;
  if jsonb_array_length(subtopics_)>500 or (p_track<>'sat' and jsonb_array_length(subtopics_)>0)
   or exists(select 1 from jsonb_array_elements(subtopics_) x where jsonb_typeof(x)<>'object'
    or jsonb_typeof(x->'topic') is distinct from 'string' or jsonb_typeof(x->'subtopic') is distinct from 'string'
    or length(x->>'topic') not between 1 and 250 or length(x->>'subtopic') not between 1 and 500)
  then raise exception 'invalid_subtopics'; end if;
  select array_agg(value) into selected_topics from jsonb_array_elements_text(p_settings->'topics');
  select array_agg(id),count(*) into ids,available from (
   select p.id from portal_private.bundle_pool(p_user,p_track) p
   left join portal_private.bundle_subtopics s on s.question_id=p.id
   where (section_ is null or p.section=section_) and ((cardinality(selected_topics) is null and jsonb_array_length(subtopics_)=0) or p.topic=any(selected_topics)
    or exists(select 1 from jsonb_array_elements(subtopics_) x where x->>'topic'=p.topic and x->>'subtopic'=coalesce(s.subtopic,'General lesson practice')))
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
-- Reassert existing service-only access. No new endpoint or public key access.
revoke all on function portal_private.bundle_section(text,text),portal_private.bundle_pool(uuid,text),public.practice_bundle_catalog(uuid,text),public.practice_bundle_create(uuid,text,uuid,jsonb,uuid) from public,anon,authenticated;
grant execute on function portal_private.bundle_section(text,text),portal_private.bundle_pool(uuid,text),public.practice_bundle_catalog(uuid,text),public.practice_bundle_create(uuid,text,uuid,jsonb,uuid) to service_role;
commit;
