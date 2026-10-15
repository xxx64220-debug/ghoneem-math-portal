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

CREATE OR REPLACE FUNCTION public.attempt_is_mine(p_attempt uuid, p_user uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
 select exists(select 1 from attempts a join exams e on e.id=a.exam_id where a.id=p_attempt and a.user_id=p_user and course_history_access(p_user,e.track_id));
$function$
;

CREATE OR REPLACE FUNCTION public.attempt_review(p_attempt uuid, p_user uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_att public.attempts%rowtype; v_exam public.exams%rowtype;
        v_open boolean; v_items jsonb;
begin
  select * into v_att from public.attempts where id = p_attempt and user_id = p_user;
  if not found then raise exception 'attempt_not_found'; end if;
  if v_att.status = 'in_progress' then
    raise exception 'attempt_still_live';
  end if;
  select * into v_exam from public.exams where id = v_att.exam_id;
  if not public.course_history_access(p_user,v_exam.track_id) then raise exception 'not_enrolled_in_track'; end if;

  v_open := v_att.score is not null and v_exam.review_policy = 'full_review'
            and v_att.review_unlocks_at is not null
            and now() >= v_att.review_unlocks_at;

  select coalesce(jsonb_agg(x order by x ->> 'ord'), '[]'::jsonb) into v_items
    from (
      select jsonb_build_object(
               'id', q.id, 'ord', lpad(u.ord::text, 4, '0'),
               'type', q.type, 'stem', q.stem, 'choices', q.choices, 'assets', q.assets,
               'response', aa.response,
               'is_correct', r.is_correct,
               'correct',     case when v_open then k.correct     else null end,
               'explanation', case when v_open then k.explanation else null end) as x
        from unnest(v_exam.question_ids) with ordinality as u(qid, ord)
        join public.questions      q on q.id = u.qid
        join public.question_keys  k on k.question_id = q.id
        left join public.attempt_results r on r.attempt_id = p_attempt and r.question_id = q.id
        left join public.attempt_answers aa on aa.attempt_id = p_attempt and aa.question_id = q.id
    ) s;

  return jsonb_build_object(
    'attempt', jsonb_build_object(
        'id', v_att.id, 'status', v_att.status, 'score', v_att.score,
        'scaled_score', v_att.scaled_score, 'total', v_att.total,
        'time_used', v_att.time_used, 'submitted_at', v_att.submitted_at,
        'review_unlocks_at', v_att.review_unlocks_at),
    'exam', jsonb_build_object('title', v_exam.title, 'track_id', v_exam.track_id,
                               'review_policy', v_exam.review_policy),
    'review_open', v_open,
    'items', case when v_open then v_items else '[]'::jsonb end);
end $function$
;

CREATE OR REPLACE FUNCTION public.student_dashboard(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare history_ jsonb; lessons_ jsonb; summary_ jsonb;
begin
 if not public.course_history_access(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',a.id,'exam_id',e.id,'title',e.title,'assessment_type',e.assessment_type,
  'attempt_no',a.attempt_no,'status',a.status,'score',a.score,'total',a.total,
  'percent',round(100.0*a.score/nullif(a.total,0)),'scaled_score',a.scaled_score,
  'submitted_at',a.submitted_at,'time_used',a.time_used,
  'review_open',e.review_policy='full_review' and a.review_unlocks_at is not null and a.review_unlocks_at<=now(),
  'review_unlocks_at',a.review_unlocks_at
 ) order by a.submitted_at desc,a.id),'[]'::jsonb) into history_
 from attempts a join exams e on e.id=a.exam_id
 where a.user_id=p_user and e.track_id=p_track and a.status in ('submitted','graded','expired');

 with eligible as (
  select a.* from attempts a join exams e on e.id=a.exam_id
  where a.user_id=p_user and e.track_id=p_track and a.status in ('submitted','graded','expired')
   and e.review_policy='full_review' and a.review_unlocks_at is not null and a.review_unlocks_at<=now()
 ), latest as (
  select distinct on (r.question_id) r.question_id,r.is_correct,a.submitted_at
  from eligible a join attempt_results r on r.attempt_id=a.id
  order by r.question_id,a.submitted_at desc,a.attempt_no desc,a.id
 ), coverage as (
  select coalesce(nullif(btrim(q.topic),''),'Mixed / untagged') as lesson,
  count(*) as seen,count(*) filter(where l.is_correct) as correct,
  max(l.submitted_at) as last_practiced
  from latest l join questions q on q.id=l.question_id
  where q.track_id=p_track
  group by 1
 ), catalog as (
  select distinct coalesce(nullif(btrim(q.topic),''),'Mixed / untagged') as lesson
  from exams e cross join lateral unnest(e.question_ids) as eq(question_id) join questions q on q.id=eq.question_id
  where e.track_id=p_track and q.track_id=p_track
   and ((e.is_published and exam_assigned_to(e.id,p_user)) or exists(select 1 from attempts a where a.exam_id=e.id and a.user_id=p_user and a.status in ('submitted','graded','expired')))
 ), ranked as (
  select c.lesson,coalesce(v.seen,0) as seen,coalesce(v.correct,0) as correct,
   round(100.0*v.correct/nullif(v.seen,0)) as percent,v.last_practiced,
   case when coalesce(v.seen,0)=0 then 'not_started' when v.seen<3 then 'more_evidence'
    when 100.0*v.correct/v.seen<60 then 'focus' when 100.0*v.correct/v.seen<80 then 'practice' else 'strong' end as priority
  from catalog c left join coverage v on v.lesson=c.lesson
 ) select coalesce(jsonb_agg(to_jsonb(r) order by
  case priority when 'focus' then 1 when 'practice' then 2 when 'more_evidence' then 3 when 'not_started' then 4 else 5 end,
  percent nulls last,lesson),'[]'::jsonb) into lessons_ from ranked r;

 select jsonb_build_object('completed',count(*),'average_percent',round(avg(100.0*a.score/nullif(a.total,0))),
 'best_percent',round(max(100.0*a.score/nullif(a.total,0))),
 'questions_answered',coalesce(sum(a.total),0),
 'lessons_to_focus',(select count(*) from jsonb_array_elements(lessons_) l where l->>'priority'='focus'),
 'review_pending',count(*) filter(where not(e.review_policy='full_review' and a.review_unlocks_at is not null and a.review_unlocks_at<=now())))
 into summary_ from attempts a join exams e on e.id=a.exam_id where a.user_id=p_user and e.track_id=p_track and a.status in ('submitted','graded','expired');
 return jsonb_build_object('summary',summary_,'history',history_,'lessons',lessons_);
end $function$
;

CREATE OR REPLACE FUNCTION public.my_tracks(p_user uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', t.id, 'name', t.name, 'theme', t.theme, 'practice_open',public.is_enrolled(p_user,t.id), 'ends_at',en.ends_at, 'starts_at',en.starts_at, 'course_label',en.course_label,
           'exams_available', (
              select count(*) from public.exams e
               where e.track_id = t.id and e.is_published and public.is_enrolled(p_user,t.id)
                 and public.student_assignment_for(e.id, p_user) is not null),
           'attempts_done', (
              select count(*) from public.attempts a
                join public.exams e2 on e2.id = a.exam_id
               where a.user_id = p_user and e2.track_id = t.id
                 and a.status in ('graded','expired'))
         ) order by t.id), '[]'::jsonb)
    from public.tracks t
    join public.enrollments en
      on en.track_id = t.id and en.user_id = p_user and public.course_history_access(p_user,t.id)
   where t.is_active or exists(select 1 from public.attempts a join public.exams x on x.id=a.exam_id where a.user_id=p_user and x.track_id=t.id);
$function$
;

CREATE OR REPLACE FUNCTION public.portal_student_controls(p_user uuid, p_action text, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare track_ text:=p_data->>'track'; role_ text; id_ uuid; request_ uuid; qid uuid;
begin
 select role into role_ from public.profiles where id=p_user and status='active';
 if role_ is null or not exists(select 1 from public.tracks where id=track_ and (is_active or (p_action='settings' and public.course_history_access(p_user,track_)))) then raise exception 'forbidden';end if;
 if role_='student' and not (public.is_enrolled(p_user,track_) or (p_action='settings' and public.course_history_access(p_user,track_))) then raise exception 'not_enrolled_in_track';end if;
 if role_='instructor' and not exists(select 1 from public.instructor_tracks where user_id=p_user and track_id=track_) then raise exception 'forbidden_track';end if;
 if p_action='settings' then
  return jsonb_build_object('track',track_,'revision_visible',track_ in ('sat','est','est2') and coalesce((select revision_visible from public.portal_track_controls where track_id=track_),false));
 end if;
 if p_action<>'report' then raise exception 'invalid_action';end if;
 request_:=(p_data->>'request_id')::uuid;
 if request_ is null then raise exception 'request_id_required';end if;
 select id into id_ from public.portal_reports where user_id=p_user and request_id=request_;
 if id_ is not null then return jsonb_build_object('id',id_,'status','received');end if;
 if p_data->>'kind' not in ('question','functionality') or p_data->>'kind' is null or length(btrim(coalesce(p_data->>'message',''))) not between 10 and 3000 then raise exception 'describe_report_10_to_3000_characters';end if;
 qid:=nullif(p_data->>'question_id','')::uuid;
 if (p_data->>'kind'='question')<>(qid is not null) then raise exception 'question_required';end if;
 if qid is not null and not exists(select 1 from public.questions q where q.id=qid and (q.track_id=track_ or (track_='sat' and exists(select 1 from public.revision_items r where r.question_id=q.id and r.programmes @> array[track_])))) then raise exception 'question_track_mismatch';end if;
 perform pg_advisory_xact_lock(hashtextextended('report:'||p_user::text,0));
 select id into id_ from public.portal_reports where user_id=p_user and request_id=request_;
 if id_ is not null then return jsonb_build_object('id',id_,'status','received');end if;
 if (select count(*) from public.portal_reports where user_id=p_user and created_at>now()-interval '1 hour')>=10 then raise exception 'report_limit_try_later';end if;
 insert into public.portal_reports(user_id,track_id,request_id,kind,question_id,screen,message)
 values(p_user,track_,request_,p_data->>'kind',qid,left(coalesce(p_data->>'screen',''),100),btrim(p_data->>'message'))
 on conflict(user_id,request_id) do update set request_id=excluded.request_id returning id into id_;
 return jsonb_build_object('id',id_,'status','received');
end $function$
;

CREATE OR REPLACE FUNCTION public.attempt_live_for(p_attempt uuid, p_user uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
 select exists(select 1 from attempts a join exams e on e.id=a.exam_id where a.id=p_attempt and a.user_id=p_user and a.status='in_progress' and clock_timestamp()<a.deadline_at and portal_private.attempt_course_access(p_attempt,p_user,false))
 and not exists(select 1 from device_sessions d where d.user_id=p_user and d.session_id=nullif(current_setting('request.jwt.claims',true)::jsonb->>'session_id','')::uuid and d.revoked_at is not null);
$function$
;

CREATE OR REPLACE FUNCTION portal_private.guard_answer()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a public.attempts; e public.exams;
begin
 if TG_OP='UPDATE' and (new.attempt_id<>old.attempt_id or new.question_id<>old.question_id) then raise exception 'answer_identity_immutable'; end if;
 select * into a from attempts where id=new.attempt_id for update;
 if a.status<>'in_progress' or clock_timestamp()>=a.deadline_at then raise exception 'attempt_not_live'; end if;
 select * into e from exams where id=a.exam_id;
 if not(new.question_id=any(e.question_ids)) then raise exception 'question_outside_exam'; end if;
 if not portal_private.attempt_course_access(a.id,a.user_id,false) then raise exception 'not_enrolled_in_track'; end if;
 if new.response is not null and jsonb_typeof(new.response) not in ('string','null') then raise exception 'invalid_response'; end if;
 if length(new.response::text)>1000 then raise exception 'response_too_long'; end if;
 new.answered_at=clock_timestamp(); return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.portal_submit(p_attempt uuid, p_user uuid, p_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare cached portal_private.submissions; payload jsonb;
begin
 perform 1 from attempts a join exams e on e.id=a.exam_id where a.id=p_attempt and a.user_id=p_user and (course_history_access(p_user,e.track_id) and (a.status<>'in_progress' or portal_private.attempt_course_access(a.id,p_user,true))) for update of a;
 if not found then raise exception 'attempt_not_found'; end if;
 select * into cached from portal_private.submissions where attempt_id=p_attempt and user_id=p_user;
 if p_key is not null and cached.idempotency_key=p_key then return jsonb_build_object('status',200,'body',cached.response); end if;
 if (select status from attempts where id=p_attempt)<>'in_progress' then
  return jsonb_build_object('status',409,'body',jsonb_build_object('error','already_submitted','result',attempt_review(p_attempt,p_user)));
 end if;
 perform submit_attempt(p_attempt,p_user);
 payload=attempt_review(p_attempt,p_user);
 if p_key is not null then
  if length(p_key)>128 then raise exception 'invalid_idempotency_key'; end if;
  insert into portal_private.submissions values(p_attempt,p_user,p_key,payload);
 end if;
 return jsonb_build_object('status',200,'body',payload);
end $function$
;

CREATE OR REPLACE FUNCTION public.portal_start_attempt(p_exam uuid, p_user uuid, p_untimed boolean DEFAULT false)
 RETURNS attempts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_exam        public.exams%rowtype;
  v_attempt     public.attempts%rowtype;
  v_assignment  uuid;
  v_used        integer;
  v_limit       integer;
  v_grant       uuid;
  v_duration    integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text||p_exam::text,0));
  if not exists(select 1 from profiles where id=p_user and role='student' and status='active') then raise exception 'student_account_required'; end if;
  select * into v_exam from public.exams where id = p_exam;
  if not found then
    raise exception 'exam_not_found';
  end if;
  if not v_exam.is_published then
    raise exception 'exam_not_published';
  end if;

  if p_untimed and v_exam.assessment_type <> 'lesson_exam' then
    raise exception 'untimed_lessons_only';
  end if;

  -- SAT/EST isolation. The track comes from the exam, never from the client.
  if not (public.is_enrolled(p_user, v_exam.track_id) or exists(select 1 from public.attempts a where a.user_id=p_user and a.exam_id=p_exam and a.status='in_progress' and portal_private.attempt_course_access(a.id,p_user,false))) then
    raise exception 'not_enrolled_in_track';
  end if;

  if (select status from public.profiles where id = p_user) <> 'active' then
    raise exception 'account_suspended';
  end if;

  -- Finalise this student's own stale attempt on this exam before anything
  -- else, so an abandoned session never blocks the partial unique index.
  perform public.finalize_expired_for(p_user, p_exam);

  if not portal_private.exam_content_ready(v_exam.question_ids,v_exam.track_id) then raise exception 'exam_content_under_review'; end if;

  -- Resume a live attempt rather than creating a second one.
  select * into v_attempt from public.attempts
   where user_id = p_user and exam_id = p_exam and status = 'in_progress';
  if found then
    return v_attempt;
  end if;

  v_assignment := public.student_assignment_for(p_exam, p_user);
  if v_assignment is null then
    raise exception 'not_assigned_or_window_closed';
  end if;

  select count(*) into v_used from public.attempts
   where user_id = p_user and exam_id = p_exam;
  v_limit := 1;

  if v_used >= v_limit and v_exam.assessment_type <> 'lesson_exam' then
    select id into v_grant from public.retake_grants
     where user_id = p_user and exam_id = p_exam
       and consumed_at is null
       and (expires_at is null or expires_at > now())
     order by granted_at limit 1 for update;
    if v_grant is null then
      raise exception 'attempt_limit_reached';
    end if;
    update public.retake_grants set consumed_at = now() where id = v_grant;
    insert into public.audit_log(actor_id, action, target_type, target_id, meta)
    values (p_user, 'retake.consumed', 'exam', p_exam::text,
            jsonb_build_object('grant_id', v_grant));
  end if;

  v_duration := coalesce(nullif(v_exam.duration_seconds, 0),
                         (select default_duration_seconds from public.tracks where id = v_exam.track_id));

  insert into public.attempts(user_id, exam_id, assignment_id, attempt_no,
                              shuffle_seed, deadline_at, total)
  values (p_user, p_exam, v_assignment, v_used + 1,
          (floor(random() * 2147483646) + 1)::bigint,
          case when p_untimed then 'infinity'::timestamptz else now() + make_interval(secs => v_duration) end,
          coalesce(array_length(v_exam.question_ids, 1), 0))
  returning * into v_attempt;

  insert into public.audit_log(actor_id, action, target_type, target_id, meta)
  values (p_user, 'attempt.started', 'attempt', v_attempt.id::text,
          jsonb_build_object('exam_id', p_exam, 'attempt_no', v_attempt.attempt_no));

  return v_attempt;

exception when unique_violation then
  -- Two starts raced. The index kept one; return the survivor.
  select * into v_attempt from public.attempts
   where user_id = p_user and exam_id = p_exam and status = 'in_progress';
  if found then return v_attempt; end if;
  raise;
end $function$
;

CREATE OR REPLACE FUNCTION public.daily_state(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  d date := (now() at time zone 'Africa/Cairo')::date;
  qids uuid[]; gid uuid; existing_progress boolean;
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
      and e.track_id=p_track and public.is_enrolled(p_user,p_track)
  ) then raise exception 'not_enrolled_in_track'; end if;

  perform pg_advisory_xact_lock(hashtextextended('daily-user:'||p_user::text||':'||p_track||':'||d::text,0));
  select * into progress_ from public.daily_progress where user_id=p_user and track_id=p_track and day=d;
  existing_progress:=found;
  if existing_progress then gid:=progress_.quiz_group_id;
  else select g.id into gid from public.groups g join public.group_members gm on gm.group_id=g.id
   where gm.user_id=p_user and g.track_id=p_track and g.instructor_id is not null
   and (g.course_starts_on is null or g.course_starts_on<=(now() at time zone 'Africa/Cairo')::date)
   and (g.course_ends_on is null or g.course_ends_on>=(now() at time zone 'Africa/Cairo')::date)
   order by g.created_at desc,g.id limit 1;end if;
  perform pg_advisory_xact_lock(hashtextextended('daily:'||coalesce(gid::text,p_track)||':'||d::text,0));
  if gid is null then select question_ids into qids from public.daily_quizzes where track_id=p_track and day=d;
  else select question_ids into qids from public.daily_group_quizzes where group_id=gid and day=d;end if;
  if qids is null then
  select array(
    select q.id from public.questions q join public.question_keys k on k.question_id=q.id
    where q.track_id=p_track and q.type='mcq' and portal_private.question_eligible(q,k,p_track,true) and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve)
      and ((gid is not null and exists(select 1 from public.groups g where g.id=gid and cardinality(g.daily_lessons)>0 and q.topic=any(g.daily_lessons)))
       or ((gid is null or exists(select 1 from public.groups g where g.id=gid and cardinality(g.daily_lessons)=0))
       and exists(select 1 from public.portal_track_controls c where c.track_id=p_track and
       (c.daily_mode='random' or (c.daily_mode='lessons' and q.topic=any(c.daily_lessons)) or (c.daily_mode='selected' and q.id=any(c.daily_question_ids))))))
    order by md5(d::text || q.id::text) limit 5
  ) into qids;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;
  if gid is null then insert into public.daily_quizzes(track_id,day,question_ids) values(p_track,d,qids);
  else insert into public.daily_group_quizzes(group_id,day,question_ids) values(gid,d,qids);end if;
  end if;
  if coalesce(array_length(qids,1),0)<>5 then raise exception 'daily_questions_unavailable'; end if;

  insert into public.daily_progress(user_id,track_id,day,quiz_group_id) values(p_user,p_track,d,gid)
  on conflict (user_id,track_id,day) do nothing;
  select * into progress_ from public.daily_progress
  where user_id=p_user and track_id=p_track and day=d;

  if progress_.quiz_completed_at is null and (select count(*) from public.questions q join public.question_keys k on k.question_id=q.id where q.id=any(qids) and portal_private.question_eligible(q,k,p_track,true))<>5 then raise exception 'daily_content_under_review'; end if;

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
    where e.track_id=p_track and public.is_enrolled(e.user_id,p_track) and (gid is null or exists(select 1 from public.group_members gm where gm.group_id=gid and gm.user_id=e.user_id))
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
  if progress_.quiz_completed_at is null and (select count(*) from public.questions q join public.question_keys k on k.question_id=q.id where q.id=any(qids) and portal_private.question_eligible(q,k,p_track,true))<>5 then raise exception 'daily_content_under_review'; end if;

  select jsonb_agg(jsonb_build_object('date',d-offset_,
    'completed',exists(select 1 from public.daily_progress p where p.user_id=p_user
      and p.track_id=p_track and p.day=d-offset_ and p.quiz_completed_at is not null),
    'today',offset_=0) order by offset_ desc) into week_ from generate_series(0,6) offset_;

  return jsonb_build_object('date',d,'reset_at',((d+1)::timestamp at time zone 'Africa/Cairo'),
    'server_now',now(),'streak',jsonb_build_object('current',current_,'longest',best_,'week',week_),
    'group_id',gid,'group_name',(select name from public.groups where id=gid),'selection_mode',case when gid is not null and exists(select 1 from public.groups where id=gid and cardinality(daily_lessons)>0) then 'group lessons' else (select daily_mode from public.portal_track_controls where track_id=p_track) end,'track',p_track,'quiz',quiz_,'score',progress_.quiz_score,
    'completed',progress_.quiz_completed_at is not null,
    'checklist',jsonb_build_object('quiz',progress_.quiz_completed_at is not null,
      'focus',progress_.focus_done,'review',progress_.review_done,
      'bonus',progress_.bonus_awarded),
    'points_today',progress_.points,'points_total',coalesce(mytotal_,0),
    'rank',myrank_,'leaderboard',leaders_);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.daily_submit(p_user uuid, p_track text, p_answers jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  select * into progress_ from public.daily_progress where user_id=p_user and track_id=p_track and day=d for update;
  if progress_.quiz_group_id is null then select question_ids into qids from public.daily_quizzes where track_id=p_track and day=d;
  else select question_ids into qids from public.daily_group_quizzes where group_id=progress_.quiz_group_id and day=d;end if;
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
end $function$
;

CREATE OR REPLACE FUNCTION public.final_revision(p_user uuid, p_track text, p_action text, p_options jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
 items jsonb; candidates jsonb; picked jsonb:='[]'; chosen jsonb; seen jsonb;
 s public.revision_sessions%rowtype; sid uuid; qid text; response text;
 scope_ text:=coalesce(p_options->>'scope',p_track);
 source_ text:=coalesce(p_options->>'source','both');
 collection_ text:=coalesce(p_options->>'collection','all');
 level_ text:=coalesce(p_options->>'difficulty','mixed');
 lesson_ text:=coalesce(p_options->>'lesson','');
 total_ int; n int; easy_ int; medium_ int; need_ text; retry_ uuid;
begin
 if p_track not in ('sat','est','est2') or not public.is_enrolled(p_user,p_track)
  or not exists(select 1 from public.profiles where id=p_user and role='student' and status='active')
 then raise exception 'not_enrolled_in_track'; end if;
 if not exists(select 1 from public.portal_track_controls where track_id=p_track and revision_visible) then raise exception 'revision_hidden';end if;
 if p_track in ('est','est2') then scope_:=p_track;source_:=p_track;end if;
 if p_action='state' then return public.final_revision_state(p_user,p_track,(p_options->>'session')::uuid); end if;
 if p_action='answer' then
  select * into s from public.revision_sessions where id=(p_options->>'session')::uuid and user_id=p_user and access_track=p_track for update;
  if not found then raise exception 'revision_session_not_found'; end if;
  qid:=p_options->>'question'; response:=btrim(p_options->>'answer');
  select q into chosen from jsonb_array_elements(s.snapshot) q where q->>'id'=qid and (q->>'source'=p_track or (p_track='sat' and q->>'source'='est'));
  if chosen is null or response is null or length(response) not between 1 and 250
    or jsonb_typeof(p_options->'answer') is distinct from 'string'
    or (chosen->>'type'='mcq' and not exists(select 1 from jsonb_array_elements(chosen->'choices') c where c->>'key'=response))
  then raise exception 'invalid_answer'; end if;
  -- A checked answer is immutable. Network retries return the first result.
  if not s.answers ? qid then
   s.answers:=s.answers||jsonb_build_object(qid,response);
   update public.revision_sessions set answers=s.answers,
    completed_at=case when not exists(select 1 from jsonb_array_elements(s.snapshot) q where (q->>'source'=p_track or (p_track='sat' and q->>'source'='est')) and not s.answers ? (q->>'id')) then now() else null end
    where id=s.id;
  end if;
  return public.final_revision_state(p_user,p_track,s.id);
 end if;
 if p_action not in ('catalogue','start') then raise exception 'invalid_action'; end if;
 -- Hide source edits until reviewed again; holds also take effect immediately.
 select coalesce(jsonb_agg(jsonb_build_object('id',q.id,'lesson',r.lesson,'idea',r.idea,
  'difficulty',r.difficulty,'focus',r.focus,'programmes',r.programmes,'source',q.track_id,
  'type',q.type)),'[]') into candidates
 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
 where r.active and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve) and portal_private.question_eligible(q,k,q.track_id,false) and (q.track_id=p_track or (p_track='sat' and q.track_id='est')) and jsonb_typeof(k.correct) in ('string','array') and nullif(q.assets->>'release_hold_reason','') is null
 and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation);
 select coalesce(jsonb_object_agg(a.key,true),'{}') into seen
 from (select distinct a.key from public.revision_sessions rs cross join lateral jsonb_each(rs.answers) a
       where rs.user_id=p_user) a;
 if p_action='catalogue' then
  select coalesce(jsonb_agg(((q-'stem'-'type'-'choices'-'assets'-'correct'-'explanation') #- '{focus,takeaway}')||jsonb_build_object('practised',seen ? (q->>'id'))),'[]') into items from jsonb_array_elements(candidates) q;
  select id into sid from public.revision_sessions where user_id=p_user and access_track=p_track and completed_at is null and exists(select 1 from jsonb_array_elements(snapshot) q where (q->>'source'=p_track or (p_track='sat' and q->>'source'='est')) and not answers ? (q->>'id')) order by created_at desc limit 1;
  return jsonb_build_object('items',items,'session',case when sid is not null then public.final_revision_state(p_user,p_track,sid) else null end);
 end if;
 if collection_ not in ('all','priority','must_know','repeated','unique') or scope_ not in ('sat','est','est2','both') or source_ not in ('sat','est','est2','both') or level_ not in ('easy','medium','hard','mixed')
   or coalesce(p_options->>'count','10') not in ('10','20') then raise exception 'invalid_revision_filter'; end if;
 total_:=coalesce(p_options->>'count','10')::int;
 retry_:=(p_options->>'retry')::uuid;
 if retry_ is not null then
  select * into s from public.revision_sessions where id=retry_ and user_id=p_user and access_track=p_track and not exists(select 1 from jsonb_array_elements(snapshot) q where (q->>'source'=p_track or (p_track='sat' and q->>'source'='est')) and not answers ? (q->>'id'));
  if not found then raise exception 'revision_session_not_found'; end if;
  select coalesce(jsonb_agg(q),'[]') into candidates from jsonb_array_elements(candidates) q
  where exists(select 1 from jsonb_array_elements(s.snapshot) old where old->>'id'=q->>'id'
   and not public.answer_matches(old->>'type',s.answers->(old->>'id'),old->'correct'));
  lesson_:='Retry mistakes';level_:='mixed';collection_:='all';
 else
  select coalesce(jsonb_agg(q),'[]') into candidates from jsonb_array_elements(candidates) q
  where (scope_='both' or q->'programmes' ? scope_) and (source_='both' or q->>'source'=source_)
    and (level_='mixed' or q->>'difficulty'=level_) and (lesson_='' or q->>'lesson'=lesson_)
    and (collection_='all' or (collection_='priority' and jsonb_array_length(coalesce(q#>'{focus,collections}','[]'))>0) or (q#>'{focus,collections}') ? collection_);
 end if;
 total_:=least(total_,jsonb_array_length(candidates));
 if collection_<>'all' then
  select count(distinct (q->>'lesson',q->>'idea')) into n from jsonb_array_elements(candidates) q;
  total_:=least(total_,n);
 end if;
 if total_=0 then raise exception 'no_revision_questions'; end if;
 easy_:=round(total_*0.3);medium_:=round(total_*0.4);
 for n in 1..total_ loop
  need_:=case when n<=easy_ then 'easy' when n<=easy_+medium_ then 'medium' else 'hard' end;
  select q into chosen from jsonb_array_elements(candidates) q
   where not exists(select 1 from jsonb_array_elements(picked) p where p->>'id'=q->>'id')
    and (collection_='all' or not exists(select 1 from jsonb_array_elements(picked) p where p->>'lesson'=q->>'lesson' and p->>'idea'=q->>'idea'))
   order by case when level_='mixed' and q->>'difficulty'=need_ then 0 else 1 end,
    (select count(*) from jsonb_array_elements(picked) p where p->>'lesson'=q->>'lesson'),
    (select count(*) from jsonb_array_elements(picked) p where p->>'idea'=q->>'idea'),
    case when seen ? (q->>'id') then 1 else 0 end,
    (select count(*) from jsonb_array_elements(picked) p where p->>'source'=q->>'source'),random() limit 1;
  picked:=picked||jsonb_build_array(chosen);
 end loop;
 -- Mix the chosen levels so the answer position never hints at difficulty.
 select jsonb_agg(q order by random()) into picked from jsonb_array_elements(picked) q;
 -- Hydrate only the selected questions. Catalogue and candidate selection do not build image payloads.
 select coalesce(jsonb_agg(p.item || jsonb_build_object('stem',q.stem,'choices',q.choices,
  'assets',(select coalesce(jsonb_object_agg(a.key,a.value),'{}') from jsonb_each(coalesce(q.assets,'{}')) a
    where a.key=any(array['figure','figure_caption','figspec','html','svg','image','image_alt','source_code','source_document','source_question','instructions','reference'])),
  'correct',k.correct,'explanation',k.explanation) order by p.n),'[]') into picked
 from jsonb_array_elements(picked) with ordinality p(item,n)
 join public.questions q on q.id=(p.item->>'id')::uuid
 join public.question_keys k on k.question_id=q.id
 join public.revision_items r on r.question_id=q.id
 where r.active and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve) and portal_private.question_eligible(q,k,q.track_id,false)
  and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation);
 if jsonb_array_length(picked)<>total_ then raise exception 'question_content_under_review'; end if;
 insert into public.revision_sessions(user_id,access_track,lesson,collection,snapshot) values(p_user,p_track,lesson_,collection_,picked) returning id into sid;
 return public.final_revision_state(p_user,p_track,sid);
end $function$
;

CREATE OR REPLACE FUNCTION public.practice_drill_start(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_topics text[]; v_ids uuid[]; v_id uuid;
begin
  if not public.is_enrolled(p_user,p_track) then raise exception 'not_enrolled_in_track'; end if;
  select id into v_id from public.practice_drills where user_id=p_user and track_id=p_track
    and completed_at is null and created_at>now()-interval '1 day'
    and portal_private.exam_content_ready(question_ids,p_track) order by created_at desc limit 1;
  if found then return public.practice_drill_state(p_user,p_track,v_id); end if;
  select array_agg(lesson) into v_topics from (
    select lesson from jsonb_to_recordset(public.student_dashboard(p_user,p_track)->'lessons')
      as l(lesson text,seen int,percent numeric)
    where seen>=3 order by percent asc nulls last,lesson limit 3
  ) ranked;
  if cardinality(v_topics) is null then raise exception 'not_enough_topic_history'; end if;
  select array_agg(id) into v_ids from (
    select q.id from public.questions q join public.question_keys k on k.question_id=q.id
    where q.track_id=p_track and q.topic=any(v_topics) and portal_private.question_eligible(q,k,p_track,false) and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve)
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
end $function$
;

CREATE OR REPLACE FUNCTION public.new_exam(p_track text, p_title text, p_count integer DEFAULT 20, p_minutes integer DEFAULT 35, p_topic text DEFAULT NULL::text, p_publish boolean DEFAULT true, p_assign boolean DEFAULT true, p_if_exists text DEFAULT 'skip'::text, p_full_length boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    from (select q.id, q.difficulty from public.questions q join public.question_keys k on k.question_id=q.id
           where q.track_id = p_track and portal_private.question_eligible(q,k,p_track,false) and not exists(select 1 from public.question_catalogue c where c.question_id=q.id and c.reserve)
             and (p_topic is null or q.topic=p_topic)
           order by case q.difficulty when 'easy' then 1 when 'medium' then 2 else 3 end, q.id
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
end $function$
;

CREATE OR REPLACE FUNCTION public.student_daily_quiz_mistakes(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  items_ jsonb;
begin
  if not exists (
    select 1
    from public.profiles p
    join public.enrollments e on e.user_id = p.id
    join public.tracks t on t.id = e.track_id
    where p.id = p_user
      and p.role = 'student'
      and p.status = 'active'
      and e.track_id = p_track
      and public.course_history_access(p_user,p_track)
  ) then
    raise exception 'not_enrolled_in_track';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'date', dp.day,
    'question_id', q.id,
    'topic', q.topic,
    'stem', q.stem,
    'choices', q.choices,
    'assets', q.assets,
    'submitted', dp.answers ->> q.id::text,
    'correct', k.correct,
    'explanation', k.explanation
  ) order by dp.day desc, q.id), '[]'::jsonb)
  into items_
  from public.daily_progress dp
  cross join lateral jsonb_object_keys(dp.answers) answer_key(question_id)
  join public.questions q on q.id = answer_key.question_id::uuid
  join public.question_keys k on k.question_id = q.id
  where dp.user_id = p_user
    and dp.track_id = p_track
    and dp.quiz_completed_at is not null
    and not public.answer_matches(q.type, dp.answers -> q.id::text, k.correct);

  return jsonb_build_object(
    'track', p_track,
    'count', jsonb_array_length(items_),
    'items', items_
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.my_exams(p_user uuid, p_track text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', e.id, 'title', e.title, 'assessment_type', e.assessment_type, 'duration_seconds', e.duration_seconds,
           'questions', coalesce(array_length(e.question_ids,1), 0),
           'exam_set_code',e.exam_set_code,'module_number',e.module_number,'module_count',e.module_count,
           'content_ready',portal_private.exam_content_ready(e.question_ids,e.track_id),
           'open', public.student_assignment_for(e.id, p_user) is not null and portal_private.exam_content_ready(e.question_ids,e.track_id),
           'attempts', (select count(*) from public.attempts a where a.user_id=p_user and a.exam_id=e.id),
           'max_attempts', case when e.assessment_type='lesson_exam' then null else 1 end,
           'repeatable', e.assessment_type='lesson_exam',
           'allow_untimed', e.assessment_type='lesson_exam',
           'retake_available', public.is_enrolled(p_user,p_track) and (e.assessment_type='lesson_exam' or exists(select 1 from retake_grants g where g.user_id=p_user and g.exam_id=e.id and g.consumed_at is null and (g.expires_at is null or g.expires_at>now()))),
           'last', (select jsonb_build_object('id',a.id,'status',a.status,'untimed',a.deadline_at='infinity'::timestamptz,'score',a.score,'total',a.total,'scaled_score',a.scaled_score)
                      from public.attempts a where a.user_id=p_user and a.exam_id=e.id order by a.attempt_no desc limit 1)
         ) order by e.created_at), '[]'::jsonb)
    from public.exams e
   where e.track_id=p_track and e.is_published and (public.is_enrolled(p_user,p_track) or exists(select 1 from public.attempts a where a.exam_id=e.id and a.user_id=p_user and a.status='in_progress' and portal_private.attempt_course_access(a.id,p_user,false)))
     and exists (select 1 from public.assignments a where a.exam_id=e.id and
       (a.user_id=p_user or exists(select 1 from public.group_members gm where gm.group_id=a.group_id and gm.user_id=p_user)));
$function$
;

CREATE OR REPLACE FUNCTION public.portal_push_collect()
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
 insert into portal_push_releases(exam_id) select id from exams where is_published on conflict do nothing;
 insert into portal_push_queue(subscription_id,event_key,kind,title,body,exam_id)
 select s.id,'exam:'||e.id,'exam','New practice is available',left(e.title,180),e.id
 from portal_push_subscriptions s join profiles p on p.id=s.user_id and p.status='active' and p.role='student'
 join enrollments en on en.user_id=s.user_id and public.is_enrolled(s.user_id,en.track_id)
 join exams e on e.track_id=en.track_id and e.is_published
 join portal_push_releases r on r.exam_id=e.id
 where s.exams and student_assignment_for(e.id,s.user_id) is not null
 and greatest(r.seen_at,coalesce((select max(greatest(a.created_at,a.open_at)) from assignments a where a.exam_id=e.id and (a.user_id=s.user_id or exists(select 1 from group_members gm where gm.group_id=a.group_id and gm.user_id=s.user_id))),r.seen_at))>=s.created_at
 and not exists(select 1 from attempts a where a.user_id=s.user_id and a.exam_id=e.id)
 on conflict do nothing;
 insert into portal_push_queue(subscription_id,event_key,kind,title,body,exam_id)
 select s.id,'result:'||a.id,'result','Your results are ready','Open the portal to view your results.',a.exam_id
 from portal_push_subscriptions s join profiles p on p.id=s.user_id and p.status='active'
 join attempts a on a.user_id=s.user_id join exams e on e.id=a.exam_id
 where s.results and a.status='graded' and a.submitted_at>=s.created_at
 and (a.review_unlocks_at is null or a.review_unlocks_at<=now())
 on conflict do nothing;
 -- Optional reminder, at 18:00 Cairo; one per device/day, never a backlog.
 if extract(hour from now() at time zone 'Africa/Cairo')=18 and extract(minute from now() at time zone 'Africa/Cairo')<10 then
 insert into portal_push_queue(subscription_id,event_key,kind,title,body)
 select s.id,'daily:'||(now() at time zone 'Africa/Cairo')::date,'reminder','Time for your daily practice','Open Ghoneem Math and complete your daily quiz.'
 from portal_push_subscriptions s join profiles p on p.id=s.user_id and p.status='active' and p.role='student'
 where s.reminders and exists(select 1 from enrollments e where e.user_id=s.user_id and is_enrolled(s.user_id,e.track_id))
 on conflict do nothing;
 end if;
 update portal_push_queue set status='failed',error='delivery_expired' where status in ('pending','sending') and created_at<now()-interval '24 hours';
end $function$
;

CREATE OR REPLACE FUNCTION public.portal_push_announce(p_actor uuid, p_id uuid, p_title text, p_body text, p_track text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare n int;
begin
 if not exists(select 1 from profiles where id=p_actor and role='admin' and status='active') then raise exception 'forbidden'; end if;
 if length(trim(p_title)) not between 1 and 80 or length(trim(p_body)) not between 1 and 240 then raise exception 'invalid_message'; end if;
 if exists(select 1 from portal_push_campaigns where id=p_id) then return (select count(*) from portal_push_queue where campaign_id=p_id); end if;
 if exists(select 1 from portal_push_campaigns where created_by=p_actor and created_at>now()-interval '30 seconds') then raise exception 'Please wait 30 seconds before another announcement'; end if;
 insert into portal_push_campaigns(id,created_by,title,body,track_id) values(p_id,p_actor,p_title,p_body,p_track);
 insert into portal_push_queue(subscription_id,event_key,kind,title,body,campaign_id)
 select s.id,'announcement:'||p_id,'announcement',p_title,p_body,p_id from portal_push_subscriptions s
 join profiles p on p.id=s.user_id and p.status='active' and p.role='student'
 where exists(select 1 from enrollments e where e.user_id=s.user_id and is_enrolled(s.user_id,e.track_id) and (p_track is null or e.track_id=p_track));
 get diagnostics n=row_count; return n;
end $function$
;
-- History SELECT never opens fresh practice or another student's rows.
alter policy attempts_read on public.attempts using(
 case when (select public.is_admin()) then true else
 ((user_id=auth.uid() and public.course_history_access(auth.uid(),public.exam_track(exam_id)))
 or (public.staff_can_touch_track(public.exam_track(exam_id)) and public.staff_can_read_student(user_id))) end);
alter policy tracks_read on public.tracks using(public.staff_can_touch_track(id) or public.course_history_access(auth.uid(),id));

commit;
