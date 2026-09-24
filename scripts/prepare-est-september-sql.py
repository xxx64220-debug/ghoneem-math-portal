"""Insert-only content batches and separate activation after assets are live."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1];out=root/'content/est-september-2026'
bank=json.loads((out/'release-bank.json').read_text())
def literal(v):return "'"+json.dumps(v,ensure_ascii=False,separators=(',',':')).replace("'","''")+"'::jsonb"
for start in range(0,len(bank['questions']),30):
 data=literal(bank['questions'][start:start+30])
 sql=f"""with src as (select * from jsonb_to_recordset({data}) as r(id uuid,track_id text,topic text,difficulty text,type text,stem text,choices jsonb,assets jsonb,correct jsonb,explanation text)),
 inserted as (insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
 select id,track_id,topic,difficulty,type,stem,choices,assets from src on conflict(id) do nothing returning id),
 keys as (insert into public.question_keys(question_id,correct,explanation)
 select s.id,s.correct,s.explanation from src s join inserted i on i.id=s.id on conflict(question_id) do nothing returning question_id)
 select (select count(*) from inserted) as questions_inserted,(select count(*) from keys) as keys_inserted;
 """
 (out/f'import-questions-{start//30+1}.sql').write_text(sql)
sql=f"""with src as (select * from jsonb_to_recordset({literal(bank['exams'])}) as r(id uuid,track_id text,title text,duration_seconds int,question_ids uuid[],shuffle boolean,review_policy text,max_attempts int,is_full_length boolean,assessment_type text)),
 inserted as (insert into public.exams(id,track_id,title,duration_seconds,question_ids,shuffle,review_policy,max_attempts,is_published,is_full_length,assessment_type,scoring_map)
 select id,track_id,title,duration_seconds,question_ids,shuffle,review_policy,max_attempts,false,is_full_length,assessment_type,null from src on conflict(id) do nothing returning id),
 assigned as (insert into public.assignments(exam_id,group_id) select id,public.default_group('est') from inserted returning id)
 select (select count(*) from inserted) as unpublished_exams_inserted,(select count(*) from assigned) as assignments_inserted;
"""
(out/'import-exams.sql').write_text(sql)
ids=','.join("'"+e['id']+"'::uuid" for e in bank['exams'])
(out/'activate.sql').write_text(f"""begin;
do $$ begin
 assert (select count(*)={len(bank['exams'])} from public.exams where id=any(array[{ids}]));
 assert not exists(select 1 from public.exams e cross join lateral unnest(e.question_ids) i(id) left join public.questions q on q.id=i.id left join public.question_keys k on k.question_id=q.id where e.id=any(array[{ids}]) and (q.id is null or k.question_id is null or q.track_id<>'est'));
end $$;
update public.exams set is_published=true where id=any(array[{ids}]) and not is_published;
commit;
select assessment_type,count(*) as published from public.exams where id=any(array[{ids}]) and is_published group by assessment_type;
""")
print('Prepared four insert-only question batches,33 draft assessments and separate activation.')
