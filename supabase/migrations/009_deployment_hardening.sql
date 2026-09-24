create or replace view public.roster as
  select p.id as user_id, p.full_name, p.role, p.status,
         u.email,
         coalesce(string_agg(e.track_id, ', ' order by e.track_id)
                  filter (where e.status = 'active'), '(none)') as tracks,
         (select count(*) from public.attempts a
           where a.user_id = p.id and a.status in ('graded','expired')) as exams_taken,
         (select max(a.submitted_at) from public.attempts a where a.user_id = p.id) as last_active
    from public.profiles p
    left join auth.users u on u.id = p.id
    left join public.enrollments e on e.user_id = p.id
   where public.is_staff() and (public.is_admin() or exists (select 1 from public.group_members gm join public.groups g on g.id=gm.group_id where gm.user_id=p.id and g.instructor_id=auth.uid()))
   group by p.id, p.full_name, p.role, p.status, u.email;


revoke all on public.roster from anon;
revoke all on public.sat_bank_by_lesson, public.exam_overview, public.results_feed, public.question_difficulty, public.student_by_lesson from anon;
alter view public.sat_bank_by_lesson set (security_invoker=true);
alter view public.exam_overview set (security_invoker=true);
alter view public.results_feed set (security_invoker=true);
alter view public.question_difficulty set (security_invoker=true);
alter view public.student_by_lesson set (security_invoker=true);
do $$ declare f regprocedure; begin
for f in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('norm_num','answer_matches','legacy_probe','legacy_import')
loop execute format('alter function %s set search_path=public,extensions',f); end loop; end $$;