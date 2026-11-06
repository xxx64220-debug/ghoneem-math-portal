create table public.student_daily_objectives (
  user_id uuid not null references public.profiles(id) on delete cascade,
  track_id text not null references public.tracks(id) on delete cascade,
  study_date date not null,
  title text not null,
  instructions text not null,
  time_budget text not null,
  lesson text not null default '',
  destination text not null check (destination in ('practice','mistakes','full_exam')),
  primary key (user_id, study_date, track_id)
);
alter table public.student_daily_objectives enable row level security;
revoke all on public.student_daily_objectives from public, anon, authenticated;
grant select on public.student_daily_objectives to authenticated;
create policy read_own_objectives on public.student_daily_objectives
  for select to authenticated using (user_id = (select auth.uid()));
