-- Fix only the device-list query; preserve approvals, browser tokens and exam ownership.
-- Refuse to overwrite an unexpected function revision.
do $$ begin
 if md5(pg_get_functiondef('public.portal_device_action(uuid,uuid,text,jsonb,text)'::regprocedure)) <> 'cabe6a74b6833c500e85c28be34827d0' then
  raise exception 'device_list_fix_precondition_failed';
 end if;
end $$;

create or replace function public.portal_device_action(p_user uuid,p_session uuid,p_action text,p_data jsonb,p_agent text) returns jsonb
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

