-- Device approval is separate from authentication. Browser secrets are hashed;
-- a secret never grants access without a valid Auth session for the same user.
create table portal_private.trusted_browsers (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 token_hash text,
 label text not null default 'Browser',
 user_agent text not null default '',
 status text not null check(status in ('pending','approved','revoked')),
 created_at timestamptz not null default now(),
 approved_at timestamptz,
 approved_by uuid references public.profiles(id) on delete set null,
 last_seen timestamptz not null default now(),
 unique(user_id,token_hash)
);
create table portal_private.device_policy (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 max_browsers integer not null default 2 check(max_browsers between 1 and 10)
);
alter table public.device_sessions add column browser_id uuid references portal_private.trusted_browsers(id);
create index devices_browser_idx on public.device_sessions(browser_id);
create index trusted_browsers_user_idx on portal_private.trusted_browsers(user_id,status);
create table portal_private.attempt_devices (
 attempt_id uuid primary key references public.attempts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 browser_id uuid not null references portal_private.trusted_browsers(id),
 session_id uuid not null,
 transferred_at timestamptz
);
alter table portal_private.trusted_browsers enable row level security;
alter table portal_private.device_policy enable row level security;
alter table portal_private.attempt_devices enable row level security;
revoke all on portal_private.trusted_browsers,portal_private.device_policy,portal_private.attempt_devices from public,anon,authenticated;
grant all on portal_private.trusted_browsers,portal_private.device_policy,portal_private.attempt_devices to service_role;

-- Grandfather only genuinely existing Auth sessions; do not trust stale rows.
insert into portal_private.trusted_browsers(id,user_id,label,user_agent,status,approved_at,last_seen)
select d.id,d.user_id,'Existing browser',d.user_agent,'approved',now(),d.last_seen
from public.device_sessions d join auth.sessions s on s.id=d.session_id and s.user_id=d.user_id
where d.revoked_at is null and (s.not_after is null or s.not_after>now());
update public.device_sessions d set browser_id=b.id from portal_private.trusted_browsers b where d.id=b.id;
insert into portal_private.device_policy(user_id,max_browsers)
select p.id,least(10,greatest(case when p.role in ('admin','instructor') then 5 else 2 end,count(b.id)::int))
from public.profiles p join portal_private.trusted_browsers b on b.user_id=p.id group by p.id,p.role;

create function portal_private.session_approved(p_user uuid,p_session uuid) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.device_sessions d
 join auth.sessions s on s.id=d.session_id and s.user_id=d.user_id
 join portal_private.trusted_browsers b on b.id=d.browser_id and b.user_id=d.user_id
 join public.profiles p on p.id=d.user_id
 where d.user_id=p_user and d.session_id=p_session and d.revoked_at is null
 and b.status='approved' and p.status='active' and (s.not_after is null or s.not_after>now()));
$$;
revoke all on function portal_private.session_approved(uuid,uuid) from public,anon,authenticated;
grant execute on function portal_private.session_approved(uuid,uuid) to service_role;

create function portal_private.current_session_allowed() returns boolean
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare sid uuid;
begin
 if auth.uid() is null then return false; end if;
 begin sid:=nullif(auth.jwt()->>'session_id','')::uuid;
 exception when invalid_text_representation then return false; end;
 return coalesce(portal_private.session_approved(auth.uid(),sid),false);
end $$;
revoke all on function portal_private.current_session_allowed() from public,anon;
grant execute on function portal_private.current_session_allowed() to authenticated,service_role;

create function portal_private.require_current_session() returns boolean
language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 -- Service calls are gated by requireUser and pass explicit verified identities.
 if coalesce(auth.jwt()->>'role','')='service_role' then return true; end if;
 if not portal_private.current_session_allowed() then raise exception 'device_approval_required' using errcode='42501'; end if;
 return true;
end $$;
revoke all on function portal_private.require_current_session() from public,anon;
grant execute on function portal_private.require_current_session() to authenticated,service_role;

-- Existing Edge Functions retain their signature and now fail closed.
create or replace function public.portal_session(p_user uuid,p_session uuid,p_agent text) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not exists(select 1 from auth.sessions where id=p_session and user_id=p_user and (not_after is null or not_after>now())) then raise exception 'invalid_session'; end if;
 if exists(select 1 from public.device_sessions where session_id=p_session and revoked_at is not null) then raise exception 'device_revoked'; end if;
 if not portal_private.session_approved(p_user,p_session) then raise exception 'device_approval_required'; end if;
 update public.device_sessions set last_seen=now() where session_id=p_session;
 update portal_private.trusted_browsers set last_seen=now() where id=(select browser_id from public.device_sessions where session_id=p_session);
end $$;
revoke all on function public.portal_session(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.portal_session(uuid,uuid,text) to service_role;

create function public.portal_device_action(p_user uuid,p_session uuid,p_action text,p_data jsonb,p_agent text) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare me public.profiles; ds public.device_sessions; b portal_private.trusted_browsers;
 target portal_private.trusted_browsers; replacement portal_private.trusted_browsers;
 token_ text; hash_ text; approved_ boolean; fresh_ boolean; max_ int; n_ int; target_user uuid;
begin
 select * into me from public.profiles where id=p_user and status='active';
 if not found then raise exception 'account_suspended'; end if;
 select created_at>now()-interval '5 minutes' into fresh_ from auth.sessions where id=p_session and user_id=p_user and (not_after is null or not_after>now());
 if not found then raise exception 'invalid_session'; end if;
 approved_:=portal_private.session_approved(p_user,p_session);
 select * into ds from public.device_sessions where session_id=p_session;
 if ds.revoked_at is not null then raise exception 'device_revoked'; end if;
 if p_action='register' then
  perform pg_advisory_xact_lock(hashtextextended('devices:'||p_user::text,0));
  token_:=p_data->>'token';
  if token_ is null or token_ !~ '^[a-f0-9]{64}$' then raise exception 'invalid_device_token'; end if;
  hash_:=encode(sha256(convert_to(token_,'UTF8')),'hex');
  select * into b from portal_private.trusted_browsers where user_id=p_user and token_hash=hash_;
  if found and b.status='revoked' then raise exception 'device_revoked'; end if;
  if b.id is null and approved_ then
   -- The old approved session can claim its browser once, at rollout.
   select * into b from portal_private.trusted_browsers where id=ds.browser_id and token_hash is null for update;
   if found then update portal_private.trusted_browsers set token_hash=hash_,label=left(coalesce(nullif(p_data->>'label',''),'Browser'),80) where id=b.id returning * into b; end if;
  end if;
  if b.id is null then
   if (select count(*) from portal_private.trusted_browsers where user_id=p_user and created_at>now()-interval '1 day')>=5 then raise exception 'device_request_limit'; end if;
   select count(*) into n_ from portal_private.trusted_browsers where user_id=p_user;
   insert into portal_private.trusted_browsers(user_id,token_hash,label,user_agent,status,approved_at,approved_by)
   values(p_user,hash_,left(coalesce(nullif(p_data->>'label',''),'Browser'),80),left(coalesce(p_agent,''),500),case when n_=0 then 'approved' else 'pending' end,case when n_=0 then now() end,case when n_=0 then p_user end) returning * into b;
   insert into public.audit_log(actor_id,action,target_type,target_id) values(p_user,'device.requested','browser',b.id::text);
  end if;
  if b.status='approved' then
   -- Binding a session is idempotent. No session can be silently rebound to another browser.
   if ds.browser_id is not null and ds.browser_id<>b.id then
    if not approved_ or not exists(select 1 from portal_private.trusted_browsers where id=ds.browser_id and token_hash is null) then raise exception 'device_session_mismatch'; end if;
    -- Same known browser returning with a legacy session: retire its empty legacy slot.
    update portal_private.trusted_browsers set status='revoked' where id=ds.browser_id;
    update portal_private.attempt_devices set browser_id=b.id where browser_id=ds.browser_id and user_id=p_user;
   end if;
   insert into public.device_sessions(user_id,device_hash,session_id,user_agent,browser_id)
   values(p_user,p_session::text,p_session,left(coalesce(p_agent,''),500),b.id)
   on conflict(session_id) where session_id is not null do update set browser_id=excluded.browser_id,last_seen=now();
   update portal_private.trusted_browsers set last_seen=now() where id=b.id;
  end if;
  return jsonb_build_object('status',b.status,'browser_id',b.id,'label',b.label);
 elsif p_action in ('approve','revoke','limit') then
  if not approved_ then raise exception 'device_approval_required'; end if;
  if not coalesce(fresh_,false) then raise exception 'reauthentication_required'; end if;
  if p_action='limit' then
   if me.role<>'admin' then raise exception 'admin_required'; end if;
   target_user:=(p_data->>'user_id')::uuid;
   insert into portal_private.device_policy(user_id,max_browsers) values(target_user,(p_data->>'max_browsers')::int)
   on conflict(user_id) do update set max_browsers=excluded.max_browsers;
   insert into public.audit_log(actor_id,action,target_type,target_id,meta) values(p_user,'device.limit','user',target_user::text,jsonb_build_object('max_browsers',(p_data->>'max_browsers')::int));
   return jsonb_build_object('ok',true);
  end if;
  select * into target from portal_private.trusted_browsers where id=(p_data->>'id')::uuid;
  if not found or (target.user_id<>p_user and me.role<>'admin') then raise exception 'device_not_found'; end if;
  perform pg_advisory_xact_lock(hashtextextended('devices:'||target.user_id::text,0));
  select * into target from portal_private.trusted_browsers where id=target.id for update;
  if p_action='revoke' then
   update portal_private.trusted_browsers set status='revoked' where id=target.id;
   update public.device_sessions set revoked_at=coalesce(revoked_at,now()) where browser_id=target.id;
  else
   if target.status<>'pending' then raise exception 'device_not_pending'; end if;
   if me.role<>'admin' and target.created_at<now()-interval '7 days' then raise exception 'device_request_expired'; end if;
   if me.role<>'admin' and (select count(*) from public.audit_log where actor_id=p_user and action='device.approved' and at>now()-interval '1 day')>=2 then raise exception 'device_approval_limit'; end if;
   select coalesce((select max_browsers from portal_private.device_policy where user_id=target.user_id),case when role in ('admin','instructor') then 5 else 2 end) into max_ from public.profiles where id=target.user_id;
   if nullif(p_data->>'replace_id','') is not null then
    select * into replacement from portal_private.trusted_browsers where id=(p_data->>'replace_id')::uuid and user_id=target.user_id and status='approved' for update;
    if not found then raise exception 'invalid_replacement'; end if;
    -- Do not interrupt an exam; revoke explicitly or finish/transfer it first.
    if exists(select 1 from portal_private.attempt_devices l join public.attempts a on a.id=l.attempt_id where l.browser_id=replacement.id and a.status='in_progress' and a.deadline_at>now()) then raise exception 'device_has_active_exam'; end if;
    update portal_private.trusted_browsers set status='revoked' where id=replacement.id;
    update public.device_sessions set revoked_at=coalesce(revoked_at,now()) where browser_id=replacement.id;
   end if;
   if (select count(*) from portal_private.trusted_browsers where user_id=target.user_id and status='approved')>=max_ then raise exception 'device_limit_reached'; end if;
   update portal_private.trusted_browsers set status='approved',approved_at=now(),approved_by=p_user where id=target.id;
  end if;
  insert into public.audit_log(actor_id,action,target_type,target_id,meta) values(p_user,case when p_action='approve' then 'device.approved' else 'device.browser_revoked' end,'browser',target.id::text,jsonb_build_object('user_id',target.user_id,'replace_id',replacement.id));
  return jsonb_build_object('ok',true);
 elsif p_action='list' then
  target_user:=p_user;
  if coalesce((p_data->>'admin')::boolean,false) then
   if me.role<>'admin' or not approved_ then raise exception 'admin_required'; end if;
   target_user:=null;
  end if;
  return jsonb_build_object('approved',approved_,'role',me.role,'current_browser',ds.browser_id,
   'devices',coalesce((select jsonb_agg(row_to_json(x) order by x.created_at desc) from (
    select listed_browser.id,listed_browser.user_id,p.full_name,listed_browser.label,listed_browser.user_agent,listed_browser.status,listed_browser.created_at,listed_browser.last_seen,listed_browser.id=ds.browser_id as current,
    coalesce(dp.max_browsers,case when p.role in ('admin','instructor') then 5 else 2 end) max_browsers
    from portal_private.trusted_browsers listed_browser join public.profiles p on p.id=listed_browser.user_id left join portal_private.device_policy dp on dp.user_id=listed_browser.user_id
    where (target_user is null or listed_browser.user_id=target_user) and (listed_browser.status<>'revoked' or listed_browser.last_seen>now()-interval '30 days')
    order by listed_browser.created_at desc limit 500) x),'[]'::jsonb));
 else raise exception 'unknown_action'; end if;
end $$;
revoke all on function public.portal_device_action(uuid,uuid,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.portal_device_action(uuid,uuid,text,jsonb,text) to service_role;

create function portal_private.claim_exam(p_attempt uuid,p_user uuid,p_session uuid,p_transfer boolean default false) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare browser_ uuid; lease_ portal_private.attempt_devices; att_ public.attempts;
begin
 if not portal_private.session_approved(p_user,p_session) then raise exception 'device_approval_required'; end if;
 select * into att_ from public.attempts where id=p_attempt and user_id=p_user for update;
 if not found then raise exception 'attempt_not_found'; end if;
 if att_.status<>'in_progress' then return; end if;
 select browser_id into browser_ from public.device_sessions where session_id=p_session;
 select * into lease_ from portal_private.attempt_devices where attempt_id=p_attempt;
 if found and lease_.browser_id<>browser_ then
  if not p_transfer then raise exception 'exam_on_another_device'; end if;
  if not exists(select 1 from auth.sessions where id=p_session and created_at>now()-interval '5 minutes') then raise exception 'reauthentication_required'; end if;
  if lease_.transferred_at>now()-interval '5 minutes' then raise exception 'exam_transfer_cooldown'; end if;
  insert into public.audit_log(actor_id,action,target_type,target_id) values(p_user,'device.exam_transferred','attempt',p_attempt::text);
 end if;
 insert into portal_private.attempt_devices(attempt_id,user_id,browser_id,session_id,transferred_at)
 values(p_attempt,p_user,browser_,p_session,case when lease_.browser_id is not null and lease_.browser_id<>browser_ then now() else lease_.transferred_at end)
 on conflict(attempt_id) do update set browser_id=excluded.browser_id,session_id=excluded.session_id,transferred_at=excluded.transferred_at;
end $$;
revoke all on function portal_private.claim_exam(uuid,uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function portal_private.claim_exam(uuid,uuid,uuid,boolean) to service_role;

create function public.portal_start_on_device(p_exam uuid,p_user uuid,p_session uuid,p_untimed boolean default false,p_transfer boolean default false) returns public.attempts
language plpgsql security definer set search_path=public,pg_temp as $$
declare att_ public.attempts;
begin
 if not portal_private.session_approved(p_user,p_session) then raise exception 'device_approval_required'; end if;
 att_:=public.portal_start_attempt(p_exam,p_user,p_untimed);
 perform portal_private.claim_exam(att_.id,p_user,p_session,p_transfer);
 return att_;
end $$;
create function public.portal_submit_on_device(p_attempt uuid,p_user uuid,p_session uuid,p_key text default null) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not portal_private.session_approved(p_user,p_session) then raise exception 'device_approval_required'; end if;
 perform portal_private.claim_exam(p_attempt,p_user,p_session,false);
 return public.portal_submit(p_attempt,p_user,p_key);
end $$;
revoke all on function public.portal_start_on_device(uuid,uuid,uuid,boolean,boolean),public.portal_submit_on_device(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.portal_start_on_device(uuid,uuid,uuid,boolean,boolean),public.portal_submit_on_device(uuid,uuid,uuid,text) to service_role;

create or replace function public.attempt_live_for(p_attempt uuid,p_user uuid) returns boolean
language sql volatile security definer set search_path=public,pg_temp as $$
 select p_user=auth.uid() and portal_private.current_session_allowed()
 and exists(select 1 from public.attempts a where a.id=p_attempt and a.user_id=p_user and a.status='in_progress'
 and clock_timestamp()<a.deadline_at and portal_private.attempt_course_access(p_attempt,p_user,false))
 and exists(select 1 from portal_private.attempt_devices l where l.attempt_id=p_attempt and l.user_id=p_user
 and l.session_id=nullif(auth.jwt()->>'session_id','')::uuid);
$$;

-- A write on an already-open pre-rollout exam claims its session atomically.
-- The row lock makes concurrent first writes select one owner, never two.
create function portal_private.guard_answer_device() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if current_setting('role',true)='authenticated' then
  perform portal_private.claim_exam(new.attempt_id,auth.uid(),nullif(auth.jwt()->>'session_id','')::uuid,false);
 end if;
 return new;
end $$;
revoke all on function portal_private.guard_answer_device() from public,anon,authenticated;
create trigger guard_answer_device before insert or update on public.attempt_answers for each row execute function portal_private.guard_answer_device();

-- Restrictive policies add session approval without weakening existing ownership,
-- enrollment, staff scope, or subscription rules. Service-role work is unaffected.
do $$ declare t record; begin
 for t in select c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and c.relrowsecurity loop
  execute format('create policy approved_session_required on public.%I as restrictive for all to authenticated using ((select portal_private.current_session_allowed())) with check ((select portal_private.current_session_allowed()))',t.relname);
 end loop;
end $$;
