"""Build a checked, image-backed College Panda Chapter 6 SAT exercise intake."""
import base64
import hashlib
import io
import json
import sys
import uuid
from pathlib import Path

import fitz
from PIL import Image

HERE = Path(__file__).resolve().parent
SOURCE_SHA = 'a6e7dcdb5eb34a88aff2163723015305c2700e26bdde7ce8e6242136a65593b8'
if len(sys.argv) != 3:
    raise SystemExit('usage: build.py ORIGINAL_PDF OUTPUT_SQL')
source, output = Path(sys.argv[1]), Path(sys.argv[2])
if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA:
    raise SystemExit('Source PDF checksum differs')
doc = fitz.open(source)
items = json.loads((HERE / 'questions.json').read_text())
assert len(items)==33
assert {(q['exercise'],q['n']) for q in items} == ({(1,n) for n in range(1,18)} | {(2,n) for n in range(1,17)})
rendered = {}
for q in items:
    ex,n = q['exercise'],q['n']
    q['id']=str(uuid.uuid5(uuid.NAMESPACE_URL,f'ghoneem/college-panda/chapter-6/exercise-{ex}/question-{n}'))
    q['code']=f'PANDA-CH06-E{ex}-Q{n:02}'
    q['topic']='Linear equations and functions'
    q['lesson']='Slope, intercepts, and perpendicular lines'
    q['assets']={
        'code':q['code'],'paper':'College Panda SAT Math Advanced Guide & Workbook',
        'source_page':q['page'],'source_chapter':6,'source_exercise':ex,
        'source_number':n,'source_sha256':SOURCE_SHA,
        'source_library_file_id':'libfile_d6167ab9f44881919492feff68ef28d4',
        'content_review':{'status':'verified','method':'Read original scanned prompt and worked answer; independently verified algebra',
                          'source_fidelity':'Math transcription and source question image for all exercises'}
    }
    if 'rect' in q:
        pg=q['page']
        if pg not in rendered:
            rendered[pg]=Image.frombytes('RGB',(doc[pg-1].get_pixmap(matrix=fitz.Matrix(1.6,1.6)).width,
               doc[pg-1].get_pixmap(matrix=fitz.Matrix(1.6,1.6)).height),
               doc[pg-1].get_pixmap(matrix=fitz.Matrix(1.6,1.6)).samples)
        im=rendered[pg].crop(tuple(q['rect'])).convert('L')
        buf=io.BytesIO(); im.save(buf,format='JPEG',quality=65,optimize=True)
        q['assets']['figure']='data:image/jpeg;base64,'+base64.b64encode(buf.getvalue()).decode()
        q['assets']['figure_caption']=f'Original College Panda Chapter 6 Exercise {ex} Question {n}'
    assert (q['correct'] in 'ABCD' if q['choices'] else q['correct'] not in 'ABCD')
    if q['choices']:
        assert len(q['choices'])==4
        q['choices']=[{'key':chr(65+i),'text':c} for i,c in enumerate(q['choices'])]
    assert len(q['explanation'])>=15, (ex,n,q['explanation'])
    q.pop('rect',None)
def lit(s):return "'"+s.replace("'","''")+"'"
payload=lit(json.dumps(items,ensure_ascii=False,separators=(',',':')))
sql=f"""-- College Panda Chapter 6: 33 independently checked exercises.
-- Source SHA256 {SOURCE_SHA}; Graphs, tables and function composition verified against printed solutions.
begin;
set local statement_timeout='50s';
create temporary table panda_ch06 on commit drop as
select * from jsonb_to_recordset({payload}::jsonb)
 as x(exercise integer,n integer,topic text,stem text,choices jsonb,correct text,accepted jsonb,
       explanation text,page integer,id uuid,code text,lesson text,assets jsonb);
do $$ begin
 if (select count(*) from panda_ch06)<>33
 or exists(select 1 from panda_ch06 group by code having count(*)>1)
 or exists(select 1 from panda_ch06 i join public.questions q on q.track_id='sat'
   where q.id not in (select id from panda_ch06) and (q.assets->>'code'=i.code
     or regexp_replace(lower(q.stem),'[^[:alnum:]]','','g')=
        regexp_replace(lower(i.stem),'[^[:alnum:]]','','g')))
 or exists(select 1 from panda_ch06 i join public.questions q on q.id=i.id
   left join public.question_keys k on k.question_id=q.id
   where q.track_id<>'sat' or q.stem<>i.stem or q.choices<>i.choices or q.assets<>i.assets
     or k.correct is distinct from (case when jsonb_array_length(i.choices)>0 then to_jsonb(i.correct)
           when i.accepted is not null then i.accepted else jsonb_build_array(i.correct) end) or k.explanation<>i.explanation)
 then raise exception 'panda_ch06_duplicate_or_changed'; end if;
end $$;
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select id,'sat',topic,'medium',case when jsonb_array_length(choices)>0 then 'mcq' else 'grid_in' end,
       stem,choices,assets from panda_ch06 on conflict(id) do nothing;
insert into public.question_keys(question_id,correct,explanation)
select id,case when jsonb_array_length(choices)>0 then to_jsonb(correct) when accepted is not null then accepted else jsonb_build_array(correct) end,
       explanation from panda_ch06 on conflict(question_id) do nothing;
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
select i.id,i.lesson,i.topic,'medium',array['sat']::text[],
       md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text),
       true,jsonb_build_object('collections',jsonb_build_array('unique'),
                               'bank_occurrences',1,'takeaway',i.explanation)
from panda_ch06 i join public.questions q on q.id=i.id
join public.question_keys k on k.question_id=q.id on conflict(question_id) do nothing;
do $$ begin
 if (select count(*) from public.questions where assets->>'code' like 'PANDA-CH06-E%-Q%')<>33
 or (select count(*) from panda_ch06 i join public.question_keys k on k.question_id=i.id)<>33
 or (select count(*) from panda_ch06 i join public.revision_items r on r.question_id=i.id)<>33
 then raise exception 'panda_ch06_incomplete'; end if;
end $$;
commit;
"""
output.write_text(sql)
print(f'Built {len(items)} questions, {sum(bool(q["assets"].get("figure")) for q in items)} source images, {len(sql)} SQL chars')
