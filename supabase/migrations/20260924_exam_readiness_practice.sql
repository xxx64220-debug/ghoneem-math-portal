-- Personal mistake mastery and keyless, server-graded weak-topic practice.
-- Edge Function authentication supplies p_user; the RPCs are service-role only.
create table if not exists public.practice_notebook (
  user_id uuid not null references public.profiles(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  correct_streak smallint not null default 0 check (correct_streak between 0 and 2),
  tries integer not null default 0 check (tries >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, question_id)
);
alter table public.practice_notebook enable row level security;
revoke all on public.practice_notebook from public, anon, authenticated;

create table if not exists public.practice_drills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  track_id text not null references public.tracks(id),
  topics text[] not null,
  question_ids uuid[] not null,
  answers jsonb not null default '{}'::jsonb,
  score integer,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint practice_drill_size check (cardinality(question_ids) between 15 and 20)
);
create index if not exists practice_drills_owner_idx on public.practice_drills(user_id, track_id, created_at desc);
alter table public.practice_drills enable row level security;
revoke all on public.practice_drills from public, anon, authenticated;

create or replace function public.practice_notebook_state(p_user uuid, p_track text, p_offset integer)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_items jsonb; v_count int; v_done int;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  if p_offset<0 or p_offset>10000 then raise exception 'invalid_page'; end if;
  -- An exam mistake is eligible only after the instructor's review policy opens.
  insert into public.practice_notebook(user_id,question_id)
  select distinct p_user,r.question_id
  from public.attempt_results r
  join public.attempts a on a.id=r.attempt_id
  join public.exams e on e.id=a.exam_id
  join public.questions q on q.id=r.question_id and q.track_id=e.track_id
  join public.question_keys k on k.question_id=q.id
  where a.user_id=p_user and e.track_id=p_track and r.is_correct=false
    and a.status in ('graded','expired') and a.score is not null
    and e.review_policy='full_review' and a.review_unlocks_at<=now()
    and jsonb_typeof(k.correct) in ('string','array')
  on conflict do nothing;
  insert into public.practice_notebook(user_id,question_id)
  select distinct p_user,q.id
  from public.daily_progress dp
  cross join lateral jsonb_each(dp.answers) answer_(qid,response)
  join public.questions q on q.id=answer_.qid::uuid and q.track_id=dp.track_id
  join public.question_keys k on k.question_id=q.id
  where dp.user_id=p_user and dp.track_id=p_track and dp.quiz_completed_at is not null
    and not public.answer_matches(q.type,answer_.response,k.correct)
    and jsonb_typeof(k.correct) in ('string','array')
  on conflict do nothing;
  select count(*) filter(where n.correct_streak<2),count(*) filter(where n.correct_streak=2)
  into v_count,v_done from public.practice_notebook n join public.questions q on q.id=n.question_id
  where n.user_id=p_user and q.track_id=p_track;
  select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'stem',q.stem,'topic',q.topic,
    'type',q.type,'choices',q.choices,'assets',q.assets,'streak',n.correct_streak,'tries',n.tries)
    order by q.topic,q.id),'[]'::jsonb) into v_items
  from (select n.question_id,n.correct_streak,n.tries,n.updated_at
    from public.practice_notebook n join public.questions page_q on page_q.id=n.question_id
    where n.user_id=p_user and page_q.track_id=p_track and n.correct_streak<2
    order by page_q.topic,n.question_id limit 25 offset p_offset) n
  join public.questions q on q.id=n.question_id;
  return jsonb_build_object('track',p_track,'remaining',v_count,'mastered',v_done,'items',v_items);
end $$;

create or replace function public.practice_notebook_answer(p_user uuid,p_track text,p_question uuid,p_answer text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_q public.questions%rowtype; v_key public.question_keys%rowtype; v_ok boolean; v_streak int;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  select * into v_q from public.questions where id=p_question and track_id=p_track;
  if not found then raise exception 'question_not_found'; end if;
  if length(p_answer)>250 or length(p_answer)=0 then raise exception 'invalid_answer'; end if;
  if v_q.type='mcq' and not exists(select 1 from jsonb_array_elements(v_q.choices) c where c->>'key'=p_answer) then raise exception 'invalid_answer'; end if;
  select * into v_key from public.question_keys where question_id=p_question;
  if not found then raise exception 'question_not_found'; end if;
  -- Serialize repeat taps and prevent grading an unearned or already mastered item.
  perform 1 from public.practice_notebook where user_id=p_user and question_id=p_question and correct_streak<2 for update;
  if not found then raise exception 'notebook_item_unavailable'; end if;
  v_ok:=public.answer_matches(v_q.type,to_jsonb(p_answer),v_key.correct);
  update public.practice_notebook set correct_streak=case when v_ok then least(correct_streak+1,2) else 0 end,
    tries=tries+1,updated_at=now() where user_id=p_user and question_id=p_question returning correct_streak into v_streak;
  return jsonb_build_object('correct',v_ok,'streak',v_streak,'mastered',v_streak=2,
    'answer',v_key.correct,'explanation',v_key.explanation);
end $$;

create or replace function public.practice_drill_state(p_user uuid,p_track text,p_drill uuid default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_drill public.practice_drills%rowtype; v_items jsonb;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  if p_drill is null then
    select * into v_drill from public.practice_drills where user_id=p_user and track_id=p_track
      and completed_at is null and created_at>now()-interval '1 day' order by created_at desc limit 1;
  else
    select * into v_drill from public.practice_drills where id=p_drill and user_id=p_user and track_id=p_track;
  end if;
  if not found then return jsonb_build_object('drill_id',null,'questions','[]'::jsonb,'completed',false); end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'stem',q.stem,'topic',q.topic,
    'type',q.type,'choices',q.choices,'assets',q.assets,
    'answer',case when v_drill.completed_at is not null then k.correct else null end,
    'explanation',case when v_drill.completed_at is not null then k.explanation else null end,
    'submitted',case when v_drill.completed_at is not null then v_drill.answers->q.id::text else null end)
    order by ord.n),'[]'::jsonb) into v_items
  from unnest(v_drill.question_ids) with ordinality ord(id,n)
  join public.questions q on q.id=ord.id join public.question_keys k on k.question_id=q.id;
  return jsonb_build_object('drill_id',v_drill.id,'topics',v_drill.topics,'questions',v_items,
    'completed',v_drill.completed_at is not null,'score',v_drill.score);
end $$;

create or replace function public.practice_drill_start(p_user uuid,p_track text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_topics text[]; v_ids uuid[]; v_id uuid;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  select id into v_id from public.practice_drills where user_id=p_user and track_id=p_track
    and completed_at is null and created_at>now()-interval '1 day' order by created_at desc limit 1;
  if found then return public.practice_drill_state(p_user,p_track,v_id); end if;
  select array_agg(lesson) into v_topics from (
    select lesson from jsonb_to_recordset(public.student_dashboard(p_user,p_track)->'lessons')
      as l(lesson text,seen int,percent numeric)
    where seen>=3 order by percent asc nulls last,lesson limit 3
  ) ranked;
  if cardinality(v_topics) is null then raise exception 'not_enough_topic_history'; end if;
  select array_agg(id) into v_ids from (
    select q.id from public.questions q join public.question_keys k on k.question_id=q.id
    where q.track_id=p_track and q.topic=any(v_topics)
      and (nullif(q.assets->>'verified_release','') is not null or exists (
        select 1 from public.exams e where e.track_id=p_track and e.is_published and q.id=any(e.question_ids)))
      and nullif(q.assets->>'release_hold_reason','') is null
      and jsonb_typeof(k.correct) in ('string','array') and length(btrim(k.explanation))>0
    order by random() limit 18
  ) picked;
  if coalesce(cardinality(v_ids),0)<15 then raise exception 'not_enough_drill_questions'; end if;
  insert into public.practice_drills(user_id,track_id,topics,question_ids)
    values(p_user,p_track,v_topics,v_ids) returning id into v_id;
  return public.practice_drill_state(p_user,p_track,v_id);
end $$;

create or replace function public.practice_drill_submit(p_user uuid,p_track text,p_drill uuid,p_answers jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_drill public.practice_drills%rowtype; v_score int;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  select * into v_drill from public.practice_drills
    where id=p_drill and user_id=p_user and track_id=p_track for update;
  if not found then raise exception 'drill_not_found'; end if;
  if v_drill.completed_at is not null then return public.practice_drill_state(p_user,p_track,p_drill); end if;
  if jsonb_typeof(p_answers) is distinct from 'object'
    or (select count(*) from jsonb_object_keys(p_answers))<>cardinality(v_drill.question_ids)
    or exists(select 1 from jsonb_object_keys(p_answers) as answer_key(qid) where not answer_key.qid=any(select unnest(v_drill.question_ids)::text))
    or exists(select 1 from unnest(v_drill.question_ids) as selected(qid)
      join public.questions q on q.id=selected.qid where jsonb_typeof(p_answers->selected.qid::text) is distinct from 'string'
      or length(p_answers->>selected.qid::text)>250 or length(p_answers->>selected.qid::text)=0
      or (q.type='mcq' and not exists(select 1 from jsonb_array_elements(q.choices) c where c->>'key'=p_answers->>selected.qid::text)))
  then raise exception 'invalid_answers'; end if;
  select count(*) into v_score from unnest(v_drill.question_ids) as selected(qid)
    join public.questions q on q.id=selected.qid join public.question_keys k on k.question_id=q.id
    where public.answer_matches(q.type,p_answers->selected.qid::text,k.correct);
  update public.practice_drills set answers=p_answers,score=v_score,completed_at=now() where id=p_drill;
  return public.practice_drill_state(p_user,p_track,p_drill);
end $$;

revoke all on function public.practice_notebook_state(uuid,text,integer),
  public.practice_notebook_answer(uuid,text,uuid,text),public.practice_drill_state(uuid,text,uuid),
  public.practice_drill_start(uuid,text),public.practice_drill_submit(uuid,text,uuid,jsonb)
  from public,anon,authenticated;
grant execute on function public.practice_notebook_state(uuid,text,integer),
  public.practice_notebook_answer(uuid,text,uuid,text),public.practice_drill_state(uuid,text,uuid),
  public.practice_drill_start(uuid,text),public.practice_drill_submit(uuid,text,uuid,jsonb)
  to service_role;
