-- Passwords and recovery tokens never enter these tables. Service-only APIs.
begin;
create table public.password_recovery_requests (
 id uuid primary key,
 user_id uuid references public.profiles(id) on delete set null,
 login text not null check(char_length(login) between 3 and 254),
 account_email text not null check(char_length(account_email)<=254),
 full_name text not null check(char_length(full_name) between 2 and 100),
 phone text not null default '' check(char_length(phone)<=30),
 group_note text not null default '' check(char_length(group_note)<=120),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 created_at timestamptz not null default now(),
 reviewed_at timestamptz, reviewed_by uuid references public.profiles(id),
 issue_nonce uuid, issue_started_at timestamptz, link_issued_at timestamptz
);
create index password_recovery_queue on public.password_recovery_requests(status,created_at desc,id);
create index password_recovery_email on public.password_recovery_requests(account_email,created_at desc);
create index password_recovery_user on public.password_recovery_requests(user_id);
create index password_recovery_reviewer on public.password_recovery_requests(reviewed_by);
alter table public.password_recovery_requests enable row level security;
revoke all on public.password_recovery_requests from public,anon,authenticated;
grant all on public.password_recovery_requests to service_role;
create table portal_private.password_recovery_limits (
 key text primary key, bucket timestamptz not null, hits integer not null
);
create index password_recovery_limit_age on portal_private.password_recovery_limits(bucket);
alter table portal_private.password_recovery_limits enable row level security;
revoke all on portal_private.password_recovery_limits from public,anon,authenticated;
grant usage on schema portal_private to service_role;
grant all on portal_private.password_recovery_limits to service_role;

create function public.password_recovery_rate_limit(p_key text) returns boolean
language plpgsql security invoker set search_path='' as $$
declare n integer; total integer;
begin
 if p_key is null or p_key !~ '^[a-f0-9]{64}$' then return false; end if;
 insert into portal_private.password_recovery_limits as l values(p_key,date_trunc('hour',now()),1)
 on conflict(key) do update set bucket=excluded.bucket,hits=case when l.bucket=excluded.bucket then l.hits+1 else 1 end returning hits into n;
 insert into portal_private.password_recovery_limits as l values('global',date_trunc('day',now()),1)
 on conflict(key) do update set bucket=excluded.bucket,hits=case when l.bucket=excluded.bucket then l.hits+1 else 1 end returning hits into total;
 delete from portal_private.password_recovery_limits where bucket<now()-interval '2 days';
 return n<=10 and total<=200;
end $$;

create function public.password_recovery_submit(p_id uuid,p_login text,p_email text,p_name text,p_phone text,p_group text) returns void
language plpgsql security invoker set search_path='' as $$
declare uid uuid;
begin
 -- Dedupe under a transaction lock; retries never overwrite the first request.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_email,81926));
 if exists(select 1 from public.password_recovery_requests where id=p_id or (account_email=p_email and status='pending' and created_at>now()-interval '7 days')) then return; end if;
 -- Nonexistent, suspended and staff logins receive the same public response.
 select id into uid from public.profiles where lower(email)=p_email and role='student' and status='active' order by id limit 1;
 insert into public.password_recovery_requests(id,user_id,login,account_email,full_name,phone,group_note)
 values(p_id,uid,p_login,p_email,p_name,p_phone,p_group);
end $$;

create function public.password_recovery_review(p_actor uuid,p_id uuid,p_decision text) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare r public.password_recovery_requests;
begin
 if not exists(select 1 from public.profiles where id=p_actor and role='admin' and status='active') then raise exception 'admin_required'; end if;
 if p_decision is null or p_decision not in ('approved','rejected') then raise exception 'invalid_decision'; end if;
 select * into r from public.password_recovery_requests where id=p_id for update;
 if not found then raise exception 'request_not_found'; end if;
 if r.status=p_decision then return jsonb_build_object('status',r.status); end if;
 if r.status<>'pending' then raise exception 'already_reviewed'; end if;
 if p_decision='approved' then
  if r.created_at<now()-interval '7 days' then raise exception 'request_expired'; end if;
  if not exists(select 1 from public.profiles where id=r.user_id and role='student' and status='active' and lower(email)=r.account_email) then raise exception 'account_unavailable'; end if;
 end if;
 update public.password_recovery_requests set status=p_decision,reviewed_at=now(),reviewed_by=p_actor where id=r.id;
 insert into public.audit_log(actor_id,action,target_type,target_id,meta)
 values(p_actor,'password_recovery.'||p_decision,'user',r.user_id::text,jsonb_build_object('request_id',r.id));
 return jsonb_build_object('status',p_decision);
end $$;

create function public.password_recovery_issue_claim(p_actor uuid,p_id uuid,p_nonce uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare r public.password_recovery_requests;
begin
 if not exists(select 1 from public.profiles where id=p_actor and role='admin' and status='active') then raise exception 'admin_required'; end if;
 select * into r from public.password_recovery_requests where id=p_id for update;
 if not found or r.status<>'approved' then raise exception 'approval_required'; end if;
 if r.reviewed_at<now()-interval '7 days' then raise exception 'request_expired'; end if;
 if not exists(select 1 from public.profiles where id=r.user_id and role='student' and status='active' and lower(email)=r.account_email) then raise exception 'account_unavailable'; end if;
 if r.issue_started_at>now()-interval '60 seconds' then raise exception 'link_busy'; end if;
 if p_nonce is null then raise exception 'invalid_request'; end if;
 update public.password_recovery_requests set issue_nonce=p_nonce,issue_started_at=now() where id=r.id;
 return jsonb_build_object('user_id',r.user_id,'email',r.account_email);
end $$;

create function public.password_recovery_issue_finish(p_actor uuid,p_id uuid,p_nonce uuid,p_success boolean) returns void
language plpgsql security invoker set search_path='' as $$
declare uid uuid;
begin
 if not exists(select 1 from public.profiles where id=p_actor and role='admin' and status='active') then raise exception 'admin_required'; end if;
 update public.password_recovery_requests set issue_nonce=null,issue_started_at=null,
 link_issued_at=case when p_success then now() else link_issued_at end
 where id=p_id and issue_nonce=p_nonce and status='approved' returning user_id into uid;
 if not found then raise exception 'link_busy'; end if;
 if p_success then
  insert into public.audit_log(actor_id,action,target_type,target_id,meta)
  values(p_actor,'password_recovery.link_issued','user',uid::text,jsonb_build_object('request_id',p_id));
 end if;
end $$;

revoke all on function public.password_recovery_rate_limit(text),public.password_recovery_submit(uuid,text,text,text,text,text),public.password_recovery_review(uuid,uuid,text),public.password_recovery_issue_claim(uuid,uuid,uuid),public.password_recovery_issue_finish(uuid,uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.password_recovery_rate_limit(text),public.password_recovery_submit(uuid,text,text,text,text,text),public.password_recovery_review(uuid,uuid,text),public.password_recovery_issue_claim(uuid,uuid,uuid),public.password_recovery_issue_finish(uuid,uuid,uuid,boolean) to service_role;
commit;
