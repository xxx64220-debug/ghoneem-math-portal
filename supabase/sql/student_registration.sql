-- Registration passwords are handled only by Supabase Auth.
create table public.student_registration_requests (
 id uuid primary key,user_id uuid not null unique references public.profiles(id) on delete cascade,
 username text not null unique check(username ~ '^[a-z0-9._-]{3,32}$'),
 full_name text not null check(char_length(full_name) between 2 and 100),
 phone text not null default '' check(char_length(phone)<=30),
 track_id text not null references public.tracks(id),
 group_note text not null default '' check(char_length(group_note)<=120),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 created_at timestamptz not null default now(),reviewed_at timestamptz,
 reviewed_by uuid references public.profiles(id),approved_group_id uuid references public.groups(id) on delete set null
);
create index student_registration_queue on public.student_registration_requests(status,created_at desc);
alter table public.student_registration_requests enable row level security;
revoke all on public.student_registration_requests from public,anon,authenticated;
grant all on public.student_registration_requests to service_role;
create table portal_private.registration_limits(key text not null,bucket timestamptz not null,hits integer not null,primary key(key,bucket));
alter table portal_private.registration_limits enable row level security;
revoke all on portal_private.registration_limits from public,anon,authenticated;
grant usage on schema portal_private to service_role;
grant all on portal_private.registration_limits to service_role;
create function public.registration_rate_limit(p_key text) returns boolean language plpgsql security invoker set search_path='' as $$
declare n int; total int;
begin
 if p_key is null or p_key !~ '^[a-f0-9]{64}$' then return false; end if;
 insert into portal_private.registration_limits as l values(p_key,date_trunc('hour',now()),1) on conflict(key,bucket) do update set hits=l.hits+1 returning hits into n;
 insert into portal_private.registration_limits as l values('global',date_trunc('day',now()),1) on conflict(key,bucket) do update set hits=l.hits+1 returning hits into total;
 delete from portal_private.registration_limits where bucket<now()-interval '2 days';
 return n<=6 and total<=300;
end $$;
create function public.registration_complete(p_id uuid,p_user uuid,p_data jsonb) returns void language plpgsql security invoker set search_path='' as $$
begin
 if not exists(select 1 from public.tracks where id=p_data->>'track_id' and is_active) then raise exception 'invalid_track'; end if;
 insert into public.profiles(id,full_name,email,role,status) values(p_user,p_data->>'full_name',p_data->>'email','student','suspended');
 insert into public.student_registration_requests(id,user_id,username,full_name,phone,track_id,group_note) values(p_id,p_user,p_data->>'username',p_data->>'full_name',coalesce(p_data->>'phone',''),p_data->>'track_id',coalesce(p_data->>'group_note',''));
 insert into public.audit_log(action,target_type,target_id,meta) values('registration.submitted','user',p_user::text,jsonb_build_object('request_id',p_id));
end $$;
create function public.registration_review(p_actor uuid,p_id uuid,p_data jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare r public.student_registration_requests;t text;g uuid;starts timestamptz;ends timestamptz;decision text;
begin
 if not exists(select 1 from public.profiles where id=p_actor and role='admin' and status='active') then raise exception 'admin_required'; end if;
 select * into r from public.student_registration_requests where id=p_id for update;
 if not found then raise exception 'request_not_found'; end if;
 decision:=p_data->>'decision';
 if decision is null or decision not in ('approved','rejected') then raise exception 'invalid_decision'; end if;
 if r.status=decision then return jsonb_build_object('status',r.status); end if;
 if r.status<>'pending' then raise exception 'request_already_reviewed'; end if;
 if not exists(select 1 from public.profiles where id=r.user_id and role='student' and status='suspended') then raise exception 'account_changed_refresh'; end if;
 if decision='approved' then
  t:=p_data->>'track_id';g:=nullif(p_data->>'group_id','')::uuid;starts:=nullif(p_data->>'starts_at','')::timestamptz;ends:=nullif(p_data->>'ends_at','')::timestamptz;
  if not exists(select 1 from public.tracks where id=t and is_active) then raise exception 'invalid_track'; end if;
  if g is not null and not exists(select 1 from public.groups where id=g and track_id=t) then raise exception 'group_course_mismatch'; end if;
  if ends is not null and ends<=coalesce(starts,now()) then raise exception 'end_must_follow_start'; end if;
  if exists(select 1 from public.enrollments where user_id=r.user_id) then raise exception 'account_changed_refresh'; end if;
  perform public.enrol_student(r.user_id,t,p_actor);
  update public.enrollments set starts_at=starts,ends_at=ends,course_label=coalesce((select name from public.groups where id=g),'') where user_id=r.user_id and track_id=t;
  if g is not null then insert into public.group_members(group_id,user_id) values(g,r.user_id) on conflict do nothing; end if;
  update public.profiles set status='active' where id=r.user_id;
 end if;
 update public.student_registration_requests set status=decision,reviewed_at=now(),reviewed_by=p_actor,approved_group_id=g where id=r.id;
 insert into public.audit_log(actor_id,action,target_type,target_id,meta) values(p_actor,'registration.'||decision,'user',r.user_id::text,jsonb_build_object('request_id',r.id,'track_id',t,'group_id',g));
 return jsonb_build_object('status',decision);
end $$;
revoke all on function public.registration_rate_limit(text),public.registration_complete(uuid,uuid,jsonb),public.registration_review(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.registration_rate_limit(text),public.registration_complete(uuid,uuid,jsonb),public.registration_review(uuid,uuid,jsonb) to service_role;
