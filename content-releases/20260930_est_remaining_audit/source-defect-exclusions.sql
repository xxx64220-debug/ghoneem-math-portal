begin;
set local lock_timeout='5s';
lock table questions,question_keys,revision_items,exams in share row exclusive mode;
create temporary table est_exclusions on commit drop as select * from jsonb_to_recordset('[{"id":"be507dd8-d608-59a3-970e-10e05284131b","q_digest":"ce62f959c7702d164e684c90e453a6c4","key_digest":"08e9bada0a4619560e0d9547839d3556","reason":"Original March question 4 prints ambiguous Honda revenue 117,00. Literal tax 51803.4 is not offered; assuming an extra zero changes the source. Existing void key retained."},{"id":"c5b39981-f58c-5d56-b5b2-79f1702ad1da","q_digest":"76cd6d810cbd2f1f10cb52e758153fdb","key_digest":"fcb653d9b829a153fc028b06813c1a84","reason":"Original March question 27 equates 1.2 cubic meters of water to 9 gallons. These units describe incompatible amounts; proportional arithmetic 195 does not certify the physical statement. No guessed unit repair."},{"id":"d734bf83-7cbd-5bd2-b857-db3656c5018d","q_digest":"2e04a3b5edba01f0990773466eeb072d","key_digest":"c6bce2f0d5a2025055da492ece2e1f72","reason":"Original March question 35 gives points (-3,44),(1,-2), whose slope is -11.5; no offered answer matches. Existing void key retained."},{"id":"fa4af000-7c2b-5a7c-a0f2-222016a9d1e9","q_digest":"7ca88c12922131fb4e1ba773d92841f9","key_digest":"d7ad594126220c0c4ed5ae49d8ba5c7a","reason":"Original HOA 056 asks when the system admits solutions. A, B and D each yield a unique solution; keyed C=-2/3 yields no solution. Wording and key conflict; not rewritten by guessing."}]'::jsonb) as t(id uuid,q_digest text,key_digest text,reason text);
do $$ begin
if exists(select 1 from audit_log where action='questions.est_remaining_exclusions.20260930') then raise exception 'Exclusions already applied';end if;
if (select count(*) from est_exclusions t join questions q on q.id=t.id join question_keys k on k.question_id=q.id where md5(to_jsonb(q)::text)=t.q_digest and md5(to_jsonb(k)::text)=t.key_digest)<>4 then raise exception 'Exclusion version changed';end if;
end $$;
insert into audit_log(action,target_type,target_id,meta)
select 'questions.est_remaining_exclusions.20260930','question',q.id::text,jsonb_build_object('previous_assets',q.assets,'previous_key',k.correct,'reason',t.reason)
from est_exclusions t join questions q on q.id=t.id join question_keys k on k.question_id=q.id;
update questions q set assets=q.assets||jsonb_build_object('release_hold_reason',t.reason,'answer_review','2026-09-30-independent-defect-exclusion') from est_exclusions t where q.id=t.id;
insert into audit_log(action,target_type,target_id,meta)
select 'revision.est_remaining_exclusions.20260930','question',r.question_id::text,jsonb_build_object('previous_active',r.active,'lesson',r.lesson,'idea',r.idea,'difficulty',r.difficulty,'programmes',r.programmes,'focus',r.focus,'reason',t.reason)
from revision_items r join est_exclusions t on t.id=r.question_id where r.active;
update revision_items r set active=false from est_exclusions t where r.question_id=t.id;
insert into audit_log(action,target_type,target_id,meta)
select 'exams.est_remaining_exclusions.20260930','exam',e.id::text,jsonb_build_object('previous_is_published',e.is_published,'reason','Contains a documented excluded question; original memberships and history retained')
from exams e where e.is_published and exists(select 1 from est_exclusions t where t.id=any(e.question_ids));
update exams e set is_published=false where e.is_published and exists(select 1 from est_exclusions t where t.id=any(e.question_ids));
do $$ begin
if exists(select 1 from revision_items r join est_exclusions t on t.id=r.question_id where r.active) then raise exception 'Excluded revision still active';end if;
end $$;
commit;
