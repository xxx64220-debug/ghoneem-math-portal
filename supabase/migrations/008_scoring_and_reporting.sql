-- =====================================================================
--  SAT & EST EXAM PORTAL  —  008  HONEST SCORES + INSTRUCTOR REPORTING
--  Abdelrahman Ghoneem | 01116004434
--
--  PART 1 — the scaled score was lying.
--  scale_score() mapped any raw/total linearly onto 200-800, so a
--  15-question lesson drill reported 8/15 as "520" and 15/15 as "800".
--  That number gets screenshotted and sent to a parent. A scaled SAT
--  score only means something over a full-length paper.
--
--  From here: only exams flagged is_full_length carry a scaled score.
--  Everything else shows the raw mark, which is the truth.
--
--  PART 2 — reporting the instructor dashboard reads from.
--
--  Run after 007. Safe to re-run.
-- =====================================================================

-- ---------------------------------------------------------------------
--  PART 1 · full-length flag
-- ---------------------------------------------------------------------
alter table public.exams
  add column if not exists is_full_length boolean not null default false;

comment on column public.exams.is_full_length is
  'Only full-length papers get a scaled 200-800 score. Lesson drills show raw marks.';

create or replace function public.grade_attempt(p_attempt uuid)
returns public.attempts
language plpgsql security definer set search_path = public as $$
declare
  v_att   public.attempts%rowtype;
  v_exam  public.exams%rowtype;
  v_score integer;
  v_total integer;
  v_close timestamptz;
begin
  select * into v_att  from public.attempts where id = p_attempt;
  select * into v_exam from public.exams    where id = v_att.exam_id;

  delete from public.attempt_results where attempt_id = p_attempt;

  insert into public.attempt_results(attempt_id, question_id, is_correct, awarded)
  select p_attempt, q.id,
         public.answer_matches(q.type, aa.response, k.correct),
         case when public.answer_matches(q.type, aa.response, k.correct) then 1 else 0 end
    from unnest(v_exam.question_ids) as qid
    join public.questions      q  on q.id = qid
    join public.question_keys  k  on k.question_id = q.id
    left join public.attempt_answers aa
           on aa.attempt_id = p_attempt and aa.question_id = q.id;

  select count(*) filter (where is_correct), count(*)
    into v_score, v_total
    from public.attempt_results where attempt_id = p_attempt;

  select a.close_at into v_close from public.assignments a where a.id = v_att.assignment_id;

  update public.attempts
     set status            = 'graded',
         score             = v_score,
         total             = v_total,
         -- CHANGED: a scaled score is only meaningful on a full-length paper.
         scaled_score      = case when v_exam.is_full_length
                                  then public.scale_score(v_exam.track_id, v_score, v_total)
                                  else null end,
         time_used         = greatest(0, extract(epoch from
                               (coalesce(submitted_at, now()) - started_at))::int),
         review_unlocks_at = case
                               when v_exam.review_policy = 'instructor_release' then null
                               when v_close is not null and v_close > now() then v_close
                               else now()
                             end
   where id = p_attempt
  returning * into v_att;

  return v_att;
end $$;

-- Any drill already graded under the old rule carries a misleading number.
update public.attempts a
   set scaled_score = null
  from public.exams e
 where e.id = a.exam_id and not e.is_full_length and a.scaled_score is not null;

-- new_exam gains the flag (default false — drills are the common case)
drop function if exists public.new_exam(text, text, integer, integer, text, boolean, boolean, text);
create or replace function public.new_exam(
  p_track       text,
  p_title       text,
  p_count       integer default 20,
  p_minutes     integer default 35,
  p_topic       text    default null,
  p_publish     boolean default true,
  p_assign      boolean default true,
  p_if_exists   text    default 'skip',
  p_full_length boolean default false)
returns uuid language plpgsql security definer set search_path = public as $$
declare ids uuid[]; v_id uuid; n integer;
begin
  if not exists (select 1 from public.tracks where id = p_track) then
    raise exception 'unknown_track: %', p_track;
  end if;

  select id into v_id from public.exams
   where track_id = p_track and title = p_title order by created_at limit 1;
  if v_id is not null then
    if p_if_exists = 'error' then
      raise exception 'exam_already_exists: % / %', p_track, p_title;
    elsif p_if_exists <> 'duplicate' then
      raise notice 'exists, left alone: "%"', p_title;
      return v_id;
    end if;
  end if;

  select array_agg(q.id order by
           case q.difficulty when 'easy' then 1 when 'medium' then 2 else 3 end, q.id)
    into ids
    from (select id, difficulty from public.questions
           where track_id = p_track
             and (p_topic is null or topic ilike '%' || p_topic || '%')
           order by case difficulty when 'easy' then 1 when 'medium' then 2 else 3 end, id
           limit p_count) q;

  n := coalesce(array_length(ids, 1), 0);
  if n = 0 then
    raise exception 'no_questions_matched: track=% topic=%', p_track, coalesce(p_topic,'(any)');
  end if;

  insert into public.exams(track_id, title, duration_seconds, question_ids,
                           is_published, is_full_length)
  values (p_track, p_title, p_minutes * 60, ids, p_publish, p_full_length)
  returning id into v_id;

  if p_assign then
    insert into public.assignments(exam_id, group_id)
    values (v_id, public.default_group(p_track));
  end if;

  raise notice 'created "%": % question(s), % min, full_length=%', p_title, n, p_minutes, p_full_length;
  return v_id;
end $$;

-- new_exam_per_lesson always builds drills, so it passes full_length = false
drop function if exists public.new_exam_per_lesson(text, integer, integer, integer, boolean);
create or replace function public.new_exam_per_lesson(
  p_track text, p_count integer default 12, p_minutes integer default 20,
  p_min_questions integer default 5, p_publish boolean default true)
returns table(lesson text, action text, questions integer, exam_id uuid)
language plpgsql security definer set search_path = public as $$
declare r record; v uuid; avail integer; existed boolean;
begin
  for r in select topic, count(*) as c from public.questions
            where track_id = p_track group by topic order by topic loop
    if r.c >= p_min_questions then
      avail := least(r.c, p_count)::integer;
      existed := exists (select 1 from public.exams where track_id = p_track and title = r.topic);
      v := public.new_exam(p_track, r.topic, avail, p_minutes, r.topic, p_publish, true, 'skip', false);
      lesson := r.topic;
      action := case when existed then 'already existed - left alone' else 'created' end;
      questions := avail; exam_id := v; return next;
    end if;
  end loop;
end $$;

-- Build a full-length paper across the whole track (these DO get scaled).
create or replace function public.new_full_length(
  p_track text, p_title text, p_count integer default 44, p_minutes integer default 70)
returns uuid language sql security definer set search_path = public as $$
  select public.new_exam(p_track, p_title, p_count, p_minutes, null, true, true, 'skip', true);
$$;

drop view if exists public.exam_overview;
create view public.exam_overview as
  select e.track_id, e.title,
         coalesce(array_length(e.question_ids,1),0) as questions,
         e.duration_seconds/60 as minutes,
         e.is_published, e.is_full_length,
         case when e.is_full_length then 'scaled 200-800' else 'raw marks' end as score_shown,
         (select count(*) from public.assignments a where a.exam_id = e.id) as assignments,
         (select count(*) from public.attempts at where at.exam_id = e.id)  as attempts_taken
    from public.exams e order by e.track_id, e.title;

-- ---------------------------------------------------------------------
--  PART 2 · reporting for the instructor dashboard
--  IMPORTANT: a Postgres view runs as its OWNER, so RLS on the underlying
--  tables is NOT applied to whoever queries the view. Without an explicit
--  guard a student could read the entire roster. Each view therefore carries
--  its own staff predicate:
--     is_staff()                  -> admin or instructor
--     staff_can_touch_track(t)    -> admin, or an instructor of that track
--  A student matches neither, so every one of these returns zero rows.
-- ---------------------------------------------------------------------
drop view if exists public.roster;
create view public.roster as
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
   where public.is_staff()
   group by p.id, p.full_name, p.role, p.status, u.email;

drop view if exists public.results_feed;
create view public.results_feed as
  select a.id as attempt_id, a.user_id, p.full_name, e.track_id, e.title as exam,
         a.status, a.score, a.total, a.scaled_score,
         round(100.0 * a.score / nullif(a.total,0)) as percent,
         a.time_used, a.submitted_at, e.is_full_length
    from public.attempts a
    join public.exams    e on e.id = a.exam_id
    join public.profiles p on p.id = a.user_id
   where a.status in ('graded','expired')
     and public.staff_can_touch_track(e.track_id)
   order by a.submitted_at desc;

-- Which questions the cohort fails most — the teaching signal.
drop view if exists public.question_difficulty;
create view public.question_difficulty as
  select q.track_id, q.topic as lesson, q.id as question_id,
         left(q.stem, 90) as stem,
         count(*)                                   as answered_by,
         count(*) filter (where r.is_correct)       as got_it_right,
         round(100.0 * count(*) filter (where r.is_correct) / count(*)) as percent_correct
    from public.attempt_results r
    join public.questions q on q.id = r.question_id
   where public.staff_can_touch_track(q.track_id)
   group by q.track_id, q.topic, q.id, q.stem
  having count(*) >= 3
   order by percent_correct asc;

-- Where each student is weak, by lesson.
drop view if exists public.student_by_lesson;
create view public.student_by_lesson as
  select a.user_id, p.full_name, q.track_id, q.topic as lesson,
         count(*)                              as questions_seen,
         count(*) filter (where r.is_correct)  as correct,
         round(100.0 * count(*) filter (where r.is_correct) / count(*)) as percent
    from public.attempt_results r
    join public.attempts  a on a.id = r.attempt_id
    join public.questions q on q.id = r.question_id
    join public.profiles  p on p.id = a.user_id
   where public.staff_can_touch_track(q.track_id)
   group by a.user_id, p.full_name, q.track_id, q.topic
   order by p.full_name, percent asc;

grant select on public.roster, public.results_feed,
                public.question_difficulty, public.student_by_lesson to authenticated;

-- ---------------------------------------------------------------------
--  Lock the new builders down, as 005 does for everything privileged.
-- ---------------------------------------------------------------------
revoke execute on function
  public.new_exam(text, text, integer, integer, text, boolean, boolean, text, boolean),
  public.new_exam_per_lesson(text, integer, integer, integer, boolean),
  public.new_full_length(text, text, integer, integer),
  public.grade_attempt(uuid)
from public, anon, authenticated;

grant execute on function
  public.new_exam(text, text, integer, integer, text, boolean, boolean, text, boolean),
  public.new_exam_per_lesson(text, integer, integer, integer, boolean),
  public.new_full_length(text, text, integer, integer),
  public.grade_attempt(uuid)
to service_role;

-- ---------------------------------------------------------------------
--  PART 3 · deleting a staff account must not be blocked by their history
--
--  enrol_student() records WHO enrolled a student, and grant_retake()
--  records who granted it. Both referenced profiles with NO ACTION, so
--  removing a former instructor's account failed with a foreign key error
--  and the row could not be deleted at all.
--
--  SET NULL keeps the enrollment and the grant — the history survives, the
--  attribution simply becomes unknown, which is the honest outcome.
-- ---------------------------------------------------------------------
alter table public.enrollments
  drop constraint if exists enrollments_enrolled_by_fkey;
alter table public.enrollments
  add  constraint enrollments_enrolled_by_fkey
  foreign key (enrolled_by) references public.profiles(id) on delete set null;

alter table public.retake_grants
  drop constraint if exists retake_grants_granted_by_fkey;
alter table public.retake_grants
  add  constraint retake_grants_granted_by_fkey
  foreign key (granted_by) references public.profiles(id) on delete set null;
