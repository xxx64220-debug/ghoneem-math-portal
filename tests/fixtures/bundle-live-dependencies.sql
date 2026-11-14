CREATE OR REPLACE FUNCTION public.norm_num(t text)
 RETURNS numeric
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'extensions'
AS $function$
declare s text; parts text[]; n numeric;
begin
  if t is null then return null; end if;
  s := btrim(t);
  s := replace(replace(replace(s, u&'\2212', '-'), u&'\FF0D', '-'), ' ', '');
  s := replace(s, ',', '');
  if s = '' then return null; end if;
  if position('/' in s) > 0 then
    parts := string_to_array(s, '/');
    if array_length(parts,1) <> 2 then return null; end if;
    begin
      if parts[2]::numeric = 0 then return null; end if;
      return parts[1]::numeric / parts[2]::numeric;
    exception when others then return null; end;
  end if;
  begin n := s::numeric; exception when others then return null; end;
  return n;
end $function$
;
CREATE OR REPLACE FUNCTION public.answer_matches(p_type text, p_response jsonb, p_correct jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'extensions'
AS $function$
declare
 r text; rn numeric; c text; body text; lo_text text; hi_text text;
 lo numeric; hi numeric; accepted numrange;
begin
 if p_response is null or p_correct is null or p_correct='null'::jsonb or jsonb_typeof(p_correct)='object' then return false; end if;
 r=btrim(p_response #>> '{}');
 if r is null or r='' then return false; end if;
 if p_type='mcq' then
  return exists(select 1 from jsonb_array_elements_text(
   case when jsonb_typeof(p_correct)='array' then p_correct else jsonb_build_array(p_correct) end) item
   where upper(r)=upper(btrim(item)));
 end if;
 rn=public.norm_num(r);
 for c in select value from jsonb_array_elements_text(
  case when jsonb_typeof(p_correct)='array' then p_correct else jsonb_build_array(p_correct #>> '{}') end)
 loop
  c=btrim(c);
  if p_type='grid_in' and left(c,1) in ('[','(') and position(',' in c)>0 then
   -- An interval-shaped key must not fall back to literal-string acceptance.
   if right(c,1) not in (']',')') or rn is null or rn::text in ('NaN','Infinity','-Infinity') then continue; end if;
   body=substr(c,2,length(c)-2);
   if length(body)-length(replace(body,',',''))<>1 then continue; end if;
   lo_text=lower(btrim(replace(split_part(body,',',1),'−','-')));
   hi_text=lower(btrim(replace(split_part(body,',',2),'−','-')));
   lo=null; hi=null;
   if lo_text not in ('','-∞','-infinity') then
    lo=public.norm_num(lo_text);
    if lo is null or lo::text in ('NaN','Infinity','-Infinity') then continue; end if;
   end if;
   if hi_text not in ('','∞','+∞','infinity','+infinity') then
    hi=public.norm_num(hi_text);
    if hi is null or hi::text in ('NaN','Infinity','-Infinity') then continue; end if;
   end if;
   begin
    accepted=numrange(lo,hi,left(c,1)||right(c,1));
    if rn <@ accepted then return true; end if;
   exception when data_exception then
    continue;
   end;
  elsif upper(c)=upper(r) or (rn is not null and public.norm_num(c) is not null and abs(public.norm_num(c)-rn)<0.000001) then
   return true;
  end if;
 end loop;
 return false;
end $function$
;
CREATE OR REPLACE FUNCTION portal_private.question_eligible(p_q questions, p_k question_keys, p_track text, p_daily boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare visual_ boolean; figures_ jsonb; a_ jsonb; needs_visual_ boolean; blank_choices_ boolean := false;
begin
 -- Detoast once into the function context, without converting image payloads to text.
 a_ := case when jsonb_typeof(p_q.assets)='object' then p_q.assets || '{}'::jsonb else '{}'::jsonb end;
 if p_q.id is null or p_q.track_id is distinct from p_track or p_k.question_id is distinct from p_q.id
  or nullif(btrim(p_q.stem),'') is null or nullif(btrim(p_k.explanation),'') is null
  or nullif(btrim((a_->>'release_hold_reason')),'') is not null
  or lower(coalesce((a_->>'bank_removed'),'false'))='true'
  or coalesce(p_k.correct->>'void','false')='true'
 then return false; end if;
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
  blank_choices_ := exists(select 1 from jsonb_array_elements(p_q.choices) c where
   nullif(btrim(c->>'text'),'') is null or c->>'text' ilike '%in the original question%');
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
   or nullif((a_->>'verified_release'),'') is null
   or exists(select 1 from jsonb_array_elements(p_q.choices) c where nullif(btrim(c->>'text'),'') is null
    or c->>'text' ilike '%in the original question%') then return false; end if;
 end if;
 -- A figure affects eligibility only when required or when it supplies choice text.
 -- Avoid parsing/base64-validating large optional images for ordinary text items.
 needs_visual_ := lower(coalesce((a_->>'figure_required'),'false'))='true' or blank_choices_;
 if needs_visual_ then

 figures_:=case jsonb_typeof((a_->'figure')) when 'array' then (a_->'figure')
  when 'string' then jsonb_build_array((a_->'figure')) else '[]'::jsonb end;
 visual_:=exists(select 1 from jsonb_array_elements_text(figures_) f where
  f ~ '^https://' or f ~ '^data:image/(png|jpeg|jpg|webp|gif|svg\+xml);base64,[A-Za-z0-9+/=[:space:]]+$')
  or coalesce((a_->>'image'),'') ~ '^https://'
  or nullif(btrim((a_->>'svg')),'') is not null
  or nullif(btrim((a_->>'html')),'') is not null
  or (jsonb_typeof((a_->'figspec'))='object' and (a_->'figspec')<>'{}'::jsonb);
 visual_:=coalesce(visual_,false);
 if not visual_ then return false; end if;
 end if;
 return true;
end $function$
;
CREATE OR REPLACE FUNCTION portal_private.is_enrolled(p_user uuid, p_track text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
 select exists(select 1 from public.enrollments e join public.profiles p on p.id=e.user_id join public.tracks t on t.id=e.track_id
 where e.user_id=p_user and e.track_id=p_track and e.status='active' and p.status='active' and p.role='student' and t.is_active
 and (e.starts_at is null or e.starts_at<=now()) and (e.ends_at is null or now()<e.ends_at));
$function$
;
CREATE OR REPLACE FUNCTION portal_private.exam_content_ready(p_ids uuid[], p_track text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
 select coalesce(cardinality(p_ids),0) between 1 and 200
 and (select count(distinct id) from unnest(p_ids) id)=cardinality(p_ids)
 and (select count(*) from questions q join question_keys k on k.question_id=q.id
  where q.id=any(p_ids) and portal_private.question_eligible(q,k,p_track,false))=cardinality(p_ids)
$function$
;
create function public.is_enrolled(p_user uuid,p_track text) returns boolean language sql as $$select portal_private.is_enrolled(p_user,p_track)$$;
