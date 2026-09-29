-- Apply after fair_exam_keys.sql. Numeric grid-in keys may be interval strings,
-- e.g. (5, ∞), (1, 2), [-2, 3), or arrays of such accepted intervals.
-- Students submit one finite number (decimal or fraction), never the interval.
-- Existing scalar/array MCQ and exact numeric keys retain their behavior.
-- No attempts are regraded and no question content is changed by this script.
create or replace function public.answer_matches(p_type text,p_response jsonb,p_correct jsonb)
returns boolean language plpgsql immutable set search_path=public,extensions as $$
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
end $$;
