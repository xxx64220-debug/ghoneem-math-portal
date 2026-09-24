-- Complete SAT topic partitions and eight paired 35-minute practice exams.
-- The 352 imported source-bank questions are identified by assets.legacy_index;
-- the two local demo questions are deliberately excluded.

alter table public.exams
  add column if not exists exam_set_code text,
  add column if not exists module_number integer,
  add column if not exists module_count integer;

alter table public.exams drop constraint if exists exams_module_metadata_check;
alter table public.exams add constraint exams_module_metadata_check check (
  (exam_set_code is null and module_number is null and module_count is null)
  or
  (exam_set_code is not null and module_number between 1 and module_count and module_count >= 2)
);

create unique index if not exists exams_module_pair_unique
  on public.exams(track_id, exam_set_code, module_number)
  where exam_set_code is not null;

comment on column public.exams.exam_set_code is 'Groups separately timed modules into one practice exam.';
comment on column public.exams.module_number is 'One-based module position inside exam_set_code.';

-- Module 2 cannot be opened before Module 1 is complete.
create or replace function portal_private.enforce_module_order()
returns trigger language plpgsql security definer set search_path=public as $$
declare e public.exams%rowtype;
begin
  select * into e from public.exams where id=new.exam_id;
  if e.exam_set_code is not null and e.module_number > 1 and not exists (
    select 1
      from public.attempts a
      join public.exams prior on prior.id=a.exam_id
     where a.user_id=new.user_id
       and prior.track_id=e.track_id
       and prior.exam_set_code=e.exam_set_code
       and prior.module_number=e.module_number-1
       and a.status in ('graded','expired')
  ) then
    raise exception 'previous_module_required';
  end if;
  return new;
end $$;

drop trigger if exists enforce_module_order on public.attempts;
create trigger enforce_module_order before insert on public.attempts
for each row execute function portal_private.enforce_module_order();
revoke execute on function portal_private.enforce_module_order() from public,anon,authenticated;

-- Replace partial lesson partitions without changing historical attempts.
do $$
declare r record; old_exam public.exams%rowtype; ids uuid[]; mins integer; new_id uuid;
begin
  for r in
    select topic, count(*) n
      from public.questions
     where track_id='sat' and assets ? 'legacy_index'
     group by topic order by topic
  loop
    select array_agg(id order by (assets->>'legacy_index')::integer)
      into ids from public.questions
     where track_id='sat' and topic=r.topic and assets ? 'legacy_index';
    mins := greatest(15, ceil(r.n * 95.0 / 60.0)::integer);
    select * into old_exam from public.exams
     where track_id='sat' and title=r.topic and assessment_type='lesson_exam' and is_published
     order by created_at desc limit 1;
    if old_exam.id is not null and not exists(select 1 from public.attempts where exam_id=old_exam.id) then
      update public.exams set question_ids=ids,duration_seconds=mins*60,shuffle=true where id=old_exam.id;
    else
      if old_exam.id is not null then update public.exams set is_published=false where id=old_exam.id; end if;
      insert into public.exams(track_id,title,duration_seconds,question_ids,shuffle,review_policy,max_attempts,is_published,is_full_length,assessment_type)
      values('sat',r.topic,mins*60,ids,true,'full_review',1,true,false,'lesson_exam') returning id into new_id;
      insert into public.assignments(exam_id,group_id) values(new_id,public.default_group('sat'));
    end if;
  end loop;
end $$;

-- Deterministically spread every source-bank question across 16 balanced modules.
-- Topic blocks are round-robined so every module receives a mixed syllabus.
do $$
declare set_no integer; mod_no integer; ids uuid[]; v_exam_id uuid; code text; title_ text;
begin
  for set_no in 1..8 loop
    code := 'sat-practice-' || lpad(set_no::text,2,'0');
    for mod_no in 1..2 loop
      select array_agg(id order by slot_order) into ids
      from (
        select id, row_number() over(order by topic,difficulty,(assets->>'legacy_index')::integer) slot_order,
               ((row_number() over(order by topic,difficulty,(assets->>'legacy_index')::integer)-1) % 16)+1 slot
          from public.questions
         where track_id='sat' and assets ? 'legacy_index'
      ) q where slot=(set_no-1)*2+mod_no;

      if coalesce(array_length(ids,1),0) <> 22 then
        raise exception 'SAT module %/% expected 22 questions, got %',set_no,mod_no,coalesce(array_length(ids,1),0);
      end if;
      title_ := 'SAT Practice Exam ' || lpad(set_no::text,2,'0') || ' — Module ' || mod_no;
      insert into public.exams(track_id,title,duration_seconds,question_ids,shuffle,review_policy,max_attempts,is_published,is_full_length,assessment_type,exam_set_code,module_number,module_count)
      values('sat',title_,2100,ids,true,case when mod_no=1 then 'score_only' else 'full_review' end,1,true,false,'full_exam',code,mod_no,2)
      on conflict (track_id,exam_set_code,module_number) where exam_set_code is not null
      do update set title=excluded.title,duration_seconds=2100,question_ids=excluded.question_ids,shuffle=true,
                    review_policy=excluded.review_policy,is_published=true,assessment_type='full_exam',module_count=2
      returning id into v_exam_id;
      if not exists(select 1 from public.assignments a where a.exam_id=v_exam_id) then
        insert into public.assignments(exam_id,group_id) values(v_exam_id,public.default_group('sat'));
      end if;
    end loop;
  end loop;
end $$;

create or replace function public.my_exams(p_user uuid, p_track text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', e.id, 'title', e.title, 'assessment_type', e.assessment_type, 'duration_seconds', e.duration_seconds,
           'questions', coalesce(array_length(e.question_ids,1), 0),
           'exam_set_code',e.exam_set_code,'module_number',e.module_number,'module_count',e.module_count,
           'open', public.student_assignment_for(e.id, p_user) is not null,
           'attempts', (select count(*) from public.attempts a where a.user_id=p_user and a.exam_id=e.id),
           'max_attempts', 1,
           'retake_available', exists(select 1 from retake_grants g where g.user_id=p_user and g.exam_id=e.id and g.consumed_at is null and (g.expires_at is null or g.expires_at>now())),
           'last', (select jsonb_build_object('id',a.id,'status',a.status,'score',a.score,'total',a.total,'scaled_score',a.scaled_score)
                      from public.attempts a where a.user_id=p_user and a.exam_id=e.id order by a.attempt_no desc limit 1)
         ) order by e.created_at), '[]'::jsonb)
    from public.exams e
   where e.track_id=p_track and e.is_published and public.is_enrolled(p_user,p_track)
     and exists (select 1 from public.assignments a where a.exam_id=e.id and
       (a.user_id=p_user or exists(select 1 from public.group_members gm where gm.group_id=a.group_id and gm.user_id=p_user)));
$$;
revoke execute on function public.my_exams(uuid,text) from public,anon,authenticated;
grant execute on function public.my_exams(uuid,text) to service_role;
