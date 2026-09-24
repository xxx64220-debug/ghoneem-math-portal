-- Daily SAT/EST practice. The Edge Function authenticates the caller and is the
-- only client of these service-role-only functions. Days follow Cairo time.
create table if not exists public.daily_quizzes (
  track_id text not null references public.tracks(id),
  day date not null,
  question_ids uuid[] not null,
  primary key (track_id, day),
  constraint five_daily_questions check (array_length(question_ids, 1) = 5)
);

create table if not exists public.daily_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  track_id text not null references public.tracks(id),
  day date not null,
  focus_done boolean not null default false,
  review_done boolean not null default false,
  quiz_completed_at timestamptz,
  quiz_score integer,
  answers jsonb not null default '{}'::jsonb,
  points integer not null default 0,
  bonus_awarded boolean not null default false,
  primary key (user_id, track_id, day),
  constraint daily_quiz_score check (quiz_score between 0 and 5 or quiz_score is null),
  constraint daily_points_nonnegative check (points >= 0)
);

create index if not exists daily_progress_rank_idx on public.daily_progress(track_id, user_id);
alter table public.daily_quizzes enable row level security;
alter table public.daily_progress enable row level security;
revoke all on public.daily_quizzes, public.daily_progress from public, anon, authenticated;

create or replace function public.daily_state(p_user uuid, p_track text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  d date := (now() at time zone 'Africa/Cairo')::date;
  qids uuid[];
  progress_ public.daily_progress%rowtype;
  quiz_ jsonb;
  leaders_ jsonb;
  myrank_ integer;
  mytotal_ integer;
  current_ integer;
  best_ integer;
  week_ jsonb;
begin
  if not exists (
    select 1 from public.profiles p join public.enrollments e on e.user_id=p.id
    join public.tracks t on t.id=e.track_id
    where p.id=p_user and p.role='student' and p.status='active'
      and e.track_id=p_track and e.status='active' and t.is_active
  ) then raise exception 'not_enrolled_in_track'; end if;

  insert into public.daily_quizzes(track_id, day, question_ids)
  select p_track, d, array(
    select q.id from public.questions q join public.question_keys k on k.question_id=q.id
    where q.track_id=p_track and q.type='mcq'
      and q.assets->>'verified_release' like '2026-09-14-batch-%'
      and length(btrim(k.explanation))>0
      and jsonb_array_length(q.choices)>=4
    order by md5(d::text || q.id::text) limit 5
  )
  on conflict (track_id,day) do nothing;
  select question_ids into qids from public.daily_quizzes where track_id=p_track and day=d;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;

  insert into public.daily_progress(user_id,track_id,day) values(p_user,p_track,d)
  on conflict (user_id,track_id,day) do nothing;
  select * into progress_ from public.daily_progress
  where user_id=p_user and track_id=p_track and day=d;

  select jsonb_agg(jsonb_build_object(
    'id',q.id,'stem',q.stem,'choices',q.choices,'topic',q.topic,
    'answer',case when progress_.quiz_completed_at is null then null else
      jsonb_build_object('correct',k.correct,'explanation',k.explanation,
        'submitted',progress_.answers->q.id::text) end
  ) order by ord.n) into quiz_
  from unnest(qids) with ordinality ord(id,n)
  join public.questions q on q.id=ord.id join public.question_keys k on k.question_id=q.id;

  with ranked as (
    select e.user_id, p.full_name,
      coalesce(sum(dp.points),0)::integer as points,
      count(dp.quiz_completed_at)::integer as completed,
      row_number() over (order by coalesce(sum(dp.points),0) desc,
        count(dp.quiz_completed_at) desc, e.user_id) as rank
    from public.enrollments e join public.profiles p on p.id=e.user_id
    left join public.daily_progress dp on dp.user_id=e.user_id and dp.track_id=e.track_id
    where e.track_id=p_track and e.status='active' and p.status='active' and p.role='student'
    group by e.user_id,p.full_name
  ) select coalesce(jsonb_agg(jsonb_build_object(
      'rank',rank,'name',split_part(coalesce(full_name,'Student'),' ',1)
        || case when position(' ' in btrim(coalesce(full_name,'')))>0 then ' '
          || left(reverse(split_part(reverse(btrim(full_name)),' ',1)),1) || '.' else '' end,
      'points',points,'completed',completed
    ) order by rank) filter (where rank<=10),'[]'::jsonb),
    (max(rank) filter (where user_id=p_user))::integer,
    max(points) filter (where user_id=p_user)
    into leaders_,myrank_,mytotal_ from ranked;

  -- Consecutive calendar dates form islands. Yesterday's streak remains active
  -- until today's deadline; a missed day resets only the current streak.
  with days as (
    select day, day - (row_number() over(order by day))::int as island
    from public.daily_progress where user_id=p_user and track_id=p_track
      and quiz_completed_at is not null and day<=d
  ), runs as (
    select count(*)::int as length,max(day) as last_day from days group by island
  ) select coalesce(max(length) filter(where last_day>=d-1),0),
      coalesce(max(length),0) into current_,best_ from runs;
  select jsonb_agg(jsonb_build_object('date',d-offset_,
    'completed',exists(select 1 from public.daily_progress p where p.user_id=p_user
      and p.track_id=p_track and p.day=d-offset_ and p.quiz_completed_at is not null),
    'today',offset_=0) order by offset_ desc) into week_ from generate_series(0,6) offset_;

  return jsonb_build_object('date',d,'reset_at',((d+1)::timestamp at time zone 'Africa/Cairo'),
    'server_now',now(),'streak',jsonb_build_object('current',current_,'longest',best_,'week',week_),
    'track',p_track,'quiz',quiz_,'score',progress_.quiz_score,
    'completed',progress_.quiz_completed_at is not null,
    'checklist',jsonb_build_object('quiz',progress_.quiz_completed_at is not null,
      'focus',progress_.focus_done,'review',progress_.review_done,
      'bonus',progress_.bonus_awarded),
    'points_today',progress_.points,'points_total',coalesce(mytotal_,0),
    'rank',myrank_,'leaderboard',leaders_);
end $$;

create or replace function public.daily_submit(p_user uuid,p_track text,p_answers jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  d date := (now() at time zone 'Africa/Cairo')::date;
  progress_ public.daily_progress%rowtype;
  qids uuid[];
  correct_ integer;
  streak_ integer;
begin
  -- Call daily_state first to validate enrollment and create today's frozen quiz.
  perform public.daily_state(p_user,p_track);
  if jsonb_typeof(p_answers) is distinct from 'object' or
    (select count(*) from jsonb_object_keys(p_answers))<>5 then
    raise exception 'invalid_answers'; end if;
  select question_ids into qids from public.daily_quizzes where track_id=p_track and day=d;
  if exists(select 1 from jsonb_object_keys(p_answers) key where not key=any(select unnest(qids)::text))
  then raise exception 'invalid_answers'; end if;
  if exists(select 1 from unnest(qids) qid join public.questions q on q.id=qid
    where not exists(select 1 from jsonb_array_elements(q.choices) choice
      where p_answers->q.id::text=to_jsonb(choice->>'key')))
  then raise exception 'invalid_answers'; end if;
  select * into progress_ from public.daily_progress
   where user_id=p_user and track_id=p_track and day=d for update;
  if progress_.quiz_completed_at is not null then return public.daily_state(p_user,p_track); end if;
  select count(*)::integer into correct_
  from unnest(qids) qid join public.questions q on q.id=qid
  join public.question_keys k on k.question_id=q.id
  where public.answer_matches(q.type,p_answers->q.id::text,k.correct);
  select case when exists(select 1 from public.daily_progress
    where user_id=p_user and track_id=p_track and day=d-1 and quiz_completed_at is not null)
    then 5 else 0 end into streak_;
  update public.daily_progress set quiz_completed_at=now(),quiz_score=correct_,answers=p_answers,
    points=points + 10 + 10*correct_ + streak_
      + case when focus_done and review_done and not bonus_awarded then 5 else 0 end,
    bonus_awarded=bonus_awarded or (focus_done and review_done)
  where user_id=p_user and track_id=p_track and day=d;
  return public.daily_state(p_user,p_track);
end $$;

create or replace function public.daily_mark(p_user uuid,p_track text,p_task text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare d date := (now() at time zone 'Africa/Cairo')::date;
begin
  perform public.daily_state(p_user,p_track);
  if p_task not in ('focus','review') then raise exception 'invalid_task'; end if;
  update public.daily_progress set
    focus_done=focus_done or p_task='focus',
    review_done=review_done or p_task='review'
  where user_id=p_user and track_id=p_track and day=d;
  update public.daily_progress set points=points+5,bonus_awarded=true
  where user_id=p_user and track_id=p_track and day=d
    and quiz_completed_at is not null and focus_done and review_done and not bonus_awarded;
  return public.daily_state(p_user,p_track);
end $$;

revoke all on function public.daily_state(uuid,text) from public,anon,authenticated;
revoke all on function public.daily_submit(uuid,text,jsonb) from public,anon,authenticated;
revoke all on function public.daily_mark(uuid,text,text) from public,anon,authenticated;
grant execute on function public.daily_state(uuid,text),public.daily_submit(uuid,text,jsonb),
  public.daily_mark(uuid,text,text) to service_role;
