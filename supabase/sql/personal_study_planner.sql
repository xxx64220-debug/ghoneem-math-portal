begin;
alter table public.student_daily_objectives
 add column if not exists practice_exam_id uuid references public.exams(id),
 add column if not exists retest_exam_id uuid references public.exams(id),
 add column if not exists practice_note text not null default '',
 add column if not exists retest_note text not null default '',
 add column if not exists calculator_allowed boolean not null default true;
create policy planner_session on public.student_daily_objectives as restrictive for all to authenticated
 using ((select portal_private.current_session_allowed())) with check ((select portal_private.current_session_allowed()));
create policy planner_staff_read on public.student_daily_objectives for select to authenticated
 using (portal_private.staff_can_touch_track(track_id) and portal_private.staff_can_read_student(user_id));
create policy planner_staff_insert on public.student_daily_objectives for insert to authenticated
 with check (track_id in ('sat','est') and portal_private.staff_can_touch_track(track_id) and portal_private.staff_can_read_student(user_id) and exists(select 1 from public.enrollments e where e.user_id=student_daily_objectives.user_id and e.track_id=student_daily_objectives.track_id));
create policy planner_staff_update on public.student_daily_objectives for update to authenticated
 using (portal_private.staff_can_touch_track(track_id) and portal_private.staff_can_read_student(user_id))
 with check (track_id in ('sat','est') and portal_private.staff_can_touch_track(track_id) and portal_private.staff_can_read_student(user_id));
grant insert,update on public.student_daily_objectives to authenticated;
create table public.study_activity_progress (
 user_id uuid not null, track_id text not null, study_date date not null,
 activity text not null check(activity in ('lesson','practice','retest')),
 status text not null default 'pending' check(status in ('pending','completed','skipped')),
 primary key(user_id,track_id,study_date,activity),
 foreign key(user_id,study_date,track_id) references public.student_daily_objectives(user_id,study_date,track_id) on delete cascade
);
alter table public.study_activity_progress enable row level security;
revoke all on public.study_activity_progress from public,anon,authenticated;
grant select,insert,update on public.study_activity_progress to authenticated;
create policy planner_progress_session on public.study_activity_progress as restrictive for all to authenticated
 using ((select portal_private.current_session_allowed())) with check ((select portal_private.current_session_allowed()));
create policy planner_progress_read on public.study_activity_progress for select to authenticated
 using (user_id=(select auth.uid()) or (portal_private.staff_can_touch_track(track_id) and portal_private.staff_can_read_student(user_id)));
create policy planner_progress_insert on public.study_activity_progress for insert to authenticated with check(user_id=(select auth.uid()));
create policy planner_progress_update on public.study_activity_progress for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create index study_objectives_date_track on public.student_daily_objectives(track_id,study_date);
notify pgrst,'reload schema';
commit;
