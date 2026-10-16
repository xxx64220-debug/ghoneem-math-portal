-- Protect the parent cohort in the existing course-plan endpoint too.
do $guard$
declare src text;needle text:='perform portal_private.require_course_staff(old_.track_id,p_group);';
begin
 select pg_get_functiondef('portal_private.staff_save_group_plan(uuid,jsonb,bigint)'::regprocedure) into src;
 if strpos(src,needle)=0 or strpos(src,'default_cohort_protected')>0 then raise exception 'group_plan_changed_review_required';end if;
 execute replace(src,needle,needle||E'\n if p_group=public.default_group(old_.track_id) then raise exception ''default_cohort_protected'';end if;');
end $guard$;
