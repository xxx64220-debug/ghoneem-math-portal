-- =====================================================================
--  SAT & EST EXAM PORTAL  —  006  IMPORT THE EXISTING SAT BANK
--  Abdelrahman Ghoneem | 01116004434
--
--  Your 352 verified SAT questions already live in THIS database, in the
--  old portal's public.site_content table. They are not retyped, re-solved
--  or regenerated here — every stem, choice, answer key, explanation and
--  figure is copied across as-is. Nothing is invented.
--
--  RUN IT IN THREE STEPS. Do not skip step 1.
--    STEP 1  select * from public.legacy_probe();     -- read-only, shows shapes
--    STEP 2  select * from public.legacy_import(true);  -- DRY RUN, changes nothing
--    STEP 3  select * from public.legacy_import(false); -- writes
--
--  Step 2 tells you exactly how many questions map cleanly and lists any it
--  cannot read. If that list is not empty, send it to me before step 3.
-- =====================================================================

-- ---------------------------------------------------------------------
--  STEP 1 — what does the old bank actually look like?
--  The old JSON was hand-built over many sessions, so the field names are
--  confirmed by inspection rather than assumed.
-- ---------------------------------------------------------------------
create or replace function public.legacy_probe()
returns table(section text, detail text)
language plpgsql as $$
declare d jsonb; item jsonb; k text;
begin
  if to_regclass('public.site_content') is null then
    return query select 'ERROR'::text,
      'public.site_content not found — is this the same project as the old portal?'::text;
    return;
  end if;

  select data into d from public.site_content order by id limit 1;
  if d is null then
    return query select 'ERROR'::text, 'site_content has no rows'::text; return;
  end if;

  return query select 'top-level keys'::text, string_agg(x, ', ' order by x)
               from jsonb_object_keys(d) x;

  for k in select jsonb_object_keys(d) loop
    if jsonb_typeof(d->k) = 'array' then
      return query select k || ' (count)', jsonb_array_length(d->k)::text;
      item := d->k->0;
      if jsonb_typeof(item) = 'object' then
        return query select k || ' (item fields)',
          (select string_agg(f, ', ' order by f) from jsonb_object_keys(item) f);
        return query select k || ' (first item)', left(item::text, 600);
      end if;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
--  STEP 2 / 3 — the import itself.
--
--  Field mapping is defensive: each attribute is read from whichever of the
--  known legacy names is present. Anything it cannot read is REPORTED, never
--  guessed — a question with an unreadable answer key is skipped, because a
--  wrong key in an exam portal is worse than a missing question.
-- ---------------------------------------------------------------------
create or replace function public.legacy_import(p_dry_run boolean default true)
returns table(metric text, value text)
language plpgsql as $$
declare
  d          jsonb;
  bank       jsonb;
  item       jsonb;
  i          integer;
  j          integer;
  v_stem     text;
  v_type     text;
  v_topic    text;
  v_diff     text;
  v_choices  jsonb;
  v_correct  jsonb;
  v_expl     text;
  v_assets   jsonb;
  v_qid      uuid;
  ch_arr     jsonb;
  ans_raw    jsonb;
  letter     text;
  n_ok       integer := 0;
  n_mc       integer := 0;
  n_grid     integer := 0;
  n_skip     integer := 0;
  n_fig      integer := 0;
  n_tab      integer := 0;
  n_noexpl   integer := 0;
  skipped    text[] := '{}';
begin
  if to_regclass('public.site_content') is null then
    return query select 'ERROR'::text, 'public.site_content not found'::text; return;
  end if;
  select data into d from public.site_content order by id limit 1;
  bank := coalesce(d->'BANK', d->'bank');
  if bank is null or jsonb_typeof(bank) <> 'array' then
    return query select 'ERROR'::text, 'no BANK array inside site_content.data'::text; return;
  end if;

  if not p_dry_run then
    delete from public.question_keys k using public.questions q
      where k.question_id = q.id and q.track_id = 'sat' and q.assets ? 'legacy_index';
    delete from public.questions
      where track_id = 'sat' and assets ? 'legacy_index';
  end if;

  for i in 0 .. jsonb_array_length(bank) - 1 loop
    item := bank->i;

    -- ---- confirmed field names, verified against the live bank ----
    --   stem      question text          (352/352)
    --   skill     lesson label           (352/352)
    --   rat       rationale/explanation  (352/352)
    --   type      'mc' | 'spr' | 'txt'
    --   opts      choice array           (223, mc only)
    --   ans       correct LETTER         (223, mc only)
    --   accepted  accepted answers array (129, spr/txt only)
    --   fig       drawing spec or null   (10 real)
    --   figHTML   data table markup      (22)
    --   src       provenance, e.g. 'December 2024'
    v_stem  := item->>'stem';
    v_topic := coalesce(nullif(item->>'skill',''), 'Unsorted');
    v_expl  := nullif(item->>'rat','');
    v_type  := lower(coalesce(item->>'type',''));

    if v_stem is null or v_stem = '' then
      n_skip := n_skip + 1; skipped := skipped || format('#%s no stem', i); continue;
    end if;

    v_choices := '[]'::jsonb;
    v_correct := null;

    if v_type = 'mc' then
      ch_arr  := item->'opts';
      ans_raw := item->'ans';
      if ch_arr is null or jsonb_typeof(ch_arr) <> 'array'
         or jsonb_array_length(ch_arr) = 0 then
        n_skip := n_skip + 1; skipped := skipped || format('#%s mc with no opts', i); continue;
      end if;
      for j in 0 .. jsonb_array_length(ch_arr) - 1 loop
        v_choices := v_choices || jsonb_build_array(jsonb_build_object(
          'key',  chr(65 + j),
          'text', case when jsonb_typeof(ch_arr->j) = 'object'
                       then coalesce(ch_arr->j->>'text','')
                       else (ch_arr->>j) end));
      end loop;
      letter := upper(trim(coalesce(item->>'ans','')));
      if letter ~ ('^[A-' || chr(64 + jsonb_array_length(ch_arr)) || ']$') then
        v_correct := to_jsonb(letter);
      end if;
      if v_correct is null then
        n_skip := n_skip + 1;
        skipped := skipped || format('#%s bad mc key (ans=%s)', i, coalesce(ans_raw::text,'null'));
        continue;
      end if;
      v_type := 'mcq'; n_mc := n_mc + 1;

    elsif v_type in ('spr','txt') then
      ans_raw := item->'accepted';
      if ans_raw is null or jsonb_typeof(ans_raw) = 'null' then
        n_skip := n_skip + 1; skipped := skipped || format('#%s %s with no accepted', i, v_type); continue;
      end if;
      v_correct := case when jsonb_typeof(ans_raw) = 'array'
                        then ans_raw else jsonb_build_array(ans_raw) end;
      if jsonb_array_length(v_correct) = 0 then
        n_skip := n_skip + 1; skipped := skipped || format('#%s empty accepted', i); continue;
      end if;
      v_type := 'grid_in'; n_grid := n_grid + 1;

    else
      n_skip := n_skip + 1;
      skipped := skipped || format('#%s unknown type "%s"', i, v_type); continue;
    end if;

    v_diff := lower(coalesce(nullif(item->>'d',''), nullif(item->>'difficulty',''),
                (regexp_match(coalesce(item->>'src',''), '(Easy|Medium|Hard)\s*$','i'))[1], 'medium'));
    if v_diff not in ('easy','medium','hard') then v_diff := 'medium'; end if;

    -- figures: fig is a drawing SPEC (not SVG) and is json-null on most rows
    v_assets := jsonb_build_object('legacy_index', i);
    if item ? 'fig' and jsonb_typeof(item->'fig') = 'object' then
      v_assets := v_assets || jsonb_build_object('figspec', item->'fig');
      n_fig := n_fig + 1;
    end if;
    if nullif(item->>'figHTML','') is not null then
      v_assets := v_assets || jsonb_build_object('html', item->>'figHTML');
      n_tab := n_tab + 1;
    end if;
    if nullif(item->>'src','') is not null then
      v_assets := v_assets || jsonb_build_object('source', item->>'src');
    end if;

    if v_expl is null then n_noexpl := n_noexpl + 1; end if;

    if not p_dry_run then
      insert into public.questions(track_id, topic, difficulty, type, stem, choices, assets)
      values ('sat', v_topic, v_diff, v_type, v_stem, v_choices, v_assets)
      returning id into v_qid;
      insert into public.question_keys(question_id, correct, explanation)
      values (v_qid, v_correct, v_expl);
    end if;
    n_ok := n_ok + 1;
  end loop;

  return query values
    ('mode',                   case when p_dry_run then 'DRY RUN - nothing written' else 'WRITTEN' end),
    ('questions in old bank',  jsonb_array_length(bank)::text),
    ('imported',               n_ok::text),
    ('  of which multiple choice', n_mc::text),
    ('  of which grid-in',     n_grid::text),
    ('skipped',                n_skip::text),
    ('carrying a diagram',     n_fig::text),
    ('carrying a data table',  n_tab::text),
    ('missing an explanation', n_noexpl::text),
    ('skip reasons',           coalesce(nullif(array_to_string(skipped[1:40], ' | '), ''), 'none'));
end $$;

-- ---------------------------------------------------------------------
--  AFTER IMPORT — a per-lesson count, so you can see the labelling landed.
-- ---------------------------------------------------------------------
-- Dropped first: a CREATE OR REPLACE VIEW cannot rename a column, so
-- re-running this file over an earlier version would fail with 42P16.
drop view if exists public.sat_bank_by_lesson;
create view public.sat_bank_by_lesson as
  select q.topic as lesson,
         count(*)                                              as questions,
         count(*) filter (where q.assets ? 'figspec')          as with_diagram,
         count(*) filter (where q.assets ? 'html')             as with_table,
         count(*) filter (where q.type = 'grid_in')            as grid_in,
         count(*) filter (where k.explanation is null
                             or k.explanation = '')            as missing_explanation
    from public.questions q
    left join public.question_keys k on k.question_id = q.id
   where q.track_id = 'sat'
   group by q.topic
   order by q.topic;

revoke execute on function public.legacy_probe()          from public, anon, authenticated;
revoke execute on function public.legacy_import(boolean)  from public, anon, authenticated;
grant  execute on function public.legacy_probe()          to service_role;
grant  execute on function public.legacy_import(boolean)  to service_role;
