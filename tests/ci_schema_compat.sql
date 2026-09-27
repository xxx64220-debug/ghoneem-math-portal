-- LOCAL CI ONLY. Never apply this file to hosted Supabase.
-- Current checked-in support SQL consumes assessment_type, but the repository
-- does not yet contain the migration that introduces the column.
alter table public.exams
  add column if not exists assessment_type text not null default 'lesson_exam';
