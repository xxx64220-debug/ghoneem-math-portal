begin;
create function portal_private.validate_daily_group() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.daily_group_id is not null and not exists(select 1 from public.groups g join public.group_members m on m.group_id=g.id
 where g.id=new.daily_group_id and g.track_id=new.track_id and m.user_id=new.user_id and g.id is distinct from public.default_group(g.track_id)) then raise exception 'daily_group_membership_or_track_mismatch';end if;
 return new;
end $$;
revoke all on function portal_private.validate_daily_group() from public,anon,authenticated;
create trigger enrollment_daily_group_guard before insert or update of daily_group_id,user_id,track_id on public.enrollments for each row execute function portal_private.validate_daily_group();
create function portal_private.clear_removed_daily_group() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin update public.enrollments set daily_group_id=null where user_id=old.user_id and daily_group_id=old.group_id;return old;end $$;
revoke all on function portal_private.clear_removed_daily_group() from public,anon,authenticated;
create trigger membership_daily_group_removed after delete on public.group_members for each row execute function portal_private.clear_removed_daily_group();
commit;
