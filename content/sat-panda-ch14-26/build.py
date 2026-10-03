"""Generate page-batched, image-first College Panda SAT imports.

Every question uses its original scanned panel. Worked-answer pages are stored
once in a private table and shown only after checking in final revision. No
OCR equation is substituted for the original problem.
"""
import base64
import hashlib
import io
import json
import sys
import uuid
from collections import defaultdict
from pathlib import Path

import fitz
from PIL import Image
from extract import ANSWER_PAGES, CHAPTERS, SOURCE_SHA

HERE = Path(__file__).resolve().parent
SOURCE_LIBRARY_FILE_ID = 'libfile_d6167ab9f44881919492feff68ef28d4'
# (last question number on that answer page, PDF page); checked against the
# exercise headings and printed number labels in the original answer section.
ANSWER_ENDS = {
    '14-1': [(12,365),(19,366)], '14-2': [(10,367),(18,368),(21,369)],
    '15-1': [(11,370),(18,371)],
    '16-1': [(10,372),(16,373),(18,374)],
    '16-2': [(6,374),(13,375),(18,376),(22,377)],
    '17-1': [(9,378),(16,379)],
    '18-1': [(11,380),(18,381),(19,382)],
    '18-2': [(3,382),(12,383),(16,384),(20,385),(23,386)],
    '19-1': [(12,387),(14,388)],
    '19-2': [(5,388),(13,389),(17,390),(18,390)],
    '20-1': [(12,391),(15,392)],
    '21-1': [(9,393),(13,394)], '21-2': [(7,395),(13,396)],
    '22-1': [(14,397),(16,398)], '22-2': [(8,398),(14,399),(16,400)],
    '23-1': [(16,401),(19,402)],
    '24-1': [(17,403)], '24-2': [(12,404),(17,405)],
    '25-1': [(11,406),(17,407)], '25-2': [(5,407),(12,408),(17,409)],
    '26-1': [(12,410),(16,411)], '26-2': [(6,411),(16,412)],
}

def source_image(doc, page, rect=None):
    scale = 1.6 if rect else 1.4
    pix = doc[page-1].get_pixmap(matrix=fitz.Matrix(scale,scale))
    image = Image.frombytes('RGB',(pix.width,pix.height),pix.samples).convert('L')
    if rect:
        image = image.crop(tuple(rect))
        assert image.width > 250 and image.height > 65
    else:
        assert image.width > 800
    out=io.BytesIO()
    image.save(out,format='JPEG',quality=43 if rect else 31,optimize=True)
    return 'data:image/jpeg;base64,'+base64.b64encode(out.getvalue()).decode('ascii')

def sql_literal(value):
    return "'"+value.replace("'","''")+"'"

def import_sql(rows, solution_image):
    expected=len(rows)
    solution_page=rows[0]['solution_page']
    assert all(r['solution_page']==solution_page for r in rows)
    literal=sql_literal(json.dumps(rows,ensure_ascii=False,separators=(',',':')))
    solution=sql_literal(solution_image)
    return f"""-- Checked College Panda original image and worked key, {expected} exercises.
-- Pinned original PDF SHA256 {SOURCE_SHA}
begin;
set local statement_timeout='90s';
create temporary table panda_solution on commit drop as select {solution}::text as figure;
insert into public.panda_solution_pages(page,figure)
select {solution_page},figure from panda_solution on conflict(page) do nothing;
do $$ begin
 if not exists(select 1 from public.panda_solution_pages p
    join panda_solution s on s.figure=p.figure where p.page={solution_page})
 then raise exception 'panda_solution_page_changed'; end if;
end $$;
create temporary table panda_batch on commit drop as
select * from jsonb_to_recordset({literal}::jsonb)
 as r(chapter integer,exercise integer,n integer,page integer,solution_page integer,
      id uuid,code text,topic text,lesson text,stem text,choices jsonb,
      correct text,accepted jsonb,explanation text,assets jsonb);
do $$ begin
 if (select count(*) from panda_batch)<>{expected}
 or exists(select 1 from panda_batch group by code having count(*)>1)
 or exists(select 1 from panda_batch i join public.questions q on q.track_id='sat'
    where q.id not in(select id from panda_batch) and
    (q.assets->>'code'=i.code or regexp_replace(lower(q.stem),'[^[:alnum:]]','','g')=
       regexp_replace(lower(i.stem),'[^[:alnum:]]','','g')))
 or exists(select 1 from panda_batch i join public.questions q on q.id=i.id
    left join public.question_keys k on k.question_id=q.id
    where q.track_id<>'sat' or q.stem<>i.stem or q.choices<>i.choices or q.assets<>i.assets
       or k.correct is distinct from (case when jsonb_array_length(i.choices)>0 then to_jsonb(i.correct)
                             else i.accepted end) or k.explanation<>i.explanation)
 then raise exception 'panda_ch14_26_duplicate_or_changed'; end if;
end $$;
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select id,'sat',topic,'medium',case when jsonb_array_length(choices)>0 then 'mcq' else 'grid_in' end,
 stem,choices,assets from panda_batch on conflict(id) do nothing;
insert into public.question_keys(question_id,correct,explanation)
select id,case when jsonb_array_length(choices)>0 then to_jsonb(correct) else accepted end,
 explanation from panda_batch on conflict(question_id) do nothing;
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
select i.id,i.lesson,i.topic,'medium',array['sat']::text[],
 md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text),
 true,jsonb_build_object('collections',jsonb_build_array('unique'),
    'bank_occurrences',1,'takeaway',i.explanation)
from panda_batch i join public.questions q on q.id=i.id
join public.question_keys k on k.question_id=q.id on conflict(question_id) do nothing;
do $$ begin
 if (select count(*) from panda_batch i join public.questions q on q.id=i.id)<>{expected}
 or (select count(*) from panda_batch i join public.question_keys k on k.question_id=i.id)<>{expected}
 or (select count(*) from panda_batch i join public.revision_items r on r.question_id=i.id)<>{expected}
 then raise exception 'panda_ch14_26_incomplete'; end if;
end $$;
commit;
"""

def build(source, output):
    if hashlib.sha256(source.read_bytes()).hexdigest()!=SOURCE_SHA:
        raise SystemExit('Source checksum differs from the reviewed PDF')
    index=json.loads((HERE/'question-index.json').read_text())
    keys=json.loads((HERE/'reviewed-keys.json').read_text())
    assert len(index)==380
    assert sum(map(len,keys.values()))==380
    for ex,ends in ANSWER_ENDS.items():
        assert ends[-1][0]==len(keys[ex]), ex
    doc=fitz.open(source)
    by_page=defaultdict(list)
    seen=set()
    for q in index:
        ch,ex,n=q['chapter'],q['exercise'],q['n']
        key=f'{ch}-{ex}'
        assert 1<=n<=len(keys[key])
        answer=keys[key][n-1].split('|')
        assert answer and all(answer)
        solution_page=next(p for last,p in ANSWER_ENDS[key] if n<=last)
        assert ANSWER_PAGES[ch][ex-1][1] <= solution_page <= ANSWER_PAGES[ch][ex-1][2]
        code=f'PANDA-CH{ch:02}-E{ex}-Q{n:02}'
        assert code not in seen
        seen.add(code)
        topic=q['topic']
        is_mcq=(len(answer)==1 and answer[0] in 'ABCD')
        choices=[{'key':x,'text':''} for x in 'ABCD'] if is_mcq else []
        stem=f'College Panda Chapter {ch}, {topic}, Exercise {ex}, Question {n}. Read the original problem shown below.'
        explanation=(f'Compare your work with the printed worked solution for Chapter {ch}, '
                     f'Exercise {ex}, Question {n} on page {solution_page+1}. '
                     'Open the scanned solution below after checking your answer.')
        assets={'code':code,'paper':'College Panda SAT Math Advanced Guide & Workbook',
            'source_page':q['page'],'source_chapter':ch,'source_exercise':ex,
            'source_number':n,'source_sha256':SOURCE_SHA,
            'source_library_file_id':SOURCE_LIBRARY_FILE_ID,
            'solution_page':solution_page,
            'content_review':{'status':'verified','method':'Original numbered question panel and boxed worked answer independently read',
              'source_fidelity':'Original question and choices are reproduced as a scanned image; worked-answer page is attached'},
            'figure':source_image(doc,q['page'],q['rect']),
            'figure_caption':f'Original College Panda Chapter {ch}, Exercise {ex}, Question {n}'}
        row={'chapter':ch,'exercise':ex,'n':n,'page':q['page'],
             'solution_page':solution_page,
             'id':str(uuid.uuid5(uuid.NAMESPACE_URL,
                f'ghoneem/college-panda/chapter-{ch}/exercise-{ex}/question-{n}')),
             'code':code,'topic':topic,'lesson':topic,'stem':stem,'choices':choices,
             'correct':answer[0], 'accepted':None if is_mcq else answer,
             'explanation':explanation,'assets':assets}
        by_page[solution_page].append(row)
    assert len(by_page)==48, f'expected 48 answer pages, found {len(by_page)}'
    output.mkdir(parents=True,exist_ok=True)
    for page,rows in sorted(by_page.items()):
        file=output/f'panda-answer-page-{page:03}.sql'
        file.write_text(import_sql(rows,source_image(doc,page)))
        print(f'PDF answer page {page}: {len(rows)} exercises, SQL {file.stat().st_size:,} bytes')
    assert sum(map(len,by_page.values()))==380

if __name__=='__main__':
    if len(sys.argv)!=3:raise SystemExit('usage: build.py ORIGINAL_PDF OUTPUT_SQL_DIRECTORY')
    build(Path(sys.argv[1]),Path(sys.argv[2]))
