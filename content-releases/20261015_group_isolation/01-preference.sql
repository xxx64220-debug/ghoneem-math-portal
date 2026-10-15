-- Applied separately before the new interface. No existing selection/history is rewritten.
alter table public.enrollments add column daily_group_id uuid references public.groups(id) on delete set null;
notify pgrst,'reload schema';
