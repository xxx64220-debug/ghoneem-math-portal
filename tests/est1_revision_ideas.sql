do $$
begin
 if (select count(*) from public.revision_items)<>2267 then raise exception 'revision total'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590 then raise exception 'EST I total'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>416 then raise exception 'EST II changed'; end if;
 if (select count(*) from public.audit_log where action='revision.est1_idea_expansion.item.20260929')<>60 then raise exception 'item audit'; end if;
 if (select count(*) from public.audit_log where action='revision.est1_idea_expansion.20260929')<>1 then raise exception 'release audit'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est' and r.programmes=array['est']::text[] and r.focus#>'{collections}'='["unique"]'::jsonb)<>60 then raise exception 'EST I release scope'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where q.track_id='est' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>578 then raise exception 'ready total'; end if;
 if (select count(*) from public.questions)<>2267 or (select count(*) from public.question_keys)<>2267 then raise exception 'question content changed'; end if;
end $$;
select 'PASS: 60 EST I ideas added; EST II and question content preserved' as result;
