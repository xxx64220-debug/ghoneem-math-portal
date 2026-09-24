-- =====================================================================
--  006a  BANK STAGING  —  only needed when the new portal lives in a
--        DIFFERENT Supabase project from the old one.
--  Abdelrahman Ghoneem | 01116004434
--
--  Migration 006 imports your 352 SAT questions from public.site_content.
--  In a brand-new project that table does not exist yet, so this creates an
--  empty one to land the old data in. Run this, load the data by one of the
--  two routes below, then run 006.
--
--  Order:  001 -> 002 -> 003 -> 004 -> 005 -> 006a -> [load data] -> 006
-- =====================================================================

create table if not exists public.site_content (
  id   integer primary key,
  data jsonb not null
);

-- Staging only. No client role may read it; the importer runs as service_role.
alter table public.site_content enable row level security;
revoke all on public.site_content from anon, authenticated;


-- =====================================================================
--  ROUTE A  —  you still have setup.sql on your computer  (recommended)
--
--  That file already contains your whole bank as one INSERT INTO
--  public.site_content. You do not need the rest of it.
--
--   1. Open setup.sql in Notepad.
--   2. Press Ctrl+F and search for:      insert into public.site_content
--   3. Select from the start of that line to the ';' that ends it.
--      It is one very long line — that is expected.
--   4. Copy it, paste into the NEW project's SQL Editor, Run.
--   5. Confirm with the check at the bottom of this file.
--
--  If the editor refuses the paste for size, use Route B instead.
-- =====================================================================

-- =====================================================================
--  ROUTE B  —  copy it straight between projects, no local file
--
--   In the OLD project:
--     1. Table Editor -> site_content
--     2. top-right menu -> Export -> Download as CSV
--
--   In the NEW project:
--     3. Table Editor -> site_content -> Insert -> Import data from CSV
--     4. Upload the file. Map 'id' to id and 'data' to data.
--
--  Route B moves the JSON as a single cell, so nothing is retyped and
--  nothing is truncated by an editor paste limit.
-- =====================================================================


-- ---------------------------------------------------------------------
--  CHECK — run this after loading, BEFORE running 006.
--  It should report one row and a BANK count of 352.
-- ---------------------------------------------------------------------
select
  (select count(*) from public.site_content)                       as rows_loaded,
  coalesce(jsonb_array_length(
    (select coalesce(data->'BANK', data->'bank')
       from public.site_content order by id limit 1)), 0)          as questions_in_bank,
  coalesce((select string_agg(k, ', ' order by k)
     from public.site_content, lateral jsonb_object_keys(data) k
    where id = (select min(id) from public.site_content)), '(none)') as top_level_keys;


-- ---------------------------------------------------------------------
--  AFTER 006 has imported successfully, the staging table has done its
--  job. Verify the import first, then drop it:
--
--     select * from public.sat_bank_by_lesson;   -- looks right?
--     drop table public.site_content;
--
--  Keep the CSV or setup.sql as your backup — do not rely on this table.
-- ---------------------------------------------------------------------
