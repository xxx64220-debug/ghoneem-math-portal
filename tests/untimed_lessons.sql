begin;
do $$
declare u uuid; e uuid; other uuid; a attempts; b attempts; payload jsonb; allowed boolean;
begin
 select p.id,x.id into u,e from profiles p cross join exams x
 where p.role='student' and p.status='active' and x.assessment_type='lesson_exam' and x.is_published
 and is_enrolled(p.id,x.track_id) and student_assignment_for(x.id,p.id) is not null
 and not exists(select 1 from attempts t where t.user_id=p.id and t.exam_id=x.id and t.status='in_progress') limit 1;
 if u is null then raise exception 'No safe assigned lesson fixture'; end if;
 a:=portal_start_attempt(e,u,true);
 if a.deadline_at<>'infinity'::timestamptz then raise exception 'Untimed deadline is finite'; end if;
 b:=portal_start_attempt(e,u,false);
 if a.id<>b.id or b.deadline_at<>'infinity'::timestamptz then raise exception 'Resume changed mode'; end if;
 perform finalize_expired_for(u,e);
 if (select status from attempts where id=a.id)<>'in_progress' then raise exception 'Untimed expired'; end if;
 payload:=attempt_payload(a.id,u);
 if payload->'attempt'->>'deadline_at'<>'infinity' then raise exception 'Payload lost timer mode'; end if;
 perform submit_attempt(a.id,u);
 if (select time_used from attempts where id=a.id) is null then raise exception 'Submission did not record time'; end if;
 b:=portal_start_attempt(e,u,false);
 if b.id=a.id or b.attempt_no<>a.attempt_no+1 or not isfinite(b.deadline_at) then raise exception 'Timed repeat failed'; end if;
 if not exists(select 1 from attempts where id=a.id and status<>'in_progress') then raise exception 'History lost'; end if;
 a:=portal_start_attempt(e,u,true);
 if a.id<>b.id or not isfinite(a.deadline_at) then raise exception 'Timed resume bypassed expiry'; end if;
 select id into other from exams where assessment_type='full_exam' and is_published limit 1;
 begin
  perform portal_start_attempt(other,u,true);
  raise exception 'Full exam accepted untimed';
 exception when others then
  if SQLERRM<>'untimed_lessons_only' then raise; end if;
 end;
 if has_function_privilege('authenticated','public.portal_start_attempt(uuid,uuid,boolean)','EXECUTE') or has_function_privilege('anon','public.portal_start_attempt(uuid,uuid,boolean)','EXECUTE') then raise exception 'Direct identity spoofing possible'; end if;
end $$;
select 'PASS: untimed start, resume, no expiry, submission, timed repeat, preserved history, locked mode, full-exam timer and RPC permissions' as result;
rollback;
