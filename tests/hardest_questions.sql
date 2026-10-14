-- Rollback-only synthetic fixtures. Never run test fixtures on production.
begin;
create temp table hq_ids(name text primary key,id uuid default gen_random_uuid());
insert into hq_ids(name) values ('admin'),('instructor'),('student'),('outsider'),('suspended'),('group');
grant select on hq_ids to authenticated;
insert into auth.users(id,email) select id,name||'-'||id||'@hardest.test' from hq_ids where name<>'group';
insert into public.profiles(id,full_name,role,status)
select id,name,case when name in ('admin','suspended') then 'admin' when name='instructor' then 'instructor' else 'student' end,case when name='suspended' then 'suspended' else 'active' end from hq_ids where name<>'group';
insert into public.tracks(id,name) values('est2','EST Math 2') on conflict do nothing;
insert into public.instructor_tracks(user_id,track_id) select id,'sat' from hq_ids where name='instructor';
insert into public.groups(id,track_id,name,instructor_id) values((select id from hq_ids where name='group'),'sat','Hardest report fixture',(select id from hq_ids where name='instructor'));
insert into public.group_members(group_id,user_id) values((select id from hq_ids where name='group'),(select id from hq_ids where name='student'));
insert into public.enrollments(user_id,track_id) select h.id,t.id from hq_ids h cross join public.tracks t where h.name in ('student','outsider') and t.id in ('sat','est','est2');
create temp table hq_questions(track text,q1 uuid,q2 uuid,exam uuid,attempt uuid);
grant select on hq_questions to authenticated;
do $$
declare t text; q1 uuid; q2 uuid; ex uuid; at uuid; other_at uuid;
begin
 foreach t in array array['sat','est','est2'] loop
  insert into public.questions(track_id,topic,type,stem,choices) values(t,'HQ_TEST','mcq','Two plus two?','[{"key":"A","text":"4"},{"key":"B","text":"5"}]') returning id into q1;
  insert into public.questions(track_id,topic,type,stem) values(t,'HQ_TEST','grid_in','Three quarters?') returning id into q2;
  insert into public.question_keys(question_id,correct,explanation) values(q1,'"A"','Four.'),(q2,'["0.75","3/4"]','Three quarters.');
  insert into public.exams(track_id,title,duration_seconds,question_ids,assessment_type) values(t,'HQ_TEST',600,array[q1,q2],'quiz') returning id into ex;
  insert into public.attempts(user_id,exam_id,attempt_no,shuffle_seed,status,deadline_at) values((select id from hq_ids where name='student'),ex,1,1,'graded',now()) returning id into at;
  insert into public.attempt_results(attempt_id,question_id,is_correct) values(at,q1,false),(at,q2,true);
  insert into public.daily_progress(user_id,track_id,day,quiz_completed_at,answers) values((select id from hq_ids where name='student'),t,current_date,now(),jsonb_build_object(q1::text,'A',q2::text,'3/4'));
  -- Incomplete daily answers must not count.
  insert into public.daily_progress(user_id,track_id,day,answers) values((select id from hq_ids where name='student'),t,current_date-1,jsonb_build_object(q1::text,'A'));
  -- An instructor must not gain access to another instructor's student's attempts.
  insert into public.attempts(user_id,exam_id,attempt_no,shuffle_seed,status,deadline_at) values((select id from hq_ids where name='outsider'),ex,1,2,'graded',now()) returning id into other_at;
  insert into public.attempt_results(attempt_id,question_id,is_correct) values(other_at,q1,false);
  insert into hq_questions values(t,q1,q2,ex,at);
 end loop;
end $$;
select public.test_login((select id from hq_ids where name='admin'));
do $$
begin
 if (select count(*) from public.question_difficulty where lesson='HQ_TEST')<>6 then raise exception 'Admin lost a track';end if;
 if exists(select 1 from public.question_difficulty d join hq_questions h on h.q1=d.question_id where answered_by<>3 or got_it_right<>1 or got_it_wrong<>2 or percent_correct<>33.3 or sources<>'Assigned quiz + Daily quiz') then raise exception 'Combined MCQ statistics changed';end if;
 if exists(select 1 from public.question_difficulty d join hq_questions h on h.q2=d.question_id where answered_by<>2 or got_it_right<>2 or got_it_wrong<>0 or percent_correct<>100) then raise exception 'Numeric aliases or incomplete quiz filtering changed';end if;
 if exists(select 1 from public.question_difficulty a join hq_questions h on h.q1=a.question_id join public.question_difficulty b on b.question_id=h.q2 where a.rank>=b.rank) then raise exception 'Difficulty rank reversed';end if;
end $$;
reset role;
select public.test_login((select id from hq_ids where name='instructor'));
do $$
begin
 if (select count(*) from public.question_difficulty where lesson='HQ_TEST')<>2 then raise exception 'Instructor track boundary changed';end if;
 if exists(select 1 from public.question_difficulty d join hq_questions h on h.q1=d.question_id where answered_by<>2 or percent_correct<>50) then raise exception 'Unrelated student attempts leaked to instructor';end if;
 if exists(select 1 from public.question_keys k join hq_questions h on h.q1=k.question_id where h.track<>'sat') then raise exception 'Other-track keys leaked';end if;
end $$;
reset role;
select public.test_login((select id from hq_ids where name='student'));
do $$
begin
 if exists(select 1 from public.question_difficulty) then raise exception 'Student can read staff report';end if;
 if exists(select 1 from public.question_keys) then raise exception 'Student can read answer keys';end if;
end $$;
reset role;
select public.test_login((select id from hq_ids where name='suspended'));
-- Even a forged/stale role claim must not turn a suspended profile into an admin.
select set_config('request.jwt.claims',jsonb_set(current_setting('request.jwt.claims')::jsonb,'{user_role}','"admin"')::text,true);
do $$
begin
 if exists(select 1 from public.question_difficulty) or exists(select 1 from public.question_keys) then raise exception 'Suspended admin gained access';end if;
end $$;
reset role;
do $$
begin
 if has_table_privilege('anon','public.question_difficulty','select') then raise exception 'Anonymous report access';end if;
 if not exists(select 1 from pg_class where oid='public.question_difficulty'::regclass and 'security_invoker=true'=any(reloptions)) then raise exception 'View bypasses RLS';end if;
 if (select count(*) from pg_policies where schemaname='public' and policyname in ('questions_staff','question_keys_staff','results_read','attempts_read','exams_read','exams_staff_write','daily_progress_staff_read') and qual ilike '%CASE%' and qual ilike '%SELECT is_admin()%')<>7 then raise exception 'Missing cached admin branches';end if;
end $$;
rollback;
