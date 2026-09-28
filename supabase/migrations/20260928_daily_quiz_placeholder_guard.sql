-- Keep placeholder answer choices out of newly generated daily quizzes.
-- Existing frozen daily sets are unchanged; corrected bank records appear immediately.
CREATE OR REPLACE FUNCTION public.daily_state(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

  perform pg_advisory_xact_lock(hashtextextended('daily:'||p_track||':'||d::text,0));
  select question_ids into qids from public.daily_quizzes where track_id=p_track and day=d;
  if qids is null then
  select array(
    select q.id from public.questions q join public.question_keys k on k.question_id=q.id
    where q.track_id=p_track and q.type='mcq'
      and nullif(q.assets->>'verified_release','') is not null
      and nullif(q.assets->>'release_hold_reason','') is null
      and length(btrim(k.explanation))>0
      and jsonb_array_length(q.choices)>=4
      and not exists (
        select 1 from jsonb_array_elements(q.choices) ch
        where ch->>'text' ilike '%in the original question%'
      )
      and jsonb_typeof(k.correct)='string'
      and exists(select 1 from jsonb_array_elements(q.choices) ch where ch->>'key'=k.correct#>>'{}')
      and exists(select 1 from public.portal_track_controls c where c.track_id=p_track and
       (c.daily_mode='random' or (c.daily_mode='lessons' and q.topic=any(c.daily_lessons)) or (c.daily_mode='selected' and q.id=any(c.daily_question_ids))))
    order by md5(d::text || q.id::text) limit 5
  ) into qids;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;
  insert into public.daily_quizzes(track_id,day,question_ids) values(p_track,d,qids);
  end if;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;

  insert into public.daily_progress(user_id,track_id,day) values(p_user,p_track,d)
  on conflict (user_id,track_id,day) do nothing;
  select * into progress_ from public.daily_progress
  where user_id=p_user and track_id=p_track and day=d;

  select jsonb_agg(jsonb_build_object(
    'id',q.id,'stem',q.stem,'choices',q.choices,'topic',q.topic,'assets',q.assets,
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
    'selection_mode',(select daily_mode from public.portal_track_controls where track_id=p_track),'track',p_track,'quiz',quiz_,'score',progress_.quiz_score,
    'completed',progress_.quiz_completed_at is not null,
    'checklist',jsonb_build_object('quiz',progress_.quiz_completed_at is not null,
      'focus',progress_.focus_done,'review',progress_.review_done,
      'bonus',progress_.bonus_awarded),
    'points_today',progress_.points,'points_total',coalesce(mytotal_,0),
    'rank',myrank_,'leaderboard',leaders_);
end;
$function$
