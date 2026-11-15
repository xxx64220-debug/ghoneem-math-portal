-- Optional exam tools, isolated from answers, grading and submission.
create table public.attempt_annotations (
 attempt_id uuid not null references public.attempts(id) on delete cascade,
 question_id uuid not null references public.questions(id) on delete cascade,
 eliminated text[] not null default '{}' check (cardinality(eliminated)<=10),
 seconds integer not null default 0 check (seconds between 0 and 86400),
 flagged boolean not null default false,
 primary key(attempt_id,question_id)
);
create index attempt_annotations_question_idx on public.attempt_annotations(question_id);
alter table public.attempt_annotations enable row level security;
revoke all on public.attempt_annotations from public,anon,authenticated;
grant select,insert,update on public.attempt_annotations to authenticated;
grant all on public.attempt_annotations to service_role;

create function portal_private.annotation_allowed(p_attempt uuid,p_question uuid,p_eliminated text[])
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(
  select 1 from public.attempts a join public.exams e on e.id=a.exam_id
  join public.questions q on q.id=p_question and q.track_id=e.track_id
  where a.id=p_attempt and a.user_id=auth.uid() and p_question=any(e.question_ids)
  and not exists(select 1 from unnest(p_eliminated) x where x is null or not exists(
   select 1 from jsonb_array_elements(coalesce(q.choices,'[]'::jsonb)) c where c->>'key'=x))
 );
$$;
revoke all on function portal_private.annotation_allowed(uuid,uuid,text[]) from public,anon;
grant execute on function portal_private.annotation_allowed(uuid,uuid,text[]) to authenticated,service_role;
create policy annotation_read on public.attempt_annotations for select to authenticated
 using ((select portal_private.current_session_allowed()) and portal_private.attempt_is_mine(attempt_id,(select auth.uid())));
create policy annotation_insert on public.attempt_annotations for insert to authenticated
 with check (portal_private.attempt_live_for(attempt_id,(select auth.uid())) and portal_private.annotation_allowed(attempt_id,question_id,eliminated));
create policy annotation_update on public.attempt_annotations for update to authenticated
 using (portal_private.attempt_live_for(attempt_id,(select auth.uid())))
 with check (portal_private.attempt_live_for(attempt_id,(select auth.uid())) and portal_private.annotation_allowed(attempt_id,question_id,eliminated));

create function portal_private.annotation_monotonic() returns trigger language plpgsql set search_path='' as $$
begin
 if new.attempt_id<>old.attempt_id or new.question_id<>old.question_id then raise exception 'annotation_identity_immutable'; end if;
 new.seconds:=greatest(new.seconds,old.seconds);
 return new;
end $$;
revoke all on function portal_private.annotation_monotonic() from public,anon,authenticated;
create trigger annotation_monotonic before update on public.attempt_annotations for each row execute function portal_private.annotation_monotonic();
