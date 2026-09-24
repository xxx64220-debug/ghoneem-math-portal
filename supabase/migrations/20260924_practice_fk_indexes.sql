-- Cover new foreign keys and notebook lookups without widening client access.
create index if not exists practice_notebook_question_idx on public.practice_notebook(question_id);
create index if not exists practice_drills_track_idx on public.practice_drills(track_id);
