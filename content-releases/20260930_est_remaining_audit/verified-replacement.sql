begin;
set local lock_timeout='5s';
lock table questions,question_keys,revision_items in share row exclusive mode;
do $$ begin
if not exists(select 1 from questions q join question_keys k on k.question_id=q.id where q.id='97a4e8db-e914-5a56-a4c6-f3b6efe36600' and q.track_id='est' and q.difficulty='medium' and md5(to_jsonb(q)::text)='dbb755b3f1713233d1a52021cd9d8a12' and md5(to_jsonb(k)::text)='d87ff3799377fa5e85da7bde2aa42efb' and nullif(q.assets->>'release_hold_reason','') is null and coalesce((q.assets->>'bank_removed')::boolean,false)=false and q.assets->>'answer_review'='2026-09-28-independent-solution-and-source-check') then raise exception 'Verified replacement version changed';end if;
if exists(select 1 from revision_items where question_id='97a4e8db-e914-5a56-a4c6-f3b6efe36600') then raise exception 'Replacement already has revision metadata';end if;
if exists(select 1 from revision_items r join questions q on q.id=r.question_id where r.active and q.track_id='est' and r.lesson='Systems of equations' and lower(trim(r.idea))='no-solution conditions' and r.difficulty='medium') then raise exception 'Existing EST representative must be retained';end if;
if not exists(select 1 from questions q join revision_items r on r.question_id=q.id where q.id='fa4af000-7c2b-5a7c-a0f2-222016a9d1e9' and not r.active and nullif(q.assets->>'release_hold_reason','') is not null) then raise exception 'Defective source exclusion missing';end if;
end $$;
insert into revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
select q.id,'Systems of equations','No-solution conditions','medium',array['est'],revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation),true,
jsonb_build_object('takeaway','Equal coefficient ratios with unequal constants give parallel distinct lines.','collections',jsonb_build_array('must_know'),'math_format','plain','source_label',q.assets->>'source_document','source_reference','HOA 179','bank_occurrences',1)
from questions q join question_keys k on k.question_id=q.id where q.id='97a4e8db-e914-5a56-a4c6-f3b6efe36600';
insert into audit_log(action,target_type,target_id,meta) values('revision.est_verified_defect_replacement.20260930','question','97a4e8db-e914-5a56-a4c6-f3b6efe36600',jsonb_build_object('replaces','fa4af000-7c2b-5a7c-a0f2-222016a9d1e9','proof','Multiply 2x+5y=1/5 by5/2:5x+(25/2)y=1/2. At a=25/2 the other equation has the same left side but constant2/25, so no solution. Other listed coefficients have nonzero determinant.','track','est','lesson','Systems of equations','idea','No-solution conditions','difficulty','medium','collections',jsonb_build_array('must_know')));
do $$ begin
if (select count(*) from revision_items r join questions q on q.id=r.question_id where r.active and q.track_id='est' and r.lesson='Systems of equations' and r.idea='No-solution conditions' and r.difficulty='medium')<>1 then raise exception 'EST representative cap violated';end if;
end $$;
commit;
