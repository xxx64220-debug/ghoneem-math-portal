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
end $function$;

CREATE OR REPLACE FUNCTION public.final_revision_state(p_user uuid, p_track text, p_session uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

CREATE OR REPLACE FUNCTION public.finalize_expired_for(p_user uuid, p_exam uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid; v_n integer := 0;
begin
  for v_id in
    select id from public.attempts
     where user_id = p_user and exam_id = p_exam
       and status = 'in_progress' and clock_timestamp() >= deadline_at for update skip locked
  loop
    update public.attempts
       set status = 'expired', submitted_at = deadline_at
     where id = v_id;
    perform public.grade_attempt(v_id);
    update public.attempts set status = 'expired' where id = v_id;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $function$;

CREATE OR REPLACE FUNCTION public.is_enrolled(p_user uuid, p_track text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
 select exists(select 1 from enrollments e join profiles p on p.id=e.user_id join tracks t on t.id=e.track_id where e.user_id=p_user and e.track_id=p_track and e.status='active' and p.status='active' and t.is_active);
$function$;

CREATE OR REPLACE FUNCTION public.revision_question_fingerprint(p_stem text, p_choices jsonb, p_assets jsonb, p_correct jsonb, p_explanation text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
 select md5(jsonb_build_array(
  p_stem,p_choices,
  coalesce(p_assets,'{}'::jsonb)-'curriculum_lesson'-'lesson_subtopic'-'lesson_original_topic'-'lesson_taxonomy_version',
  p_correct,p_explanation
 )::text)
$function$;

CREATE OR REPLACE FUNCTION public.student_assignment_for(p_exam uuid, p_user uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select a.id
    from public.assignments a
    join public.exams e on e.id = a.exam_id
   where a.exam_id = p_exam
     and e.is_published
     and public.is_enrolled(p_user, e.track_id)
     and (a.user_id = p_user
          or exists (select 1 from public.group_members gm
                      where gm.group_id = a.group_id and gm.user_id = p_user))
     and (a.open_at  is null or now() >= a.open_at)
     and (a.close_at is null or now() <= a.close_at)
   order by a.close_at nulls last
   limit 1;
$function$;
