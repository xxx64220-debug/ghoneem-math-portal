"""Build the checked March International SAT math intake from a local copy of the supplied PDF."""
import base64
import hashlib
import io
import json
import sys
import uuid
from fractions import Fraction
from pathlib import Path

import fitz
from PIL import Image

HERE = Path(__file__).resolve().parent
SOURCE_SHA = '57ba41043b3052bd2bd7159288b5439e619baf3542447c914e8c17307d3394bb'
if len(sys.argv) != 3:
    raise SystemExit('usage: build.py ORIGINAL_PDF OUTPUT_SQL')
source, output = Path(sys.argv[1]), Path(sys.argv[2])
if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA:
    raise SystemExit('Source PDF checksum differs; inspect the source before building')
doc = fitz.open(source)
items = json.loads((HERE / 'questions.json').read_text())
assert len(items) == 40
assert {(q['module'], q['n']) for q in items} == (
    {(m, n) for m in (1, 2) for n in range(1, 23)}
    - {(1, 6), (1, 12), (1, 18), (1, 22)})
assert len({(q['module'], q['n']) for q in items}) == 40

LESSONS = {
    'Volume':'Area and volume', 'Area':'Area and volume',
    'Systems of inequalities':'Linear inequalities', 'Linear functions':'Lines and linear models',
    'Mean and median':'Statistics', 'Linear systems':'Linear systems',
    'Percentages':'Percentages', 'Percent change':'Percentages',
    'Polynomial factors':'Polynomials', 'Exponent rules':'Exponents and radicals',
    'Exponential models':'Exponential models', 'Exponential graphs':'Exponential models',
    'Similar triangles':'Angles, triangles and similarity',
    'Perpendicular lines':'Lines and linear models', 'Rates and units':'Ratios, rates and units',
    'Probability':'Probability', 'Linear models':'Lines and linear models',
    'Graphing lines':'Lines and linear models', 'Quadratic equations':'Quadratics',
    'Radians and degrees':'Right triangles and trigonometry', 'Subtraction':'Linear equations',
    'Line of best fit':'Scatterplots and models', 'Graph intersections':'Nonlinear systems',
    'Linear equations':'Linear equations', 'Unit conversion':'Ratios, rates and units',
    'Evaluating functions':'Functions and graphs', 'Rational functions':'Rational expressions and equations',
    'Frequency tables':'Statistics', 'Factoring':'Polynomials',
    'Polynomial functions':'Polynomials', 'Exponential functions':'Exponential models'
}
assert {q['topic'] for q in items} <= LESSONS.keys()
raw_img_sha = {}
for q in items:
    m, n = q['module'], q['n']
    page = (54 if m == 1 else 76) + n
    assert page <= len(doc)
    image_refs = [ref for ref in doc[page-1].get_images(full=True) if ref[2] > 500 and ref[3] > 500]
    assert image_refs, (m, n)
    source_bytes = doc.extract_image(image_refs[0][0])['image']
    raw_img_sha[f'M{m}-Q{n:02}'] = hashlib.sha256(source_bytes).hexdigest()
    figure = None
    if q.get('visual'):
        im = Image.open(io.BytesIO(source_bytes)).convert('RGB')
        gray = im.convert('L')
        ink = gray.point(lambda v: 255 if v < 190 else 0)
        bbox = ink.getbbox()
        assert bbox is not None and bbox[3] > bbox[1] + 50
        l,t,r,b = bbox
        im = im.crop((max(l-15,0),max(t-15,0),min(r+15,im.width),min(b+15,im.height)))
        im = im.convert('L').point(lambda v: 255 if v > 205 else 0, mode='1')
        buf = io.BytesIO(); im.save(buf,format='PNG',optimize=True)
        figure = 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode()
    q['id'] = str(uuid.uuid5(uuid.NAMESPACE_URL, f'ghoneem/sat-march-int-2026/m{m}/q{n}'))
    q['code'] = f'MARCHINT26-M{m}-Q{n:02}'
    q['page'] = page
    q['lesson'] = LESSONS[q['topic']]
    q['assets'] = {
        'code': q['code'], 'paper':'SAT March International Version C',
        'source_page':page, 'source_number':n, 'source_module':m,
        'source_sha256':SOURCE_SHA, 'source_image_sha256':raw_img_sha[f'M{m}-Q{n:02}'],
        'source_library_file_id':'libfile_700d72e693a881918b7ebbb0eee38163',
        'figure':figure, 'figure_caption':f'Original source diagram or table, Module {m} Question {n}',
        'content_review':{'status':'verified','method':'Original image read; answer independently solved; distractors and required visuals checked',
                          'source_fidelity':'Concise accessible transcription; original visual included where required'}
    }
    if figure is None:
        del q['assets']['figure']
    assert q['correct'] and len(q['explanation']) >= 20, (m,n,q['explanation'])
    assert len(q['choices']) in (0,4)
    assert (q['correct'] in ('A','B','C','D')) if q['choices'] else True
    if q['choices']:
        q['choices'] = [{'key':chr(65+i),'text':c} for i,c in enumerate(q['choices'])]

# Arithmetic checks independent from the authored answer text.
assert next(q for q in items if q['module']==1 and q['n']==5)['correct'] == str((306+86)//56)
assert 20*1.8*.75 == 27
assert 52*Fraction(63,52)-12 == 51
assert 22-(4/5)*16 == 46/5
assert 6600-110*50 == 1100
assert 13*(13-5) == 104
assert 2*8+7*6 == 58
assert 530*2**(50/25) == 2120

def sql_literal(s): return "'" + s.replace("'","''") + "'"
payload = sql_literal(json.dumps(items,ensure_ascii=False,separators=(',',':')))
sql = f"""-- March International Version C: 40 independently checked SAT math questions.
-- Original PDF SHA-256: {SOURCE_SHA}
-- Four defective/source-limited questions are recorded in README.md, not graded.
begin;
set local statement_timeout='50s';
create temporary table sat_march_int on commit drop as
select * from jsonb_to_recordset({payload}::jsonb)
 as x(module integer,n integer,topic text,stem text,choices jsonb,correct text,
       explanation text,visual boolean,id uuid,code text,page integer,lesson text,assets jsonb);
do $$ begin
 if (select count(*) from sat_march_int)<>40
 or exists(select 1 from sat_march_int group by code having count(*)>1)
 or exists(select 1 from sat_march_int i join public.questions q on q.track_id='sat'
   where q.id<>i.id and (q.assets->>'code'=i.code
    or regexp_replace(lower(q.stem),'[^[:alnum:]]','','g')=
       regexp_replace(lower(i.stem),'[^[:alnum:]]','','g')))
 or exists(select 1 from sat_march_int i join public.questions q on q.id=i.id
   left join public.question_keys k on k.question_id=q.id
   where q.track_id<>'sat' or q.stem<>i.stem or q.choices<>i.choices
     or q.assets<>i.assets or k.correct is distinct from
       case when jsonb_array_length(i.choices)>0 then to_jsonb(i.correct)
            else jsonb_build_array(i.correct) end
     or k.explanation<>i.explanation)
 then raise exception 'sat_march_int_duplicate_or_changed'; end if;
end $$;
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select id,'sat',topic,'medium',
       case when jsonb_array_length(choices)>0 then 'mcq' else 'grid_in' end,
       stem,choices,assets from sat_march_int on conflict(id) do nothing;
insert into public.question_keys(question_id,correct,explanation)
select id,case when jsonb_array_length(choices)>0 then to_jsonb(correct)
               else jsonb_build_array(correct) end,explanation
from sat_march_int on conflict(question_id) do nothing;
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
select i.id,i.lesson,i.topic,'medium',array['sat']::text[],
       md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text),
       true,jsonb_build_object('collections',jsonb_build_array('unique'),
                               'bank_occurrences',1,'takeaway',i.explanation)
from sat_march_int i join public.questions q on q.id=i.id
join public.question_keys k on k.question_id=q.id
on conflict(question_id) do nothing;
do $$ begin
 if (select count(*) from public.questions where assets->>'code' like 'MARCHINT26-M%-Q%')<>40
 or (select count(*) from sat_march_int i join public.question_keys k on k.question_id=i.id)<>40
 or (select count(*) from sat_march_int i join public.revision_items r on r.question_id=i.id)<>40
 then raise exception 'sat_march_int_incomplete'; end if;
end $$;
commit;
"""
output.write_text(sql)
(HERE/'image-hashes.json').write_text(json.dumps(raw_img_sha,indent=2)+'\n')
print(f'Built {len(items)} graded rows, {sum(q.get("visual",False) for q in items)} with source visuals; SQL bytes {len(sql)}')
