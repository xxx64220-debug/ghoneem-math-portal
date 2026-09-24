-- =====================================================================
--  000  PRE-FLIGHT CHECK  —  run this FIRST, before anything else.
--  Read-only. Creates nothing permanent, changes nothing.
--  Works on a brand-new project and on one that already has the old portal.
--  Abdelrahman Ghoneem | 01116004434
-- =====================================================================

create or replace function pg_temp.preflight()
returns table(section text, object text, status text)
language plpgsql as $$
declare
  t     text;
  n     bigint;
  names text[] := array[
    'tracks','enrollments','profiles','groups','group_members',
    'instructor_tracks','questions','question_keys','exams',
    'assignments','attempts','attempt_answers','attempt_results',
    'retake_grants','device_sessions','audit_log'];
begin
  section := '1. NAMES THE NEW SCHEMA NEEDS'; object := ''; status := '';
  return next;

  foreach t in array names loop
    section := '';
    object  := t;
    status  := case when to_regclass('public.' || t) is null
                    then 'free'
                    else '*** ALREADY EXISTS - read the note below ***' end;
    return next;
  end loop;

  section := '2. OLD PORTAL DATA'; object := ''; status := ''; return next;

  section := '';
  object  := 'site_content';
  if to_regclass('public.site_content') is null then
    status := 'not here - if this is a NEW project, run 006a to stage the bank';
  else
    -- dynamic, because a plain subquery would fail to parse when the
    -- table is absent, which is the whole case this check exists for
    execute 'select count(*) from public.site_content' into n;
    status := 'present, ' || n || ' row(s) - 001-005 will not touch it';
  end if;
  return next;

  section := '3. VERDICT'; object := ''; status := ''; return next;
  section := '';
  object  := 'safe to run 001?';
  if exists (select 1 from unnest(names) x where to_regclass('public.' || x) is not null) then
    status := 'NO - rename the clashing table(s) first, see note';
  else
    status := 'YES - nothing clashes, run 001 next';
  end if;
  return next;
end $$;

select * from pg_temp.preflight();

-- ---------------------------------------------------------------------
--  IF SOMETHING CLASHED
--
--  Most likely device_sessions, which the old portal's device-limit system
--  already owns. Migration 001 uses CREATE TABLE IF NOT EXISTS, so it would
--  leave the old table in place and then 003 would attach the new policies
--  to the wrong shape.
--
--  Fix before running 001: open 001_schema.sql and 003_policies.sql in
--  Notepad and Replace All
--      device_sessions   ->   portal_device_sessions
--  in both files. The new portal does not use that table yet, so this
--  costs nothing today.
--
--  On a brand-new project nothing clashes and there is nothing to do.
-- ---------------------------------------------------------------------
