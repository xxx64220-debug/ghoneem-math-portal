"""Prepare an insert-only draft import; activation is a separate explicit step."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'content/est-banks-2026'
bank=json.loads((OUT/'reviewed-bank.json').read_text())
assert all(not e['is_published'] for e in bank['exams'])
literal=json.dumps(bank,ensure_ascii=False,separators=(',',':')).replace("'","''")
sql="""-- Reviewed EST bank: insert new immutable questions and UNPUBLISHED exams.
-- Does not edit any existing questions, keys, exams, assignments, or attempts.
with payload as (select '%s'::jsonb as data),
qsrc as (
 select r.* from payload p cross join lateral jsonb_to_recordset(p.data->'questions')
 as r(id uuid,track_id text,topic text,difficulty text,type text,stem text,choices jsonb,assets jsonb,correct jsonb,explanation text)
), inserted_questions as (
 insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
 select id,track_id,topic,difficulty,type,stem,choices,assets from qsrc
 on conflict(id) do nothing returning id
), inserted_keys as (
 insert into public.question_keys(question_id,correct,explanation)
 select s.id,s.correct,s.explanation from qsrc s join inserted_questions q on q.id=s.id
 on conflict(question_id) do nothing returning question_id
), inserted_exams as (
 insert into public.exams(id,track_id,title,duration_seconds,question_ids,shuffle,review_policy,max_attempts,is_published,is_full_length,assessment_type,scoring_map)
 select r.id,r.track_id,r.title,r.duration_seconds,r.question_ids,r.shuffle,r.review_policy,r.max_attempts,false,r.is_full_length,r.assessment_type,null
 from payload p cross join lateral jsonb_to_recordset(p.data->'exams')
 as r(id uuid,track_id text,title text,duration_seconds int,question_ids uuid[],shuffle boolean,review_policy text,max_attempts int,is_full_length boolean,assessment_type text)
 on conflict(id) do nothing returning id
), inserted_assignments as (
 insert into public.assignments(exam_id,group_id)
 select id,public.default_group('est') from inserted_exams returning id
)
select (select count(*) from inserted_questions) as questions_inserted,
 (select count(*) from inserted_keys) as keys_inserted,
 (select count(*) from inserted_exams) as unpublished_exams_inserted,
 (select count(*) from inserted_assignments) as assignments_inserted;
""" % literal
(OUT/'import-draft.sql').write_text(sql)
ids=','.join("'"+e['id']+"'::uuid" for e in bank['exams'])
(OUT/'activate-after-publish.sql').write_text("""-- Run only after the matching Site asset version is live and publishing is authorized.
begin;
do $$ begin
 assert (select count(*)=45 from public.exams where id=any(array[%s]));
 assert not exists (
  select 1 from public.exams e cross join lateral unnest(e.question_ids) q(id)
  left join public.questions s on s.id=q.id left join public.question_keys k on k.question_id=q.id
  where e.id=any(array[%s]) and (s.id is null or k.question_id is null or s.track_id<>'est')
 );
end $$;
update public.exams set is_published=true where id=any(array[%s]) and not is_published;
commit;
""" % (ids,ids,ids))
print('Prepared draft import and separate activation for',len(bank['questions']),'questions and',len(bank['exams']),'exams.')
