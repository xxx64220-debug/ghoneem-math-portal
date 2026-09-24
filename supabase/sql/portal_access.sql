begin;
alter table public.profiles add column if not exists email text;
update profiles p set email=u.email from auth.users u where u.id=p.id and p.email is distinct from u.email;
create or replace function public.staff_can_read_student(p_user uuid) returns boolean language sql stable security definer set search_path=public as $$
 select is_admin() or (jwt_role()='instructor' and exists(select 1 from group_members gm join groups g on g.id=gm.group_id join instructor_tracks it on it.track_id=g.track_id and it.user_id=auth.uid() where gm.user_id=p_user and g.instructor_id=auth.uid()));
$$;
revoke execute on function public.staff_can_read_student(uuid) from public,anon;
grant execute on function public.staff_can_read_student(uuid) to authenticated,service_role;
drop policy profiles_self_read on profiles;
create policy profiles_self_read on profiles for select to authenticated using(id=auth.uid() or staff_can_read_student(id));
drop policy enrollments_read on enrollments;
create policy enrollments_read on enrollments for select to authenticated using(user_id=auth.uid() or (staff_can_touch_track(track_id) and staff_can_read_student(user_id)));
drop policy tracks_read on tracks;
create policy tracks_read on tracks for select to authenticated using(staff_can_touch_track(id) or is_enrolled(auth.uid(),id));
drop policy groups_read on groups;
create policy groups_read on groups for select to authenticated using(is_admin() or (instructor_id=auth.uid() and staff_can_touch_track(track_id)) or in_group(id,auth.uid()));
drop policy group_members_read on group_members;
create policy group_members_read on group_members for select to authenticated using(user_id=auth.uid() or staff_can_read_student(user_id));
drop policy attempts_read on attempts;
create policy attempts_read on attempts for select to authenticated using((user_id=auth.uid() and is_enrolled(auth.uid(),exam_track(exam_id))) or (staff_can_touch_track(exam_track(exam_id)) and staff_can_read_student(user_id)));
create or replace function public.attempt_is_mine(p_attempt uuid,p_user uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from attempts a join exams e on e.id=a.exam_id where a.id=p_attempt and a.user_id=p_user and is_enrolled(p_user,e.track_id));
$$;
create or replace view public.roster with(security_invoker=true) as
 select p.id as user_id,p.full_name,p.role,p.status,p.email::varchar(255) as email,
 coalesce(string_agg(e.track_id,', ' order by e.track_id) filter(where e.status='active'),'(none)') as tracks,
 (select count(*) from attempts a where a.user_id=p.id and a.status in ('graded','expired')) as exams_taken,
 (select max(a.submitted_at) from attempts a where a.user_id=p.id) as last_active
 from profiles p left join enrollments e on e.user_id=p.id where is_staff() and staff_can_read_student(p.id)
 group by p.id,p.full_name,p.role,p.status,p.email;
create or replace view public.results_feed with(security_invoker=true) as
 select a.id as attempt_id,a.user_id,p.full_name,e.track_id,e.title as exam,a.status,a.score,a.total,a.scaled_score,
 round(100.0*a.score/nullif(a.total,0)) as percent,a.time_used,a.submitted_at,e.is_full_length,e.id as exam_id
 from attempts a join exams e on e.id=a.exam_id join profiles p on p.id=a.user_id
 where a.status in ('graded','expired') and staff_can_touch_track(e.track_id) order by a.submitted_at desc;
commit;
