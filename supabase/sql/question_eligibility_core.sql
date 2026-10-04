-- A structural eligibility check, not mathematical certification.
create schema if not exists portal_private;
create or replace function portal_private.question_eligible(
 p_q public.questions,p_k public.question_keys,p_track text,p_daily boolean default false
) returns boolean language plpgsql immutable security invoker set search_path=public,pg_temp as $$
declare visual_ boolean; figures_ jsonb;
begin
 if p_q.id is null or p_q.track_id is distinct from p_track or p_k.question_id is distinct from p_q.id
  or nullif(btrim(p_q.stem),'') is null or nullif(btrim(p_k.explanation),'') is null
  or nullif(btrim(p_q.assets->>'release_hold_reason'),'') is not null
  or lower(coalesce(p_q.assets->>'bank_removed','false'))='true'
  or coalesce(p_k.correct->>'void','false')='true'
 then return false; end if;
 figures_:=case jsonb_typeof(p_q.assets->'figure') when 'array' then p_q.assets->'figure'
  when 'string' then jsonb_build_array(p_q.assets->'figure') else '[]'::jsonb end;
 visual_:=exists(select 1 from jsonb_array_elements_text(figures_) f where
  f ~ '^https://' or f ~ '^data:image/(png|jpeg|jpg|webp|gif|svg\+xml);base64,[A-Za-z0-9+/=[:space:]]+$')
  or coalesce(p_q.assets->>'image','') ~ '^https://'
  or nullif(btrim(p_q.assets->>'svg'),'') is not null
  or nullif(btrim(p_q.assets->>'html'),'') is not null
  or (jsonb_typeof(p_q.assets->'figspec')='object' and p_q.assets->'figspec'<>'{}'::jsonb);
 visual_:=coalesce(visual_,false);
 if lower(coalesce(p_q.assets->>'figure_required','false'))='true' and not visual_ then return false; end if;
 if p_q.type='mcq' then
  if jsonb_typeof(p_q.choices) is distinct from 'array' then return false; end if;
  if jsonb_array_length(p_q.choices) not between 2 and 8
   or exists(select 1 from jsonb_array_elements(p_q.choices) c where nullif(btrim(c->>'key'),'') is null)
   or (select count(distinct c->>'key') from jsonb_array_elements(p_q.choices) c)<>jsonb_array_length(p_q.choices)
  then return false; end if;
  if jsonb_typeof(p_k.correct)='string' then
   if not exists(select 1 from jsonb_array_elements(p_q.choices) c where c->>'key'=p_k.correct#>>'{}') then return false; end if;
  elsif jsonb_typeof(p_k.correct)='array' then
   if jsonb_array_length(p_k.correct)=0 or exists(select 1 from jsonb_array_elements(p_k.correct) a
    where jsonb_typeof(a)<>'string' or not exists(select 1 from jsonb_array_elements(p_q.choices) c where c->>'key'=a#>>'{}')) then return false; end if;
  else return false; end if;
  if not visual_ and exists(select 1 from jsonb_array_elements(p_q.choices) c where
   nullif(btrim(c->>'text'),'') is null or c->>'text' ilike '%in the original question%') then return false; end if;
 elsif p_q.type='grid_in' then
  if jsonb_typeof(p_k.correct) in ('string','number') then
   if nullif(btrim(p_k.correct#>>'{}'),'') is null then return false; end if;
  elsif jsonb_typeof(p_k.correct)='array' then
   if jsonb_array_length(p_k.correct)=0 or exists(select 1 from jsonb_array_elements(p_k.correct) a
    where jsonb_typeof(a) not in ('string','number') or nullif(btrim(a#>>'{}'),'') is null) then return false; end if;
  else return false; end if;
 else return false; end if;
 if p_daily then
  if p_q.type<>'mcq' or jsonb_typeof(p_k.correct)<>'string' or jsonb_array_length(p_q.choices)<4
   or nullif(p_q.assets->>'verified_release','') is null
   or exists(select 1 from jsonb_array_elements(p_q.choices) c where nullif(btrim(c->>'text'),'') is null
    or c->>'text' ilike '%in the original question%') then return false; end if;
 end if;
 return true;
end $$;
revoke all on function portal_private.question_eligible(public.questions,public.question_keys,text,boolean) from public,anon,authenticated;
grant usage on schema portal_private to service_role;
grant execute on function portal_private.question_eligible(public.questions,public.question_keys,text,boolean) to service_role;

create or replace function portal_private.exam_content_ready(p_ids uuid[],p_track text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(cardinality(p_ids),0) between 1 and 200
 and (select count(distinct id) from unnest(p_ids) id)=cardinality(p_ids)
 and (select count(*) from questions q join question_keys k on k.question_id=q.id
  where q.id=any(p_ids) and portal_private.question_eligible(q,k,p_track,false))=cardinality(p_ids)
$$;
revoke all on function portal_private.exam_content_ready(uuid[],text) from public,anon,authenticated;
grant execute on function portal_private.exam_content_ready(uuid[],text) to service_role;

create or replace function portal_private.guard_exam_content() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.is_published and not portal_private.exam_content_ready(new.question_ids,new.track_id)
 then raise exception 'exam_content_under_review'; end if;
 return new;
end $$;
revoke all on function portal_private.guard_exam_content() from public,anon,authenticated;
drop trigger if exists guard_published_exam_content on public.exams;
create trigger guard_published_exam_content before insert or update of question_ids,track_id,is_published
 on public.exams for each row execute function portal_private.guard_exam_content();
