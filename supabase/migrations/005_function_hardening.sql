-- =====================================================================
--  SAT & EST EXAM PORTAL  —  005  FUNCTION HARDENING
--  Abdelrahman Ghoneem | 01116004434
--
--  WHY THIS EXISTS
--  Postgres grants EXECUTE on every new function to PUBLIC by default.
--  Combined with SECURITY DEFINER, that made the whole attempt engine
--  callable straight from the browser through PostgREST's /rpc/ route.
--  Three confirmed escalations before this migration:
--
--    rpc/grant_retake     a student granted themselves unlimited retakes
--    rpc/start_attempt    a student burned ANOTHER student's single attempt
--    rpc/my_exams         a student read another student's exam list + scores
--
--  RLS did not stop any of them: SECURITY DEFINER runs as the owner, so
--  the policies were never consulted. The fix is EXECUTE privilege, not
--  more policies.
--
--  Run after 004_seed.sql. Safe to re-run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Take EXECUTE away from everyone, on everything in public.
-- ---------------------------------------------------------------------
revoke execute on all functions in schema public from public;
revoke execute on all functions in schema public from anon;
revoke execute on all functions in schema public from authenticated;

-- Future functions inherit the same default, so a later migration cannot
-- silently reopen the hole.
alter default privileges in schema public revoke execute on functions from public;

-- ---------------------------------------------------------------------
-- 2. Give it back only where a signed-in user genuinely needs it.
--
--    These thirteen are the ones RLS policy expressions call. A policy is
--    evaluated as the querying user, so without EXECUTE here every student
--    query fails outright. All are read-only booleans or single-column
--    lookups: none of them mutates, and none returns question content.
-- ---------------------------------------------------------------------
grant execute on function
  public.attempt_is_mine(uuid, uuid),
  public.attempt_live_for(uuid, uuid),
  public.attempt_review_open(uuid, uuid),
  public.attempt_track(uuid),
  public.exam_assigned_to(uuid, uuid),
  public.exam_track(uuid),
  public.group_track(uuid),
  public.in_group(uuid, uuid),
  public.is_admin(),
  public.is_enrolled(uuid, text),
  public.is_staff(),
  public.question_track(uuid),
  public.staff_can_touch_track(text)
to authenticated;

-- ---------------------------------------------------------------------
-- 3. The Edge Functions hold the service-role key. They keep everything.
-- ---------------------------------------------------------------------
grant execute on all functions in schema public to service_role;

-- ---------------------------------------------------------------------
-- 4. The auth hook is called by GoTrue, not by a user.
--    Ignored on a local database where that role does not exist.
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    execute 'grant execute on function public.custom_access_token_hook(jsonb)
             to supabase_auth_admin';
    execute 'revoke execute on function public.custom_access_token_hook(jsonb)
             from authenticated, anon, public';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 5. Belt and braces: name the dangerous ones explicitly, so a reader can
--    see at a glance that no client role can reach them.
-- ---------------------------------------------------------------------
do $$
declare fn text;
begin
  foreach fn in array array[
    'start_attempt(uuid,uuid)',
    'submit_attempt(uuid,uuid)',
    'grade_attempt(uuid)',
    'grant_retake(uuid,uuid,uuid,text,timestamptz)',
    'sweep_expired_attempts()',
    'finalize_expired_for(uuid,uuid)',
    'attempt_payload(uuid,uuid)',
    'attempt_review(uuid,uuid)',
    'my_tracks(uuid)',
    'my_exams(uuid,text)',
    'scale_score(text,integer,integer)',
    'student_assignment_for(uuid,uuid)'
  ] loop
    if exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.oid::regprocedure::text = 'public.' || fn
    ) then
      execute format('revoke execute on function public.%s from public, anon, authenticated', fn);
      execute format('grant  execute on function public.%s to service_role', fn);
    end if;
  end loop;
end $$;
