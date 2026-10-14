begin;
do $guard$ begin
if md5(pg_get_functiondef('public.attempt_is_mine(uuid,uuid)'::regprocedure))<>'9bffc3cbae64e8972a69a7b9db7b1082' then raise exception 'management preflight: attempt_is_mine changed; refresh release';end if;
if md5(pg_get_functiondef('public.attempt_review(uuid,uuid)'::regprocedure))<>'e303f416d7121df42f4a3628760b61cb' then raise exception 'management preflight: attempt_review changed; refresh release';end if;
if md5(pg_get_functiondef('public.student_dashboard(uuid,text)'::regprocedure))<>'498f3d79293b135fc9e7a26866fb53d8' then raise exception 'management preflight: student_dashboard changed; refresh release';end if;
if md5(pg_get_functiondef('public.my_tracks(uuid)'::regprocedure))<>'7b8bc5b2c6a2b8c19056861bcc84e439' then raise exception 'management preflight: my_tracks changed; refresh release';end if;
if md5(pg_get_functiondef('public.portal_student_controls(uuid,text,jsonb)'::regprocedure))<>'f122333baf6e5d0a1d492af03bac3e65' then raise exception 'management preflight: portal_student_controls changed; refresh release';end if;
if md5(pg_get_functiondef('public.attempt_live_for(uuid,uuid)'::regprocedure))<>'6ab02d9ef14431d7dd5dda2a55629ca7' then raise exception 'management preflight: attempt_live_for changed; refresh release';end if;
if md5(pg_get_functiondef('portal_private.guard_answer()'::regprocedure))<>'3e11510f84f6d812a172c2b38ea52c96' then raise exception 'management preflight: guard_answer changed; refresh release';end if;
if md5(pg_get_functiondef('public.portal_submit(uuid,uuid,text)'::regprocedure))<>'8e9d14ec633afeb65274b05dea89bb99' then raise exception 'management preflight: portal_submit changed; refresh release';end if;
if md5(pg_get_functiondef('public.portal_start_attempt(uuid,uuid,boolean)'::regprocedure))<>'bb75e509e4c8233f0709911a43acdcef' then raise exception 'management preflight: portal_start_attempt changed; refresh release';end if;
if md5(pg_get_functiondef('public.daily_state(uuid,text)'::regprocedure))<>'e048a5f94884add3c06c24ab4deddaa8' then raise exception 'management preflight: daily_state changed; refresh release';end if;
if md5(pg_get_functiondef('public.daily_submit(uuid,text,jsonb)'::regprocedure))<>'d8ab4aaa2af0e63e61aefceb575cf0cf' then raise exception 'management preflight: daily_submit changed; refresh release';end if;
if md5(pg_get_functiondef('public.final_revision(uuid,text,text,jsonb)'::regprocedure))<>'9152fe78ea9ba38bdd6618f2975b4e96' then raise exception 'management preflight: final_revision changed; refresh release';end if;
if md5(pg_get_functiondef('public.practice_drill_start(uuid,text)'::regprocedure))<>'3a411026c7262e2b550759744bdfa3fd' then raise exception 'management preflight: practice_drill_start changed; refresh release';end if;
if md5(pg_get_functiondef('public.new_exam(text,text,integer,integer,text,boolean,boolean,text,boolean)'::regprocedure))<>'bb2429c0407b46076a16d43c1fdb3722' then raise exception 'management preflight: new_exam changed; refresh release';end if;
if md5(pg_get_functiondef('public.student_daily_quiz_mistakes(uuid,text)'::regprocedure))<>'c4e60eaf91dce3c13f9a02afa89a7ffc' then raise exception 'management preflight: student_daily_quiz_mistakes changed; refresh release';end if;
if md5(pg_get_functiondef('public.my_exams(uuid,text)'::regprocedure))<>'22a7814cad3f359fc4cfcbcfc96f8131' then raise exception 'management preflight: my_exams changed; refresh release';end if;
if md5(pg_get_functiondef('public.portal_push_collect()'::regprocedure))<>'e9a41529ec2f7106831c1b65104e449f' then raise exception 'management preflight: portal_push_collect changed; refresh release';end if;
if md5(pg_get_functiondef('public.portal_push_announce(uuid,uuid,text,text,text)'::regprocedure))<>'368b2caf8c125ce8a10198c509191924' then raise exception 'management preflight: portal_push_announce changed; refresh release';end if;
if md5(pg_get_functiondef('public.is_enrolled(uuid,text)'::regprocedure))<>'fb4c5e8f4354cf2a6dcb5f252f91a8cf' then raise exception 'management preflight: is_enrolled changed';end if;
end $guard$;

-- Course administration and scoped teaching evidence. Existing access/history stay intact.
alter table public.enrollments
 add column starts_at timestamptz,
 add column ends_at timestamptz,
 add column course_label text not null default '',
 add column payment_status text not null default 'unrecorded' check(payment_status in ('unrecorded','pending','paid','waived')),
 add column access_version bigint not null default 0,
 add constraint enrollment_access_dates check(ends_at is null or starts_at is null or ends_at>starts_at),
 add constraint enrollment_course_label check(length(course_label)<=120);
create index enrollment_expiry_idx on public.enrollments(ends_at) where status='active' and ends_at is not null;
alter table public.groups
 add column target_exam_date date,
 add column course_starts_on date,
 add column course_ends_on date,
 add column teaching_plan text not null default '',
 add column plan_version bigint not null default 0,
 add column daily_lessons text[] not null default '{}',
 add constraint group_course_dates check(course_ends_on is null or course_starts_on is null or course_ends_on>=course_starts_on),
 add constraint group_teaching_plan_length check(length(teaching_plan)<=4000);
alter table public.daily_progress add column quiz_group_id uuid references public.groups(id);
create table public.daily_group_quizzes(
 group_id uuid not null references public.groups(id),day date not null,question_ids uuid[] not null check(cardinality(question_ids)=5),
 primary key(group_id,day)
);
alter table public.daily_group_quizzes enable row level security;
revoke all on public.daily_group_quizzes from public,anon,authenticated;
grant all on public.daily_group_quizzes to service_role;

create function portal_private.bump_course_access_version() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin new.access_version:=old.access_version+1;return new;end $$;
revoke all on function portal_private.bump_course_access_version() from public,anon,authenticated;
create trigger course_access_version before update on public.enrollments for each row execute function portal_private.bump_course_access_version();

create table public.course_payments(
 id uuid primary key default gen_random_uuid(), request_id uuid not null unique,
 user_id uuid not null references public.profiles(id),track_id text not null references public.tracks(id),
 amount numeric(12,2) not null check(amount>0),currency text not null default 'EGP' check(currency ~ '^[A-Z]{3}$'),
 paid_on date not null,reference text not null default '' check(length(reference)<=200),
 recorded_by uuid not null references public.profiles(id),recorded_at timestamptz not null default now()
);
create index course_payments_user_track_idx on public.course_payments(user_id,track_id,recorded_at desc);
create index course_payments_recorder_idx on public.course_payments(recorded_by);
alter table public.course_payments enable row level security;
revoke all on public.course_payments from public,anon,authenticated;
grant select on public.course_payments to authenticated;
create policy course_payments_read on public.course_payments for select to authenticated using((select public.is_admin()));


create table public.question_catalogue(
 question_id uuid primary key references public.questions(id),reserve boolean not null default false,
 reason text not null check(length(btrim(reason)) between 5 and 500),updated_by uuid not null references public.profiles(id),updated_at timestamptz not null default now()
);
create index question_catalogue_editor_idx on public.question_catalogue(updated_by);
alter table public.question_catalogue enable row level security;
revoke all on public.question_catalogue from public,anon,authenticated;
grant select on public.question_catalogue to authenticated;
create policy question_catalogue_read on public.question_catalogue for select to authenticated using(
 exists(select 1 from public.questions q where q.id=question_id and public.staff_can_touch_track(q.track_id)));

-- Only current permission opens new practice. Payments are an independently recorded ledger.
create or replace function public.is_enrolled(p_user uuid,p_track text) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.enrollments e join public.profiles p on p.id=e.user_id join public.tracks t on t.id=e.track_id
 where e.user_id=p_user and e.track_id=p_track and e.status='active' and p.status='active' and p.role='student' and t.is_active
 and (e.starts_at is null or e.starts_at<=now()) and (e.ends_at is null or now()<e.ends_at));
$$;
create or replace function portal_private.course_history_access(p_user uuid,p_track text) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.profiles p join public.enrollments e on e.user_id=p.id
 where p.id=p_user and p.status='active' and p.role='student' and e.track_id=p_track
 and (p_user=auth.uid() or public.staff_can_read_student(p_user) or coalesce(current_setting('role',true),'none') in ('service_role','none')));
$$;


-- Finish an already-started timed exam. Untimed lessons have at most two hours after expiry.
create function portal_private.attempt_course_access(p_attempt uuid,p_user uuid,p_submit boolean default false) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.attempts a join public.exams x on x.id=a.exam_id
 join public.enrollments e on e.user_id=a.user_id and e.track_id=x.track_id
 join public.profiles p on p.id=a.user_id join public.tracks t on t.id=x.track_id
 where a.id=p_attempt and a.user_id=p_user and p.role='student' and p.status='active' and e.status='active' and t.is_active
 and (public.is_enrolled(p_user,x.track_id) or (
 e.ends_at is not null and a.started_at<e.ends_at and (e.starts_at is null or a.started_at>=e.starts_at)
 and now()<case when isfinite(a.deadline_at) then a.deadline_at+case when p_submit then interval '1 day' else interval '0' end
 else e.ends_at+interval '2 hours' end)));
$$;
revoke all on function portal_private.attempt_course_access(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function portal_private.attempt_course_access(uuid,uuid,boolean) to service_role;

create function portal_private.require_course_staff(p_track text,p_group uuid default null) returns text
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare role_ text;
begin
 select role into role_ from public.profiles where id=auth.uid() and status='active';
 if auth.uid() is null or role_ is null or role_ not in ('admin','instructor') then raise exception 'staff_required';end if;
 if not exists(select 1 from public.tracks where id=p_track) then raise exception 'choose_track';end if;
 if role_='instructor' and not exists(select 1 from public.instructor_tracks where user_id=auth.uid() and track_id=p_track) then raise exception 'forbidden_track';end if;
 if p_group is not null and not exists(select 1 from public.groups where id=p_group and track_id=p_track and (role_='admin' or instructor_id=auth.uid())) then raise exception 'group_scope_denied';end if;
 return role_;
end $$;
revoke all on function portal_private.require_course_staff(text,uuid) from public,anon,authenticated;

create function portal_private.my_course_access() returns jsonb
language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 if not exists(select 1 from public.profiles where id=auth.uid() and status='active' and role='student') then raise exception 'student_required';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('track_id',e.track_id,'course_label',e.course_label,'status',e.status,
 'starts_at',e.starts_at,'ends_at',e.ends_at,'payment_status',e.payment_status,'practice_open',public.is_enrolled(e.user_id,e.track_id),
 'can_finish',exists(select 1 from public.attempts a join public.exams x on x.id=a.exam_id where a.user_id=e.user_id and x.track_id=e.track_id
 and a.status='in_progress' and now()<a.deadline_at and portal_private.attempt_course_access(a.id,e.user_id,false))) order by e.track_id)
 from public.enrollments e where e.user_id=auth.uid()),'[]'::jsonb);
end $$;

create function portal_private.admin_course_enrollments(p_track text default '',p_filter text default 'all',p_search text default '',p_page integer default 0)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result_ jsonb;
begin
 if not coalesce(public.is_admin(),false) then raise exception 'admin_required';end if;
 if p_filter is null or p_filter not in ('all','active','expiring','expired','future','paused','pending','unrecorded') or p_page is null or p_page not between 0 and 100000 or length(coalesce(p_search,''))>200 then raise exception 'invalid_filter';end if;
 with base as materialized(
 select e.*,p.full_name,p.email,p.status account_status,
 case when e.status='paused' then 'paused' when e.starts_at>now() then 'future' when e.ends_at<=now() then 'expired'
 when e.ends_at<=now()+interval '7 days' then 'expiring' else 'active' end access_state
 from public.enrollments e join public.profiles p on p.id=e.user_id where p.role='student'
 and (coalesce(p_track,'')='' or e.track_id=p_track)
 and (coalesce(p_search,'')='' or strpos(lower(concat_ws(' ',p.full_name,p.email,e.course_label)),lower(p_search))>0)
 ), filtered as(select * from base where p_filter='all' or access_state=p_filter or (p_filter in ('pending','unrecorded') and payment_status=p_filter)),
 page_ as(select * from filtered order by ends_at nulls last,full_name,user_id,track_id limit 50 offset p_page*50)
 select jsonb_build_object('total',(select count(*) from filtered),'page',p_page,'items',coalesce((select jsonb_agg(to_jsonb(x) order by ends_at nulls last,full_name,user_id,track_id) from page_ x),'[]'::jsonb),
 'summary',jsonb_build_object('active',(select count(*) from base where access_state='active'),'expiring',(select count(*) from base where access_state='expiring'),'expired',(select count(*) from base where access_state='expired'),'unrecorded',(select count(*) from base where payment_status='unrecorded'))) into result_;
 return result_;
end $$;

create function portal_private.admin_save_course_access(p_user uuid,p_track text,p_data jsonb,p_expected_version bigint) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare old_ public.enrollments%rowtype; new_ public.enrollments%rowtype;
begin
 if not coalesce(public.is_admin(),false) then raise exception 'admin_required';end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' or p_data->>'status' is null or p_data->>'payment_status' is null then raise exception 'invalid_access_data';end if;
 if not exists(select 1 from public.profiles where id=p_user and role='student') or not exists(select 1 from public.tracks where id=p_track and is_active) then raise exception 'invalid_student_or_track';end if;
 perform pg_advisory_xact_lock(hashtextextended('course:'||p_user::text||':'||p_track,0));
 select * into old_ from public.enrollments where user_id=p_user and track_id=p_track for update;
 if not found or old_.access_version is distinct from p_expected_version then raise exception 'access_changed_refresh';end if;
 update public.enrollments set status=p_data->>'status',payment_status=p_data->>'payment_status',
 starts_at=nullif(p_data->>'starts_at','')::timestamptz,ends_at=nullif(p_data->>'ends_at','')::timestamptz,
 course_label=btrim(coalesce(p_data->>'course_label','')),access_version=access_version+1
 where user_id=p_user and track_id=p_track returning * into new_;
 insert into public.audit_log(actor_id,action,target_type,target_id,meta) values(auth.uid(),'course.access_saved','user',p_user::text,jsonb_build_object('before',to_jsonb(old_),'after',to_jsonb(new_)));
 return to_jsonb(new_);
end $$;

create function portal_private.admin_record_course_payment(p_user uuid,p_track text,p_amount numeric,p_currency text,p_paid_on date,p_reference text,p_request uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare old_ public.course_payments%rowtype; new_ public.course_payments%rowtype;
begin
 if not coalesce(public.is_admin(),false) then raise exception 'admin_required';end if;
 if p_request is null or p_amount is null or p_amount<=0 or p_amount::text in ('NaN','Infinity','-Infinity') or p_amount>9999999999.99 or p_amount<>round(p_amount,2) or p_paid_on is null or p_paid_on>(now() at time zone 'Africa/Cairo')::date
 or p_currency is null or p_currency !~ '^[A-Z]{3}$' or length(coalesce(p_reference,''))>200 then raise exception 'invalid_payment';end if;
 perform pg_advisory_xact_lock(hashtextextended('payment:'||p_request::text,0));
 select * into old_ from public.course_payments where request_id=p_request;
 if found then
 if old_.user_id is distinct from p_user or old_.track_id is distinct from p_track or old_.amount is distinct from p_amount or old_.currency is distinct from p_currency
 or old_.paid_on is distinct from p_paid_on or old_.reference is distinct from coalesce(p_reference,'') then raise exception 'payment_request_conflict';end if;
 return to_jsonb(old_);end if;
 if not exists(select 1 from public.enrollments where user_id=p_user and track_id=p_track) then raise exception 'enrollment_required';end if;
 insert into public.course_payments(request_id,user_id,track_id,amount,currency,paid_on,reference,recorded_by)
 values(p_request,p_user,p_track,p_amount,p_currency,p_paid_on,coalesce(p_reference,''),auth.uid()) returning * into new_;
 insert into public.audit_log(actor_id,action,target_type,target_id,meta) values(auth.uid(),'course.payment_recorded','user',p_user::text,to_jsonb(new_));
 return to_jsonb(new_);
end $$;

create function portal_private.staff_save_group_plan(p_group uuid,p_data jsonb,p_expected_version bigint) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare old_ public.groups%rowtype; new_ public.groups%rowtype;
begin
 select * into old_ from public.groups where id=p_group for update;
 if not found then raise exception 'group_scope_denied';end if;
 perform portal_private.require_course_staff(old_.track_id,p_group);
 if old_.plan_version is distinct from p_expected_version then raise exception 'plan_changed_refresh';end if;
 if jsonb_typeof(p_data->'daily_lessons') is distinct from 'array' or jsonb_array_length(p_data->'daily_lessons')>10 then raise exception 'invalid_daily_lessons';end if;
 if exists(select 1 from jsonb_array_elements_text(p_data->'daily_lessons') l where not exists(select 1 from public.questions q where q.track_id=old_.track_id and q.topic=l)) then raise exception 'lesson_track_mismatch';end if;
 if jsonb_array_length(p_data->'daily_lessons')>0 and (select count(*) from public.questions q join public.question_keys k on k.question_id=q.id
 where q.track_id=old_.track_id and q.topic in(select jsonb_array_elements_text(p_data->'daily_lessons')) and portal_private.question_eligible(q,k,old_.track_id,true)
 and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve))<5 then raise exception 'group_needs_five_ready_questions';end if;
 update public.groups set target_exam_date=nullif(p_data->>'target_exam_date','')::date,course_starts_on=nullif(p_data->>'course_starts_on','')::date,
 course_ends_on=nullif(p_data->>'course_ends_on','')::date,teaching_plan=coalesce(p_data->>'teaching_plan',''),plan_version=plan_version+1
 ,daily_lessons=array(select jsonb_array_elements_text(p_data->'daily_lessons'))
 where id=p_group returning * into new_;
 insert into public.audit_log(actor_id,action,target_type,target_id,meta) values(auth.uid(),'group.plan_saved','group',p_group::text,jsonb_build_object('before',to_jsonb(old_),'after',to_jsonb(new_)));
 return to_jsonb(new_);
end $$;

create function portal_private.staff_course_lessons(p_track text) returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 perform portal_private.require_course_staff(p_track);
 return coalesce((select jsonb_agg(topic order by topic) from(select distinct topic from public.questions where track_id=p_track and btrim(topic)<>'') x),'[]'::jsonb);
end $$;

-- Catalogue reserve affects future automatic selections, never existing exam/review eligibility.
create function portal_private.staff_question_reserve(p_question uuid,p_reserve boolean,p_reason text,p_expected_hash text) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare q public.questions%rowtype;
begin
 select * into q from public.questions where id=p_question for update;
 if not found then raise exception 'question_not_found';end if;
 perform portal_private.require_course_staff(q.track_id);
 if not coalesce(public.is_admin(),false) then raise exception 'admin_required';end if;
 if p_reserve is null or length(btrim(coalesce(p_reason,''))) not between 5 and 500 then raise exception 'reason_required';end if;
 if md5(coalesce((select to_jsonb(c)::text from public.question_catalogue c where c.question_id=q.id),'{}')) is distinct from p_expected_hash then raise exception 'question_changed_refresh';end if;
 insert into public.question_catalogue(question_id,reserve,reason,updated_by) values(q.id,p_reserve,btrim(p_reason),auth.uid())
 on conflict(question_id) do update set reserve=excluded.reserve,reason=excluded.reason,updated_by=excluded.updated_by,updated_at=clock_timestamp();
 insert into public.audit_log(actor_id,action,target_type,target_id,meta) values(auth.uid(),'question.reserve_changed','question',q.id::text,jsonb_build_object('reserve',p_reserve,'reason',btrim(p_reason)));
 return jsonb_build_object('id',q.id,'reserve',p_reserve);
end $$;

-- First and latest scored response per student/question, with explicit cohort scope.
create function portal_private.staff_bank_operations(p_track text,p_group uuid default null,p_cycle uuid default null,p_filter text default 'all',p_page integer default 0)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare role_ text; start_ timestamptz:='-infinity';end_ timestamptz:='infinity';result_ jsonb;
begin
 role_:=portal_private.require_course_staff(p_track,p_group);
 if p_filter is null or p_filter not in ('all','unused','underused','hardest','held','pending','reserve') or p_page is null or p_page not between 0 and 100000 then raise exception 'invalid_filter';end if;
 if p_cycle is not null then
 select starts_at,coalesce(ends_at,'infinity') into start_,end_ from public.hardest_cycles where id=p_cycle and track_id=p_track;
 if not found then raise exception 'cycle_track_mismatch';end if;end if;
 with learners as materialized(
 select p.id from public.profiles p where p.role='student'
 and (exists(select 1 from public.enrollments en where en.user_id=p.id and en.track_id=p_track)
 or exists(select 1 from public.attempts a join public.exams e on e.id=a.exam_id where a.user_id=p.id and e.track_id=p_track)
 or exists(select 1 from public.daily_progress d where d.user_id=p.id and d.track_id=p_track))
 and (role_='admin' or exists(select 1 from public.group_members gm join public.groups g on g.id=gm.group_id
 where gm.user_id=p.id and g.track_id=p_track and g.instructor_id=auth.uid()))
 and (p_group is null or exists(select 1 from public.group_members gm where gm.user_id=p.id and gm.group_id=p_group))
 ),events as materialized(
 select r.question_id,a.user_id,r.is_correct,a.started_at at_,a.id::text||':'||r.question_id::text event_
 from public.attempt_results r join public.attempts a on a.id=r.attempt_id join public.exams e on e.id=a.exam_id
 join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
 where e.track_id=p_track and q.track_id=p_track and a.user_id in(select id from learners)
 and a.status in ('submitted','graded','expired') and a.score is not null and r.is_correct is not null
 and coalesce(k.correct->>'void','false')<>'true' and a.started_at>=start_ and a.started_at<end_
 union all
 select q.id,d.user_id,public.answer_matches(q.type,d.answers->q.id::text,k.correct),d.quiz_completed_at,
 d.user_id::text||':'||d.track_id||':'||d.day::text||':'||q.id::text
 from public.daily_progress d cross join lateral jsonb_object_keys(d.answers) x(id)
 join public.questions q on q.id::text=x.id join public.question_keys k on k.question_id=q.id
 where d.track_id=p_track and q.track_id=p_track and d.user_id in(select id from learners)
 and d.quiz_completed_at is not null and d.quiz_score is not null and coalesce(k.correct->>'void','false')<>'true'
 and d.answers->x.id is not null and jsonb_typeof(d.answers->x.id)<>'null'
 and d.quiz_completed_at>=start_ and d.quiz_completed_at<end_
 ),per_student as materialized(
 select question_id,user_id,count(*) responses,(array_agg(is_correct order by at_,event_))[1] first_correct,
 (array_agg(is_correct order by at_ desc,event_ desc))[1] latest_correct,max(at_) last_used
 from events group by question_id,user_id
 ),metrics as materialized(
 select question_id,count(*)::int unique_students,sum(responses)::int responses,
 count(*) filter(where first_correct)::int first_correct,count(*) filter(where latest_correct)::int latest_correct,
 count(*) filter(where not first_correct and responses>1)::int repeat_candidates,
 count(*) filter(where not first_correct and responses>1 and latest_correct)::int improved,max(last_used) last_used
 from per_student group by question_id
 ),exposure as materialized(
 select qid,count(distinct e.id)::int published_exams,count(distinct a.id)::int assignments
 from public.exams e cross join lateral unnest(e.question_ids) qid left join public.assignments a on a.exam_id=e.id
 and (p_group is null or a.group_id=p_group or a.user_id in(select id from learners))
 and (role_='admin' or a.user_id in(select id from learners) or exists(select 1 from public.groups ag where ag.id=a.group_id and ag.track_id=p_track and ag.instructor_id=auth.uid()))
 where e.track_id=p_track and e.is_published and (role_='admin' or exists(select 1 from public.assignments a2 where a2.exam_id=e.id
 and (a2.user_id in(select id from learners) or exists(select 1 from public.groups g where g.id=a2.group_id and g.instructor_id=auth.uid() and g.track_id=p_track))))
 group by qid
 ),bank as materialized(
 select q.id,q.topic lesson,left(q.stem,160) stem,q.difficulty,md5(coalesce(to_jsonb(c)::text,'{}')) assets_hash,
 coalesce(q.assets->>'source_code',q.id::text) code,
 portal_private.question_eligible(q,k,p_track,false) ready,coalesce(q.assets->>'release_hold_reason','') hold_reason,
 coalesce(q.assets->>'answer_review_status','') math_review,
 coalesce(c.reserve,false) reserve,
 coalesce(m.unique_students,0) unique_students,coalesce(m.responses,0) responses,
 round(100.0*m.first_correct/nullif(m.unique_students,0),1) first_success,
 round(100.0*m.latest_correct/nullif(m.unique_students,0),1) latest_success,
 coalesce(m.repeat_candidates,0) repeat_candidates,coalesce(m.improved,0) improved,
 round(100.0*m.improved/nullif(m.repeat_candidates,0),1) repeat_improvement,m.last_used,
 coalesce(x.published_exams,0) published_exams,coalesce(x.assignments,0) assignments
 from public.questions q left join public.question_catalogue c on c.question_id=q.id left join public.question_keys k on k.question_id=q.id left join metrics m on m.question_id=q.id
 left join exposure x on x.qid=q.id where q.track_id=p_track and coalesce(q.assets->>'bank_removed','false')<>'true'
 ),filtered as(select * from bank where p_filter='all' or (p_filter='unused' and ready and not reserve and assignments=0 and responses=0)
 or (p_filter='underused' and ready and assignments>0 and unique_students<3) or (p_filter='hardest' and unique_students>0)
 or (p_filter='held' and not ready) or (p_filter='pending' and math_review<>'independently_solved') or (p_filter='reserve' and reserve)),
 page_ as(select * from filtered order by case when p_filter='hardest' then first_success end asc nulls last,
 case when p_filter='hardest' then unique_students end desc,lesson,id limit 50 offset p_page*50)
 select jsonb_build_object('track',p_track,'group',p_group,'cycle',p_cycle,'total',(select count(*) from filtered),'page',p_page,
 'items',coalesce((select jsonb_agg(to_jsonb(p) order by case when p_filter='hardest' then first_success end asc nulls last,
 case when p_filter='hardest' then unique_students end desc,lesson,id) from page_ p),'[]'::jsonb),
 'summary',jsonb_build_object('total',(select count(*) from bank),'unused',(select count(*) from bank where ready and not reserve and assignments=0 and responses=0),
 'held',(select count(*) from bank where not ready),'reserve',(select count(*) from bank where reserve),'students',(select count(*) from learners))) into result_;
 return result_;
end $$;

create function public.course_history_access(p_user uuid,p_track text) returns boolean language sql security invoker set search_path=public,pg_temp as $$select portal_private.course_history_access(p_user,p_track);$$;
revoke all on function portal_private.course_history_access(uuid,text) from public,anon,authenticated;
grant execute on function portal_private.course_history_access(uuid,text) to authenticated,service_role;

create function public.my_course_access() returns jsonb language sql security invoker set search_path=public,pg_temp as $$select portal_private.my_course_access();$$;
revoke all on function portal_private.my_course_access() from public,anon,authenticated;
grant execute on function portal_private.my_course_access() to authenticated,service_role;

create function public.admin_course_enrollments(p_track text default '',p_filter text default 'all',p_search text default '',p_page integer default 0) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select portal_private.admin_course_enrollments(p_track,p_filter,p_search,p_page);$$;
revoke all on function portal_private.admin_course_enrollments(text,text,text,integer) from public,anon,authenticated;
grant execute on function portal_private.admin_course_enrollments(text,text,text,integer) to authenticated,service_role;

create function public.admin_save_course_access(p_user uuid,p_track text,p_data jsonb,p_expected_version bigint) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select portal_private.admin_save_course_access(p_user,p_track,p_data,p_expected_version);$$;
revoke all on function portal_private.admin_save_course_access(uuid,text,jsonb,bigint) from public,anon,authenticated;
grant execute on function portal_private.admin_save_course_access(uuid,text,jsonb,bigint) to authenticated,service_role;

create function public.admin_record_course_payment(p_user uuid,p_track text,p_amount numeric,p_currency text,p_paid_on date,p_reference text,p_request uuid) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select portal_private.admin_record_course_payment(p_user,p_track,p_amount,p_currency,p_paid_on,p_reference,p_request);$$;
revoke all on function portal_private.admin_record_course_payment(uuid,text,numeric,text,date,text,uuid) from public,anon,authenticated;
grant execute on function portal_private.admin_record_course_payment(uuid,text,numeric,text,date,text,uuid) to authenticated,service_role;

create function public.staff_save_group_plan(p_group uuid,p_data jsonb,p_expected_version bigint) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select portal_private.staff_save_group_plan(p_group,p_data,p_expected_version);$$;
revoke all on function portal_private.staff_save_group_plan(uuid,jsonb,bigint) from public,anon,authenticated;
grant execute on function portal_private.staff_save_group_plan(uuid,jsonb,bigint) to authenticated,service_role;

create function public.staff_course_lessons(p_track text) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select portal_private.staff_course_lessons(p_track);$$;
revoke all on function portal_private.staff_course_lessons(text) from public,anon,authenticated;
grant execute on function portal_private.staff_course_lessons(text) to authenticated,service_role;

create function public.staff_question_reserve(p_question uuid,p_reserve boolean,p_reason text,p_expected_hash text) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select portal_private.staff_question_reserve(p_question,p_reserve,p_reason,p_expected_hash);$$;
revoke all on function portal_private.staff_question_reserve(uuid,boolean,text,text) from public,anon,authenticated;
grant execute on function portal_private.staff_question_reserve(uuid,boolean,text,text) to authenticated,service_role;

create function public.staff_bank_operations(p_track text,p_group uuid default null,p_cycle uuid default null,p_filter text default 'all',p_page integer default 0) returns jsonb language sql security invoker set search_path=public,pg_temp as $$select portal_private.staff_bank_operations(p_track,p_group,p_cycle,p_filter,p_page);$$;
revoke all on function portal_private.staff_bank_operations(text,uuid,uuid,text,integer) from public,anon,authenticated;
grant execute on function portal_private.staff_bank_operations(text,uuid,uuid,text,integer) to authenticated,service_role;

-- Explicit ACLs for every new public endpoint. Private helpers stay unexposed.
revoke all on function public.my_course_access(),public.admin_course_enrollments(text,text,text,integer),
 public.admin_save_course_access(uuid,text,jsonb,bigint),public.admin_record_course_payment(uuid,text,numeric,text,date,text,uuid),
 public.staff_save_group_plan(uuid,jsonb,bigint),public.staff_question_reserve(uuid,boolean,text,text),
 public.staff_bank_operations(text,uuid,uuid,text,integer),public.staff_course_lessons(text) from public,anon;
grant execute on function public.my_course_access(),public.admin_course_enrollments(text,text,text,integer),
 public.admin_save_course_access(uuid,text,jsonb,bigint),public.admin_record_course_payment(uuid,text,numeric,text,date,text,uuid),
 public.staff_save_group_plan(uuid,jsonb,bigint),public.staff_question_reserve(uuid,boolean,text,text),
 public.staff_bank_operations(text,uuid,uuid,text,integer),public.staff_course_lessons(text) to authenticated;

revoke all on function public.course_history_access(uuid,text) from public,anon;
grant execute on function public.course_history_access(uuid,text) to authenticated,service_role;

commit;
