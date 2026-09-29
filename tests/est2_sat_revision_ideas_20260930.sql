do $$
begin
 if (select count(*) from public.revision_items)<>2427 then raise exception 'revision total'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1341 then raise exception 'SAT total'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590 then raise exception 'EST I changed'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>496 then raise exception 'EST II total'; end if;
 if (select count(*) from public.audit_log where action='revision.est2_sat_idea_expansion.item.20260930')<>80 then raise exception 'item audit'; end if;
 if (select count(*) from public.audit_log where action='revision.est2_sat_idea_expansion.20260930')<>1 then raise exception 'release audit'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id
     where r.focus->>'release'='20260930-est2-sat-idea-expansion' and q.track_id='sat'
       and r.programmes=array['sat']::text[] and r.focus#>'{collections}'='["unique"]'::jsonb)<>40 then raise exception 'SAT release scope'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id
     where r.focus->>'release'='20260930-est2-sat-idea-expansion' and q.track_id='est2'
       and r.programmes=array['est2']::text[] and r.focus#>'{collections}'='["unique"]'::jsonb)<>40 then raise exception 'EST II release scope'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
     where q.track_id='sat' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>1341 then raise exception 'SAT ready total'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
     where q.track_id='est2' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>495 then raise exception 'EST II ready total'; end if;
end $$;
select 'PASS: second 40 SAT and 40 EST II ideas added; EST I and question content preserved' as result;


