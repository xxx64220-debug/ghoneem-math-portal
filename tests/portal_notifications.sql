begin;
do $$
declare u uuid; s uuid; j uuid; n int;
begin
 select id into u from public.profiles where role='student' and status='active' limit 1;
 if u is null then raise exception 'test needs an existing active student';end if;
 insert into public.portal_push_subscriptions(user_id,endpoint,p256dh,auth,origin)
 values(u,'https://fcm.googleapis.com/fcm/send/rollback-only','test','test','https://math.portal.ghoneem.com') returning id into s;
 perform public.portal_push_collect();
 select count(*) into n from public.portal_push_queue where subscription_id=s;
 if n<>0 then raise exception 'historical notification backlog';end if;
 begin
  perform public.portal_push_announce(u,gen_random_uuid(),'test','test',null);
  raise exception 'student allowed to announce';
 exception when others then if sqlerrm<>'forbidden' then raise;end if;
 end;
 insert into public.portal_push_queue(subscription_id,event_key,kind,title,body) values(s,'test:1','test','test','test') returning id into j;
 insert into public.portal_push_queue(subscription_id,event_key,kind,title,body) values(s,'test:1','test','test','test') on conflict do nothing;
 if (select count(*) from public.portal_push_queue where subscription_id=s)<>1 then raise exception 'duplicate queued';end if;
 perform public.portal_push_claim();
 if not exists(select 1 from public.portal_push_queue where id=j and status='sending' and attempts=1) then raise exception 'job was not claimed';end if;
 perform public.portal_push_claim();
 if exists(select 1 from public.portal_push_queue where id=j and attempts<>1) then raise exception 'claimed twice';end if;
 delete from public.portal_push_subscriptions where id=s;
 if exists(select 1 from public.portal_push_queue where id=j) then raise exception 'opt-out left a queued notification';end if;
 if has_table_privilege('authenticated','public.portal_push_config','select') or has_table_privilege('anon','public.portal_push_subscriptions','select') or has_function_privilege('authenticated','public.portal_push_collect()','execute') then raise exception 'unexpected public notification access';end if;
end $$;
rollback;
