begin;
set local lock_timeout='5s';
lock table questions,question_keys,revision_items,exams in share row exclusive mode;
do $$ begin
if not exists(select 1 from questions q join question_keys k on k.question_id=q.id where q.id='25341cd9-57d3-529c-bd83-36eae2d1f3a7' and md5(to_jsonb(q)::text)='cf2628381ff014fffaf522b398e33e4f' and md5(to_jsonb(k)::text)='5224a3638c020de49ada6f5bfe69e2b1') then raise exception 'Ambiguous question version changed'; end if;
end $$;
insert into audit_log(action,target_type,target_id,meta)
select 'questions.est_march_ambiguous_hold.20260930','question',q.id::text,jsonb_build_object('previous_assets',q.assets,'previous_key',k.correct,'reason','Original single-answer question has two distinct valid answers B and D. B has an open interval of solutions; D is true for every real x. No guessed replacement.')
from questions q join question_keys k on k.question_id=q.id where q.id='25341cd9-57d3-529c-bd83-36eae2d1f3a7';
update questions set assets=assets||jsonb_build_object('release_hold_reason','Original single-answer question has two distinct valid answers B and D; excluded pending a verified unambiguous replacement.','answer_review','2026-09-30-independent-ambiguity-exclusion') where id='25341cd9-57d3-529c-bd83-36eae2d1f3a7';
insert into audit_log(action,target_type,target_id,meta) select 'revision.est_march_ambiguous_hold.20260930','question',question_id::text,jsonb_build_object('previous_active',active,'reason','Ambiguous source question excluded') from revision_items where question_id='25341cd9-57d3-529c-bd83-36eae2d1f3a7' and active;
update revision_items set active=false where question_id='25341cd9-57d3-529c-bd83-36eae2d1f3a7';
insert into audit_log(action,target_type,target_id,meta) select 'exams.est_march_ambiguous_hold.20260930','exam',id::text,jsonb_build_object('previous_is_published',is_published,'reason','Contains ambiguous original March question 23; memberships retained') from exams where is_published and '25341cd9-57d3-529c-bd83-36eae2d1f3a7'::uuid=any(question_ids);
update exams set is_published=false where is_published and '25341cd9-57d3-529c-bd83-36eae2d1f3a7'::uuid=any(question_ids);
commit;
