-- Structural readiness for catalog reads. Attempts still validate live content.
-- Install once in a transaction: trigger DDL locks protect the initial backfill.
create table portal_private.question_eligibility_cache (
 question_id uuid primary key references public.questions(id) on delete cascade on update cascade,
 track_id text not null,
 exam_eligible boolean not null,
 rule_version text not null
);
alter table portal_private.question_eligibility_cache enable row level security;
revoke all on portal_private.question_eligibility_cache from public,anon,authenticated;

create function portal_private.refresh_question_eligibility(p_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 -- Both question and key writers serialize on the question row. A key update
 -- waiting for a question update recomputes from the committed question version.
 perform 1 from public.questions where id=p_id for no key update;
 if not found then return; end if;
 insert into portal_private.question_eligibility_cache(question_id,track_id,exam_eligible,rule_version)
 select q.id,q.track_id,portal_private.question_eligible(q,k,q.track_id,false),
  md5(pg_get_functiondef('portal_private.question_eligible(public.questions,public.question_keys,text,boolean)'::regprocedure))
 from public.questions q left join public.question_keys k on k.question_id=q.id
 where q.id=p_id
 on conflict(question_id) do update set
  track_id=excluded.track_id,exam_eligible=excluded.exam_eligible,rule_version=excluded.rule_version;
end $$;
revoke all on function portal_private.refresh_question_eligibility(uuid) from public,anon,authenticated;

create function portal_private.refresh_question_eligibility_trigger()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if TG_OP='TRUNCATE' then
  update portal_private.question_eligibility_cache set exam_eligible=false;
  return null;
 end if;
 if TG_TABLE_NAME='questions' then
  perform portal_private.refresh_question_eligibility(NEW.id);
 else
  if TG_OP='DELETE' then
   perform portal_private.refresh_question_eligibility(OLD.question_id);
  else
   if TG_OP='UPDATE' and OLD.question_id is distinct from NEW.question_id then
    perform portal_private.refresh_question_eligibility(OLD.question_id);
   end if;
   perform portal_private.refresh_question_eligibility(NEW.question_id);
  end if;
 end if;
 return null;
end $$;
revoke all on function portal_private.refresh_question_eligibility_trigger() from public,anon,authenticated;

create trigger refresh_catalog_question_eligibility
 after insert or update of id,track_id,type,stem,choices,assets on public.questions
 for each row execute function portal_private.refresh_question_eligibility_trigger();
create trigger refresh_catalog_key_eligibility
 after insert or update of question_id,correct,explanation or delete on public.question_keys
 for each row execute function portal_private.refresh_question_eligibility_trigger();
create trigger refresh_catalog_truncated_key_eligibility
 after truncate on public.question_keys
 for each statement execute function portal_private.refresh_question_eligibility_trigger();

insert into portal_private.question_eligibility_cache(question_id,track_id,exam_eligible,rule_version)
 with rule as materialized (select md5(pg_get_functiondef('portal_private.question_eligible(public.questions,public.question_keys,text,boolean)'::regprocedure)) version)
 select q.id,q.track_id,portal_private.question_eligible(q,k,q.track_id,false),rule.version
 from public.questions q left join public.question_keys k on k.question_id=q.id cross join rule;
