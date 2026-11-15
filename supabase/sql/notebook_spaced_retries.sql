-- Space retries without changing original scores, question eligibility or release gates.
alter table public.practice_notebook add column next_due_at timestamptz not null default (now()+interval '1 day');
update public.practice_notebook set next_due_at=updated_at+case when tries=0 then interval '1 day' when tries=1 then interval '3 days' else interval '7 days' end;
create index practice_notebook_due_idx on public.practice_notebook(user_id,next_due_at) where correct_streak<2;
create function portal_private.schedule_notebook_retry() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='INSERT' then
   new.next_due_at:=new.updated_at+interval '1 day';
 elsif new.tries>old.tries then
   new.next_due_at:=now()+case when new.tries=1 then interval '3 days' else interval '7 days' end;
 elsif new.correct_streak=0 and new.updated_at>old.updated_at then
   new.next_due_at:=now()+interval '1 day';
 end if;
 return new;
end $$;
revoke all on function portal_private.schedule_notebook_retry() from public,anon,authenticated;
create trigger schedule_notebook_retry before insert or update on public.practice_notebook for each row execute function portal_private.schedule_notebook_retry();
CREATE OR REPLACE FUNCTION public.practice_notebook_state(p_user uuid, p_track text, p_offset integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_items jsonb; v_count int; v_done int; v_due int; v_next timestamptz;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  if p_offset<0 or p_offset>10000 then raise exception 'invalid_page'; end if;
  insert into public.practice_notebook(user_id,question_id)
  select distinct p_user,r.question_id from public.attempt_results r
  join public.attempts a on a.id=r.attempt_id join public.exams e on e.id=a.exam_id
  join public.questions q on q.id=r.question_id and q.track_id=e.track_id
  join public.question_keys k on k.question_id=q.id
  where a.user_id=p_user and e.track_id=p_track and r.is_correct=false
    and a.status in ('graded','expired') and a.score is not null
    and e.review_policy='full_review' and a.review_unlocks_at<=now()
    and jsonb_typeof(k.correct) in ('string','array') and portal_private.question_eligible(q,k,p_track,false) on conflict do nothing;
  insert into public.practice_notebook(user_id,question_id)
  select distinct p_user,q.id from public.daily_progress dp
  cross join lateral jsonb_each(dp.answers) answer_(qid,response)
  join public.questions q on q.id=answer_.qid::uuid and q.track_id=dp.track_id
  join public.question_keys k on k.question_id=q.id
  where dp.user_id=p_user and dp.track_id=p_track and dp.quiz_completed_at is not null
    and not public.answer_matches(q.type,answer_.response,k.correct)
    and jsonb_typeof(k.correct) in ('string','array') and portal_private.question_eligible(q,k,p_track,false) on conflict do nothing;
  select count(*) filter(where n.correct_streak<2),count(*) filter(where n.correct_streak=2), count(*) filter(where n.correct_streak<2 and n.next_due_at<=now()), min(n.next_due_at) filter(where n.correct_streak<2 and n.next_due_at>now())
    into v_count,v_done,v_due,v_next from public.practice_notebook n join public.questions q on q.id=n.question_id
    join public.question_keys k on k.question_id=q.id
    where n.user_id=p_user and q.track_id=p_track and portal_private.question_eligible(q,k,p_track,false);
  select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'stem',q.stem,'topic',q.topic,
    'type',q.type,'choices',q.choices,'assets',q.assets,'streak',n.correct_streak,'tries',n.tries,'next_due_at',n.next_due_at)
    order by q.topic,q.id),'[]'::jsonb) into v_items
  from (select n.question_id,n.correct_streak,n.tries,n.updated_at,n.next_due_at
    from public.practice_notebook n join public.questions page_q on page_q.id=n.question_id
    join public.question_keys page_k on page_k.question_id=page_q.id
    where n.user_id=p_user and page_q.track_id=p_track and n.correct_streak<2 and n.next_due_at<=now()
      and portal_private.question_eligible(page_q,page_k,p_track,false)
    order by page_q.topic,n.question_id limit 25 offset p_offset) n
  join public.questions q on q.id=n.question_id;
  return jsonb_build_object('track',p_track,'remaining',v_count,'due_count',v_due,'next_due_at',v_next,'mastered',v_done,'items',v_items,'offset',p_offset);
end $function$;

CREATE OR REPLACE FUNCTION public.practice_notebook_answer(p_user uuid, p_track text, p_question uuid, p_answer text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_q public.questions%rowtype; v_key public.question_keys%rowtype; v_ok boolean; v_streak int;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  select * into v_q from public.questions where id=p_question and track_id=p_track;
  if not found then raise exception 'question_not_found'; end if;
  if length(p_answer)>250 or length(p_answer)=0 then raise exception 'invalid_answer'; end if;
  if v_q.type='mcq' and not exists(select 1 from jsonb_array_elements(v_q.choices) c where c->>'key'=p_answer) then raise exception 'invalid_answer'; end if;
  select * into v_key from public.question_keys where question_id=p_question;
  if not found then raise exception 'question_not_found'; end if;
  if not portal_private.question_eligible(v_q,v_key,p_track,false) then raise exception 'question_content_under_review'; end if;
  -- Serialize repeat taps and prevent grading an unearned or already mastered item.
  perform 1 from public.practice_notebook where user_id=p_user and question_id=p_question and correct_streak<2 and next_due_at<=now() for update;
  if not found then raise exception 'notebook_item_unavailable'; end if;
  v_ok:=public.answer_matches(v_q.type,to_jsonb(p_answer),v_key.correct);
  update public.practice_notebook set correct_streak=case when v_ok then least(correct_streak+1,2) else 0 end,
    tries=tries+1,updated_at=now() where user_id=p_user and question_id=p_question returning correct_streak into v_streak;
  return jsonb_build_object('correct',v_ok,'streak',v_streak,'mastered',v_streak=2,
    'next_due_at',(select next_due_at from public.practice_notebook where user_id=p_user and question_id=p_question),'answer',v_key.correct,'explanation',v_key.explanation);
end $function$;

revoke all on function public.practice_notebook_state(uuid,text,integer),public.practice_notebook_answer(uuid,text,uuid,text) from public,anon,authenticated;
grant execute on function public.practice_notebook_state(uuid,text,integer),public.practice_notebook_answer(uuid,text,uuid,text) to service_role;

