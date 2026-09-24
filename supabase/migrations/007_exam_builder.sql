-- =====================================================================
--  SAT & EST EXAM PORTAL  —  007  EXAM BUILDER
--  Abdelrahman Ghoneem | 01116004434
--
--  WHY THIS EXISTS
--  After 006 the bank is loaded, but a student would still log in and see
--  "No exams are open in this track yet" — because questions are not exams.
--  An exam needs three things to be visible: an exams row, an assignment
--  pointing at a cohort, and the student being in that cohort.
--
--  This migration makes all three one-liners, and enrols students into the
--  right cohort automatically so you never have to think about groups.
--
--  Run after 006. Safe to re-run.
-- =====================================================================

-- ---------------------------------------------------------------------
--  1. One default cohort per track. Every student lands in it on enrolment,
--     so assigning an exam to the cohort assigns it to everybody.
-- ---------------------------------------------------------------------
insert into public.groups (track_id, name)
select t.id, t.name || ' — all students'
  from public.tracks t
 where not exists (
   select 1 from public.groups g
    where g.track_id = t.id and g.name = t.name || ' — all students');

create or replace function public.default_group(p_track text)
returns uuid language sql stable security definer set search_path = public as $$
  select g.id from public.groups g
    join public.tracks t on t.id = g.track_id
   where g.track_id = p_track and g.name = t.name || ' — all students'
   limit 1;
$$;

-- ---------------------------------------------------------------------
--  2. Enrol a student: track enrollment + cohort membership together.
--     The Edge Functions call this instead of writing enrollments directly,
--     so a student can never end up enrolled but in no cohort (which would
--     look like "no exams" and is very hard to diagnose).
-- ---------------------------------------------------------------------
create or replace function public.enrol_student(
  p_user uuid, p_track text, p_by uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare g uuid;
begin
  insert into public.enrollments(user_id, track_id, status, enrolled_by)
  values (p_user, p_track, 'active', p_by)
  on conflict (user_id, track_id)
    do update set status = 'active', enrolled_by = coalesce(excluded.enrolled_by,
                                                            enrollments.enrolled_by);

  g := public.default_group(p_track);
  if g is not null then
    insert into public.group_members(group_id, user_id)
    values (g, p_user) on conflict do nothing;
  end if;

  insert into public.audit_log(actor_id, action, target_type, target_id, meta)
  values (coalesce(p_by, p_user), 'enrollment.added', 'user', p_user::text,
          jsonb_build_object('track_id', p_track));
end $$;

-- ---------------------------------------------------------------------
--  3. Build an exam from the bank in one line.
--
--     p_topic  null  = draw from the whole track
--              text  = draw only from that lesson (matched case-insensitively,
--                      partial allowed, so 'linear' catches 'Linear functions')
--     p_count        how many questions
--     p_minutes      time limit
--     p_publish      false lets you inspect it before students can see it
--
--  Questions are picked deterministically (easiest first, then by id) so a
--  rebuild with the same arguments gives the same paper. Per-student order
--  is still shuffled at attempt time by attempts.shuffle_seed.
-- ---------------------------------------------------------------------
drop function if exists public.new_exam(text, text, integer, integer, text, boolean, boolean);
create or replace function public.new_exam(
  p_track    text,
  p_title    text,
  p_count    integer default 20,
  p_minutes  integer default 35,
  p_topic    text    default null,
  p_publish  boolean default true,
  p_assign   boolean default true,
  p_if_exists text default 'skip')   -- 'skip' | 'error' | 'duplicate'
returns uuid language plpgsql security definer set search_path = public as $$
declare
  ids   uuid[];
  v_id  uuid;
  n     integer;
begin
  if not exists (select 1 from public.tracks where id = p_track) then
    raise exception 'unknown_track: %', p_track;
  end if;

  -- Idempotency. Without this, re-running the builder creates a SECOND exam
  -- with the same title, and a student who already used their one attempt on
  -- the first would get a fresh attempt on the copy — quietly defeating the
  -- single-attempt rule. Skipping is therefore the default.
  select id into v_id from public.exams
   where track_id = p_track and title = p_title
   order by created_at limit 1;
  if v_id is not null then
    if p_if_exists = 'error' then
      raise exception 'exam_already_exists: % / %', p_track, p_title;
    elsif p_if_exists <> 'duplicate' then
      raise notice 'exists, left alone: "%"', p_title;
      return v_id;
    end if;
  end if;

  select array_agg(q.id order by
           case q.difficulty when 'easy' then 1 when 'medium' then 2 else 3 end,
           q.id)
    into ids
    from (select id, difficulty from public.questions
           where track_id = p_track
             and (p_topic is null or topic ilike '%' || p_topic || '%')
           order by case difficulty when 'easy' then 1 when 'medium' then 2 else 3 end, id
           limit p_count) q;

  n := coalesce(array_length(ids, 1), 0);
  if n = 0 then
    raise exception 'no_questions_matched: track=% topic=%', p_track, coalesce(p_topic, '(any)');
  end if;

  insert into public.exams(track_id, title, duration_seconds, question_ids, is_published)
  values (p_track, p_title, p_minutes * 60, ids, p_publish)
  returning id into v_id;

  if p_assign then
    insert into public.assignments(exam_id, group_id)
    values (v_id, public.default_group(p_track));
  end if;

  raise notice 'created "%" with % question(s), % min, published=%',
    p_title, n, p_minutes, p_publish;
  return v_id;
end $$;

-- ---------------------------------------------------------------------
--  4. Build one exam per lesson in a track, in a single call.
--     The fastest way to go from an imported bank to a usable portal.
-- ---------------------------------------------------------------------
-- Dropped first: CREATE OR REPLACE cannot change a function's return type,
-- so re-running this file over an earlier version would leave the OLD
-- signature in place and fail silently at the call site.
drop function if exists public.new_exam_per_lesson(text, integer, integer, integer, boolean);
create or replace function public.new_exam_per_lesson(
  p_track   text,
  p_count   integer default 12,
  p_minutes integer default 20,
  p_min_questions integer default 5,
  p_publish boolean default true)
returns table(lesson text, action text, questions integer, exam_id uuid)
language plpgsql security definer set search_path = public as $$
declare r record; v uuid; avail integer; existed boolean;
begin
  for r in select topic, count(*) as c from public.questions
            where track_id = p_track group by topic order by topic loop
    if r.c >= p_min_questions then
      avail := least(r.c, p_count)::integer;
      existed := exists (select 1 from public.exams
                          where track_id = p_track and title = r.topic);
      v := public.new_exam(p_track, r.topic, avail, p_minutes, r.topic,
                           p_publish, true, 'skip');
      lesson := r.topic;
      action := case when existed then 'already existed - left alone' else 'created' end;
      questions := avail; exam_id := v;
      return next;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
--  5. What is live right now — check this after building.
-- ---------------------------------------------------------------------
drop view if exists public.exam_overview;
create view public.exam_overview as
  select e.track_id,
         e.title,
         coalesce(array_length(e.question_ids, 1), 0) as questions,
         e.duration_seconds / 60                      as minutes,
         e.is_published,
         (select count(*) from public.assignments a where a.exam_id = e.id) as assignments,
         (select count(*) from public.attempts at where at.exam_id = e.id)  as attempts_taken
    from public.exams e
   order by e.track_id, e.title;

-- ---------------------------------------------------------------------
--  6. Lock these down the same way 005 did — staff tools, not client calls.
-- ---------------------------------------------------------------------
revoke execute on function
  public.new_exam(text, text, integer, integer, text, boolean, boolean, text),
  public.new_exam_per_lesson(text, integer, integer, integer, boolean),
  public.enrol_student(uuid, text, uuid),
  public.default_group(text)
from public, anon, authenticated;

grant execute on function
  public.new_exam(text, text, integer, integer, text, boolean, boolean, text),
  public.new_exam_per_lesson(text, integer, integer, integer, boolean),
  public.enrol_student(uuid, text, uuid),
  public.default_group(text)
to service_role;
