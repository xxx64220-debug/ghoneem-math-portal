-- Remove only the arbitrary lesson-count limit; preserve authorization, parent-track,
-- stale-edit and five-eligible-question checks. Installation rewrites no group data.
do $patch$
declare f regprocedure;src text;needle text:=' or jsonb_array_length(p_data->''daily_lessons'')>10';
begin
 foreach f in array array['portal_private.staff_save_group_plan(uuid,jsonb,bigint)'::regprocedure,'portal_private.staff_save_teaching_group(jsonb,text)'::regprocedure] loop
  select pg_get_functiondef(f) into src;
  if strpos(src,needle)=0 then raise exception 'group_lesson_validator_changed_review_required';end if;
  execute replace(src,needle,'');
 end loop;
end $patch$;
