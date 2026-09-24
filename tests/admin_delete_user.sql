-- Run inside a transaction with 012_admin_delete_user.sql, then ROLLBACK.
do $$
declare a uuid:=gen_random_uuid(); s uuid:=gen_random_uuid(); i uuid:=gen_random_uuid(); other_admin uuid:=gen_random_uuid(); suspended uuid:=gen_random_uuid(); eid uuid; tid text;
begin
 insert into auth.users(id,email) values(a,'delete-admin-test@example.invalid'),(s,'delete-student-test@example.invalid'),(i,'delete-instructor-test@example.invalid'),(other_admin,'delete-other-admin@example.invalid'),(suspended,'delete-suspended@example.invalid');
 insert into public.profiles(id,role,status) values(a,'admin','active'),(s,'student','active'),(i,'instructor','active'),(other_admin,'admin','active'),(suspended,'admin','suspended') on conflict(id) do update set role=excluded.role,status=excluded.status;
 begin perform public.portal_delete_user(s,i,'delete-instructor-test@example.invalid'); raise exception 'test_student_allowed'; exception when others then if sqlerrm<>'admin_required' then raise; end if; end;
 begin perform public.portal_delete_user(i,s,'delete-student-test@example.invalid'); raise exception 'test_instructor_allowed'; exception when others then if sqlerrm<>'admin_required' then raise; end if; end;
 begin perform public.portal_delete_user(suspended,s,'delete-student-test@example.invalid'); raise exception 'test_suspended_allowed'; exception when others then if sqlerrm<>'admin_required' then raise; end if; end;
 begin perform public.portal_delete_user(a,a,'delete-admin-test@example.invalid'); raise exception 'test_self_allowed'; exception when others then if sqlerrm<>'protected_account' then raise; end if; end;
 begin perform public.portal_delete_user(a,other_admin,'delete-other-admin@example.invalid'); raise exception 'test_admin_allowed'; exception when others then if sqlerrm<>'protected_account' then raise; end if; end;
 begin perform public.portal_delete_user(a,s,'wrong@example.invalid'); raise exception 'test_confirmation_allowed'; exception when others then if sqlerrm<>'confirmation_mismatch' then raise; end if; end;
 select id into tid from public.tracks limit 1;
 insert into public.enrollments(user_id,track_id) values(s,tid);
 insert into public.daily_progress(user_id,track_id,day) values(s,tid,current_date);
 select id into eid from public.exams limit 1;
 if eid is not null then insert into public.attempts(user_id,exam_id,attempt_no,shuffle_seed,deadline_at) values(s,eid,1,123,now()+interval '75 minutes'); end if;
 perform public.portal_delete_user(a,s,'delete-student-test@example.invalid');
 if exists(select 1 from auth.users where id=s) or exists(select 1 from public.profiles where id=s) or exists(select 1 from public.attempts where user_id=s) or exists(select 1 from public.daily_progress where user_id=s) or exists(select 1 from public.enrollments where user_id=s) then raise exception 'test_cascade_failed'; end if;
 if not exists(select 1 from public.audit_log where actor_id=a and action='user.delete' and target_id=s::text) then raise exception 'test_missing_audit'; end if;
 perform public.portal_delete_user(a,i,'delete-instructor-test@example.invalid');
 begin perform public.portal_delete_user(a,s,'delete-student-test@example.invalid'); raise exception 'test_missing_allowed'; exception when others then if sqlerrm<>'user_not_found' then raise; end if; end;
 if has_function_privilege('authenticated','public.portal_delete_user(uuid,uuid,text)','execute') or has_function_privilege('anon','public.portal_delete_user(uuid,uuid,text)','execute') then raise exception 'test_public_access'; end if;
end $$;
select 'PASS: role protection, confirmation, cascades, audit, repeat deletion and RPC privileges' as result;
