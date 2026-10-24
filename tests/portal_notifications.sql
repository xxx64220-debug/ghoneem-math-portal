begin;
do $$
declare u uuid:=gen_random_uuid(); s uuid; j uuid; n int;
begin
 insert into auth.users(id,email) values(u,u::text||'@notifications.test');
 insert into public.profiles(id,role,status) values(u,'student','active');
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
 -- Simulate worker death after claim, before recording a provider response.
 update public.portal_push_queue set attempts=3,next_attempt=now()-interval '1 second' where id=j;
 perform public.portal_push_claim();
 if not exists(select 1 from public.portal_push_queue where id=j and status='failed' and attempts=3 and error='retry_limit_reached') then raise exception 'crashed third attempt was reclaimed';end if;
 update public.portal_push_queue set status='sending',attempts=2,next_attempt=now()-interval '1 second' where id=j;
 perform public.portal_push_claim();
 if not exists(select 1 from public.portal_push_queue where id=j and status='sending' and attempts=3) then raise exception 'recoverable lease was not reclaimed';end if;
 perform public.portal_push_claim();
 if not exists(select 1 from public.portal_push_queue where id=j and status='sending' and attempts=3) then raise exception 'live final lease was changed';end if;
 update public.portal_push_queue set next_attempt=now()-interval '1 second' where id=j;
 perform public.portal_push_claim();
 if not exists(select 1 from public.portal_push_queue where id=j and status='failed' and attempts=3) then raise exception 'fourth delivery attempt allowed';end if;
 update public.portal_push_queue set status='pending',attempts=0,created_at=now()-interval '25 hours' where id=j;
 perform public.portal_push_claim();
 if not exists(select 1 from public.portal_push_queue where id=j and status='failed' and attempts=0 and error='delivery_expired') then raise exception 'expired notification claimed';end if;
 update public.portal_push_queue set status='pending',attempts=1,created_at=now(),next_attempt=now()+interval '5 minutes' where id=j;
 perform public.portal_push_claim();
 if not exists(select 1 from public.portal_push_queue where id=j and status='pending' and attempts=1) then raise exception 'retry backoff ignored';end if;
 update public.portal_push_queue set attempts=0,created_at=now()-interval '24 hours',next_attempt=now() where id=j;
 perform public.portal_push_claim();
 if not exists(select 1 from public.portal_push_queue where id=j and status='sending' and attempts=1 and next_attempt=now()+interval '5 minutes') then raise exception '24-hour boundary or lease duration changed';end if;
 update public.portal_push_queue set created_at=now()-interval '24 hours 1 second' where id=j;
 perform public.portal_push_claim();
 if not exists(select 1 from public.portal_push_queue where id=j and status='sending' and attempts=1) then raise exception 'live expired lease changed by claim';end if;
 update public.portal_push_queue set next_attempt=now() where id=j;
 perform public.portal_push_claim();
 if not exists(select 1 from public.portal_push_queue where id=j and status='failed' and attempts=1 and error='delivery_expired') then raise exception 'expired lease reclaimed';end if;
 insert into public.portal_push_queue(subscription_id,event_key,kind,title,body)
 select s,'batch:'||i,'test','test','test' from generate_series(1,12) i;
 select count(*) into n from public.portal_push_claim();
 if n<>10 then raise exception 'claim batch did not stop at ten';end if;
 select count(*) into n from public.portal_push_claim();
 if n<>2 then raise exception 'claim duplicated an active lease';end if;
 delete from public.portal_push_subscriptions where id=s;
 if exists(select 1 from public.portal_push_queue where id=j) then raise exception 'opt-out left a queued notification';end if;
 if has_table_privilege('authenticated','public.portal_push_config','select') or has_table_privilege('anon','public.portal_push_subscriptions','select') or has_function_privilege('authenticated','public.portal_push_collect()','execute') then raise exception 'unexpected public notification access';end if;
end $$;
rollback;
