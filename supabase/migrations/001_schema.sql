-- =====================================================================
--  SAT & EST EXAM PORTAL  —  001  CORE SCHEMA
--  Abdelrahman Ghoneem | 01116004434
--  Run order: 001_schema → 002_functions → 003_policies → 004_seed
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- roles
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text        not null default '',
  role        text        not null default 'student'
                          check (role in ('student','instructor','admin')),
  status      text        not null default 'active'
                          check (status in ('active','suspended')),
  created_at  timestamptz not null default now()
);

-- --------------------------------------------------------------- tracks
-- A track is a self-contained exam programme (SAT, EST, later ACT).
-- Text primary key: readable in every foreign key and every hand-written query.
create table if not exists public.tracks (
  id                       text primary key check (id ~ '^[a-z0-9_]{2,16}$'),
  name                     text        not null,
  theme                    jsonb       not null default '{}'::jsonb,
  scoring                  jsonb       not null default '{}'::jsonb,
  default_duration_seconds integer     not null default 3600 check (default_duration_seconds > 0),
  is_active                boolean     not null default true,
  created_at               timestamptz not null default now()
);

-- Student ↔ track. This table is the security boundary between SAT and EST.
create table if not exists public.enrollments (
  user_id     uuid        not null references public.profiles(id) on delete cascade,
  track_id    text        not null references public.tracks(id)   on delete cascade,
  status      text        not null default 'active' check (status in ('active','paused')),
  enrolled_at timestamptz not null default now(),
  enrolled_by uuid        references public.profiles(id),
  primary key (user_id, track_id)
);

-- Which tracks an instructor may author and report on. Admins are unbounded.
create table if not exists public.instructor_tracks (
  user_id  uuid not null references public.profiles(id) on delete cascade,
  track_id text not null references public.tracks(id)   on delete cascade,
  primary key (user_id, track_id)
);

-- --------------------------------------------------------------- groups
create table if not exists public.groups (
  id            uuid primary key default gen_random_uuid(),
  track_id      text not null references public.tracks(id) on delete cascade,
  name          text not null,
  instructor_id uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id)   on delete cascade,
  user_id  uuid not null references public.profiles(id) on delete cascade,
  primary key (group_id, user_id)
);

-- -------------------------------------------------------------- content
create table if not exists public.questions (
  id         uuid primary key default gen_random_uuid(),
  track_id   text not null references public.tracks(id) on delete cascade,
  topic      text not null default '',
  difficulty text not null default 'medium' check (difficulty in ('easy','medium','hard')),
  type       text not null default 'mcq'    check (type in ('mcq','grid_in')),
  stem       text not null,
  choices    jsonb not null default '[]'::jsonb,   -- [{"key":"A","text":"..."}]
  assets     jsonb not null default '{}'::jsonb,   -- {"svg":"...","image":"..."}
  created_at timestamptz not null default now()
);
create index if not exists questions_track_idx on public.questions(track_id, topic);

-- Split from questions on purpose: no policy on this table ever grants a
-- student access, so a leaked publishable key cannot dump the answers.
create table if not exists public.question_keys (
  question_id uuid primary key references public.questions(id) on delete cascade,
  correct     jsonb not null,   -- mcq: "B"   |   grid_in: ["3/4","0.75"]
  explanation text  not null default ''
);

create table if not exists public.exams (
  id               uuid primary key default gen_random_uuid(),
  track_id         text    not null references public.tracks(id) on delete cascade,
  title            text    not null,
  duration_seconds integer not null check (duration_seconds > 0),
  question_ids     uuid[]  not null default '{}',
  shuffle          boolean not null default true,
  review_policy    text    not null default 'full_review'
                     check (review_policy in ('full_review','score_only','instructor_release')),
  max_attempts     integer not null default 1 check (max_attempts >= 1),
  is_published     boolean not null default false,
  created_at       timestamptz not null default now()
);
create index if not exists exams_track_idx on public.exams(track_id) where is_published;

create table if not exists public.assignments (
  id        uuid primary key default gen_random_uuid(),
  exam_id   uuid not null references public.exams(id)    on delete cascade,
  group_id  uuid references public.groups(id)            on delete cascade,
  user_id   uuid references public.profiles(id)          on delete cascade,
  open_at   timestamptz,
  close_at  timestamptz,
  created_at timestamptz not null default now(),
  constraint assignment_target_exactly_one
    check ((group_id is null) <> (user_id is null))
);
create index if not exists assignments_exam_idx  on public.assignments(exam_id);
create index if not exists assignments_group_idx on public.assignments(group_id);
create index if not exists assignments_user_idx  on public.assignments(user_id);

-- ------------------------------------------------------------- attempts
create table if not exists public.attempts (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles(id) on delete cascade,
  exam_id           uuid not null references public.exams(id)    on delete cascade,
  assignment_id     uuid references public.assignments(id)       on delete set null,
  attempt_no        integer     not null check (attempt_no >= 1),
  shuffle_seed      bigint      not null,
  status            text        not null default 'in_progress'
                      check (status in ('in_progress','submitted','graded','expired')),
  started_at        timestamptz not null default now(),
  deadline_at       timestamptz not null,
  submitted_at      timestamptz,
  review_unlocks_at timestamptz,
  score             integer,
  scaled_score      integer,
  total             integer,
  time_used         integer,
  ip                text,
  user_agent        text
);

-- Layer 2 of single-submission enforcement: the database itself refuses a
-- second live attempt. Keyed on exam, not track, so a dual-enrolled student
-- may hold one live SAT attempt and one live EST attempt at the same time.
create unique index if not exists one_live_attempt
  on public.attempts (user_id, exam_id) where status = 'in_progress';

create unique index if not exists attempt_no_unique
  on public.attempts (user_id, exam_id, attempt_no);

create index if not exists attempts_exam_idx     on public.attempts(exam_id, status);
create index if not exists attempts_deadline_idx on public.attempts(deadline_at) where status = 'in_progress';

-- Student-writable: their own responses, while their own attempt is live.
create table if not exists public.attempt_answers (
  attempt_id  uuid not null references public.attempts(id)  on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  response    jsonb,
  answered_at timestamptz not null default now(),
  primary key (attempt_id, question_id)
);

-- Server-only: correctness is never a column the client can write.
create table if not exists public.attempt_results (
  attempt_id  uuid not null references public.attempts(id)  on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  is_correct  boolean not null,
  awarded     numeric not null default 0,
  primary key (attempt_id, question_id)
);

create table if not exists public.retake_grants (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  exam_id     uuid not null references public.exams(id)    on delete cascade,
  granted_by  uuid references public.profiles(id),
  reason      text not null default '',
  granted_at  timestamptz not null default now(),
  expires_at  timestamptz,
  consumed_at timestamptz
);
create index if not exists retake_open_idx
  on public.retake_grants(user_id, exam_id) where consumed_at is null;

-- --------------------------------------------------------- ops & audit
create table if not exists public.device_sessions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  device_hash text not null,
  user_agent  text not null default '',
  last_seen   timestamptz not null default now(),
  unique (user_id, device_hash)
);

create table if not exists public.audit_log (
  id          bigserial primary key,
  actor_id    uuid,
  action      text not null,
  target_type text,
  target_id   text,
  meta        jsonb not null default '{}'::jsonb,
  at          timestamptz not null default now()
);
create index if not exists audit_at_idx on public.audit_log(at desc);
