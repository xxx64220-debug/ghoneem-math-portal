begin;
create or replace function public.staff_can_read_attempt(p_attempt uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from attempts a join exams e on e.id=a.exam_id where a.id=p_attempt and staff_can_touch_track(e.track_id) and staff_can_read_student(a.user_id));
$$;
revoke execute on function public.staff_can_read_attempt(uuid) from public,anon;
grant execute on function public.staff_can_read_attempt(uuid) to authenticated,service_role;
drop policy answers_read on attempt_answers;
create policy answers_read on attempt_answers for select to authenticated using(attempt_is_mine(attempt_id,auth.uid()) or staff_can_read_attempt(attempt_id));
drop policy results_read on attempt_results;
create policy results_read on attempt_results for select to authenticated using((attempt_review_open(attempt_id,auth.uid()) and attempt_is_mine(attempt_id,auth.uid())) or staff_can_read_attempt(attempt_id));
drop policy assignments_read on assignments;
create policy assignments_read on assignments for select to authenticated using(
 (is_enrolled(auth.uid(),exam_track(exam_id)) and (user_id=auth.uid() or in_group(group_id,auth.uid())))
 or (staff_can_touch_track(exam_track(exam_id)) and (is_admin() or (user_id is not null and staff_can_read_student(user_id)) or exists(select 1 from groups g where g.id=group_id and g.instructor_id=auth.uid()))));
commit;
