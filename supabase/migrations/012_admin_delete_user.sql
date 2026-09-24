-- Only the verified admin Edge Function may call this atomic account deletion.
create or replace function public.portal_delete_user(p_actor uuid,p_target uuid,p_confirmation text)
returns jsonb language plpgsql security definer set search_path = public,pg_temp as $$
declare target_role text; target_email text;
begin
 perform 1 from public.profiles where id=p_actor and role='admin' and status='active' for update;
 if not found then raise exception 'admin_required'; end if;
 if p_target=p_actor then raise exception 'protected_account'; end if;
 select role into target_role from public.profiles where id=p_target for update;
 if not found then raise exception 'user_not_found'; end if;
 if target_role='admin' then raise exception 'protected_account'; end if;
 select email into target_email from auth.users where id=p_target for update;
 if target_email is null then raise exception 'user_not_found'; end if;
 if p_confirmation is null or p_confirmation<>target_email then raise exception 'confirmation_mismatch'; end if;
 -- Auth identities/sessions, profile, attempts and student progress cascade together.
 -- Any dependency error rolls back the entire operation, including this audit entry.
 insert into public.audit_log(actor_id,action,target_type,target_id,meta)
 values(p_actor,'user.delete','user',p_target::text,jsonb_build_object('role',target_role));
 delete from auth.users where id=p_target;
 return jsonb_build_object('deleted',true,'user_id',p_target);
end $$;
revoke all on function public.portal_delete_user(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.portal_delete_user(uuid,uuid,text) to service_role;
