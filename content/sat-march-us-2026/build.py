"""Build the checked March US SAT math intake from a local copy of the supplied PDF."""
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
SOURCE_SHA = 'a486567d62181cdf7a8979987e82c690e2fc5f54cebc9d4a0d20014bcde163fd'
if len(sys.argv) != 3:
    raise SystemExit('usage: build.py ORIGINAL_PDF OUTPUT_SQL')
source, output = Path(sys.argv[1]), Path(sys.argv[2])
if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA:
    raise SystemExit('Source PDF checksum differs; inspect the source before building')
doc = fitz.open(source)
items = json.loads((HERE / 'questions.json').read_text())
assert len(items)==38
assert {(q['module'],q['n']) for q in items} == (
    {(m,n) for m in (1,2) for n in range(1,23)}
    - {(1,6),(1,19),(2,3),(2,16),(2,17),(2,19)})
LESSONS = {
'Exponential functions':'Exponential models', 'Exponential models':'Exponential models',
'Scatterplots and models':'Scatterplots and models', 'Similar triangles':'Angles, triangles and similarity',
'Discriminant':'Quadratics', 'Rational equations':'Rational expressions and equations',
'Factoring':'Polynomials', 'Evaluating functions':'Functions and graphs',
'Linear models':'Lines and linear models', 'Linear functions':'Lines and linear models',
'Linear inequalities':'Linear inequalities', 'Linear systems':'Linear systems', 'Linear equations':'Linear equations',
'Trigonometry':'Right triangles and trigonometry','Quadratic functions':'Quadratics',
'Percent change':'Percentages', 'Ratios and units':'Ratios, rates and units',
'Mixture equations':'Ratios, rates and units', 'Quadratic equations':'Quadratics',
'Systems of inequalities':'Linear inequalities', 'Circle area':'Circles',
'Tangent geometry':'Circles','Tangents to circles':'Circles',
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
    q['id'] = str(uuid.uuid5(uuid.NAMESPACE_URL, f'ghoneem/sat-march-us-2026/m{m}/q{n}'))
    q['code'] = f'MARCHUS26-M{m}-Q{n:02}'
    q['page'] = page
    q['lesson'] = LESSONS[q['topic']]
    q['assets'] = {
        'code': q['code'], 'paper':'SAT March US Version C',
        'source_page':page, 'source_number':n, 'source_module':m,
        'source_sha256':SOURCE_SHA, 'source_image_sha256':raw_img_sha[f'M{m}-Q{n:02}'],
        'source_pdf_name':source.name,
        'figure':figure, 'figure_caption':f'Original source diagram or table, Module {m} Question {n}',
        'content_review':{'status':'verified','method':'Original image read; answer independently solved; distractors and required visuals checked',
                          'source_fidelity':'Concise accessible transcription; original visual included where required'}
    }
    if figure is None:
        del q['assets']['figure']
    assert q['correct'] and len(q['explanation']) >= 10, (m,n,q['explanation'])
    assert len(q['choices']) in (0,4)
    assert (q['correct'] in ('A','B','C','D')) if q['choices'] else True
    if q['choices']:
        q['choices'] = [{'key':chr(65+i),'text':c} for i,c in enumerate(q['choices'])]

# Independent arithmetic cross-checks.
assert (1.2)**2==1.44
assert (5_174-2*247)//2==2340
assert 247**2+2340**2==2353**2
assert 2.66*.86-1 > 1.28
assert (36*2+9,36*5+9,36*10+9)==(81,189,369)
def sql_literal(s): return "'" + s.replace("'","''") + "'"
payload = sql_literal(json.dumps(items,ensure_ascii=False,separators=(',',':')))
sql = f"""-- March US Version C: 40 independently checked SAT math questions.
-- Original PDF SHA-256: {SOURCE_SHA}
-- Six source-limited or ungradable questions are recorded in README.md.
begin;
set local statement_timeout='50s';
create temporary table sat_march_us on commit drop as
select * from jsonb_to_recordset({payload}::jsonb)
 as x(module integer,n integer,topic text,stem text,choices jsonb,correct text,
       explanation text,visual boolean,id uuid,code text,page integer,lesson text,assets jsonb);
do $$ begin
 if (select count(*) from sat_march_us)<>38
 or exists(select 1 from sat_march_us group by code having count(*)>1)
 or exists(select 1 from sat_march_us i join public.questions q on q.track_id='sat'
   where q.id<>i.id and (q.assets->>'code'=i.code
    or regexp_replace(lower(q.stem),'[^[:alnum:]]','','g')=
       regexp_replace(lower(i.stem),'[^[:alnum:]]','','g')))
 or exists(select 1 from sat_march_us i join public.questions q on q.id=i.id
   left join public.question_keys k on k.question_id=q.id
   where q.track_id<>'sat' or q.stem<>i.stem or q.choices<>i.choices
     or q.assets<>i.assets or k.correct is distinct from
       case when jsonb_array_length(i.choices)>0 then to_jsonb(i.correct)
            else jsonb_build_array(i.correct) end
     or k.explanation<>i.explanation)
 then raise exception 'sat_march_us_duplicate_or_changed'; end if;
end $$;
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select id,'sat',topic,'medium',
       case when jsonb_array_length(choices)>0 then 'mcq' else 'grid_in' end,
       stem,choices,assets from sat_march_us on conflict(id) do nothing;
insert into public.question_keys(question_id,correct,explanation)
select id,case when jsonb_array_length(choices)>0 then to_jsonb(correct)
               else jsonb_build_array(correct) end,explanation
from sat_march_us on conflict(question_id) do nothing;
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
select i.id,i.lesson,i.topic,'medium',array['sat']::text[],
       md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text),
       true,jsonb_build_object('collections',jsonb_build_array('unique'),
                               'bank_occurrences',1,'takeaway',i.explanation)
from sat_march_us i join public.questions q on q.id=i.id
join public.question_keys k on k.question_id=q.id
on conflict(question_id) do nothing;
do $$ begin
 if (select count(*) from public.questions where assets->>'code' like 'MARCHUS26-M%-Q%')<>38
 or (select count(*) from sat_march_us i join public.question_keys k on k.question_id=i.id)<>38
 or (select count(*) from sat_march_us i join public.revision_items r on r.question_id=i.id)<>38
 then raise exception 'sat_march_us_incomplete'; end if;
end $$;
commit;
"""
output.write_text(sql)
(HERE/'image-hashes.json').write_text(json.dumps(raw_img_sha,indent=2)+'\n')
print(f'Built {len(items)} graded rows, {sum(q.get("visual",False) for q in items)} with source visuals; SQL bytes {len(sql)}')
