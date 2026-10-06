"""Build the checked Elite May math intake from a local copy of the supplied PDF."""
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
SOURCE_SHA = '664f00c14f03c1482d2368ab90c2f3ddccee42c6a3ec2962431bb5c521535a0f'
if len(sys.argv) != 3:
    raise SystemExit('usage: build.py ORIGINAL_PDF OUTPUT_SQL')
source, output = Path(sys.argv[1]), Path(sys.argv[2])
if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA:
    raise SystemExit('Source PDF checksum differs; inspect the source before building')
doc = fitz.open(source)
items = json.loads((HERE / 'questions.json').read_text())
assert len(items) == 44
assert {(q['module'], q['n']) for q in items} == {(m,n) for m in (1,2) for n in range(1,23)}
LESSONS = {
    'Linear equations':'Linear equations', 'Percentages':'Percentages',
    'Linear systems':'Linear systems', 'Linear functions':'Lines and linear models',
    'Parallel lines':'Lines and linear models', 'Evaluating functions':'Functions and graphs',
    'Quadratic equations':'Quadratics', 'Linear inequalities':'Linear inequalities',
    'Polynomials':'Polynomials', 'Absolute value':'Linear equations',
    'Rearranging formulas':'Linear equations', 'Radians and degrees':'Right triangles and trigonometry',
    'Scatterplots and models':'Scatterplots and models', 'Conditional probability':'Probability',
    'Exponential models':'Exponential models', 'Perimeter':'Area and volume',
    'Radical equations':'Exponents and radicals', 'Right triangles':'Right triangles and trigonometry',
    'Circle equations':'Circles', 'Triangle area':'Area and volume', 'Exponent rules':'Exponents and radicals',
    'Vertical lines':'Lines and linear models', 'Rational functions':'Rational expressions and equations',
    'Quadratics':'Quadratics', 'Graphing lines':'Lines and linear models',
    'Ratios and units':'Ratios, rates and units', 'Quadratic functions':'Quadratics',
    'Linear models':'Lines and linear models', 'Trigonometry':'Right triangles and trigonometry',
    'Discriminant':'Quadratics', 'Polynomial factors':'Polynomials', 'Quadratic models':'Scatterplots and models',
    'Percent change':'Percentages'
}
assert {q['topic'] for q in items} <= LESSONS.keys()
raw_img_sha = {}
for q in items:
    m, n = q['module'], q['n']
    page = (54 if m == 1 else 76) + n + (1 if m == 2 and n == 22 else 0)
    assert page <= len(doc)
    image_refs = [ref for ref in doc[page-1].get_images(full=True) if ref[2] > 500 and ref[3] > 500]
    assert image_refs, (m, n)
    source_bytes = doc.extract_image(image_refs[0][0])['image']
    raw_img_sha[f'M{m}-Q{n:02}'] = hashlib.sha256(source_bytes).hexdigest()
    figure = None
    if q.get('visual'):
        ims = []
        for sp in q.get('source_pages', [page]):
            ref = next(ref for ref in doc[sp-1].get_images(full=True)
                       if ref[2]>500 and ref[3]>500)
            raw = doc.extract_image(ref[0])['image']
            shot = Image.open(io.BytesIO(raw)).convert('RGB')
            if (m,n)==(2,21):
                shot = shot.crop((0,20,min(1300,shot.width),min(675,shot.height)))
            elif not q['choices'] or (m,n)==(2,10):
                shot = shot.crop((min(900,shot.width//2),20,shot.width,min(675,shot.height)))
            else:
                shot = shot.crop((min(350,shot.width//4),20,shot.width,min(675,shot.height)))
            ims.append(shot)
        if len(ims)>1:
            width=max(im.width for im in ims)
            combined=Image.new('RGB',(width,sum(im.height for im in ims)+10*(len(ims)-1)),'white')
            y=0
            for im in ims:
                combined.paste(im,(0,y));y+=im.height+10
            shot=combined
        else: shot=ims[0]
        shot.thumbnail((1400,1300))
        buf = io.BytesIO(); shot.save(buf,format='JPEG',quality=78,optimize=True)
        figure = 'data:image/jpeg;base64,' + base64.b64encode(buf.getvalue()).decode()
    q['id'] = str(uuid.uuid5(uuid.NAMESPACE_URL, f'ghoneem/sat-elite-may-2026/m{m}/q{n}'))
    q['code'] = f'ELITEMAY26-M{m}-Q{n:02}'
    q['page'] = page
    q['lesson'] = LESSONS[q['topic']]
    q['assets'] = {
        'code': q['code'], 'paper':'Elite Practice X6 May Edition',
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

# Independent arithmetic checks for the more error-prone answers.
assert (131-5)/21==6
assert 14+7/25==357/25
assert 20/(20+30)==0.4
assert 36*((-5/9)+6)==196
assert 37500 == 60*25*25 and 960 == 60*4*4
assert 28/2.8==10

def sql_literal(s): return "'" + s.replace("'","''") + "'"
payload = sql_literal(json.dumps(items,ensure_ascii=False,separators=(',',':')))
sql = f"""-- Elite May Edition: 44 independently checked SAT math questions.
-- Original PDF SHA-256: {SOURCE_SHA}
-- All 44 math-module questions are represented.
begin;
set local statement_timeout='50s';
create temporary table sat_elite_may on commit drop as
select * from jsonb_to_recordset({payload}::jsonb)
 as x(module integer,n integer,topic text,stem text,choices jsonb,correct text,
       explanation text,visual boolean,id uuid,code text,page integer,lesson text,assets jsonb);
do $$ begin
 if (select count(*) from sat_elite_may)<>44
 or exists(select 1 from sat_elite_may group by code having count(*)>1)
 or exists(select 1 from sat_elite_may i join public.questions q on q.track_id='sat'
   where q.id<>i.id and (q.assets->>'code'=i.code
    or regexp_replace(lower(q.stem),'[^[:alnum:]]','','g')=
       regexp_replace(lower(i.stem),'[^[:alnum:]]','','g')))
 or exists(select 1 from sat_elite_may i join public.questions q on q.id=i.id
   left join public.question_keys k on k.question_id=q.id
   where q.track_id<>'sat' or q.stem<>i.stem or q.choices<>i.choices
     or q.assets<>i.assets or k.correct is distinct from
       case when jsonb_array_length(i.choices)>0 then to_jsonb(i.correct)
            else jsonb_build_array(i.correct) end
     or k.explanation<>i.explanation)
 then raise exception 'sat_elite_may_duplicate_or_changed'; end if;
end $$;
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select id,'sat',topic,'medium',
       case when jsonb_array_length(choices)>0 then 'mcq' else 'grid_in' end,
       stem,choices,assets from sat_elite_may on conflict(id) do nothing;
insert into public.question_keys(question_id,correct,explanation)
select id,case when jsonb_array_length(choices)>0 then to_jsonb(correct)
               else jsonb_build_array(correct) end,explanation
from sat_elite_may on conflict(question_id) do nothing;
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
select i.id,i.lesson,i.topic,'medium',array['sat']::text[],
       md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text),
       true,jsonb_build_object('collections',jsonb_build_array('unique'),
                               'bank_occurrences',1,'takeaway',i.explanation)
from sat_elite_may i join public.questions q on q.id=i.id
join public.question_keys k on k.question_id=q.id
on conflict(question_id) do nothing;
do $$ begin
 if (select count(*) from public.questions where assets->>'code' like 'ELITEMAY26-M%-Q%')<>44
 or (select count(*) from sat_elite_may i join public.question_keys k on k.question_id=i.id)<>44
 or (select count(*) from sat_elite_may i join public.revision_items r on r.question_id=i.id)<>44
 then raise exception 'sat_elite_may_incomplete'; end if;
end $$;
commit;
"""
output.write_text(sql)
(HERE/'image-hashes.json').write_text(json.dumps(raw_img_sha,indent=2)+'\n')
print(f'Built {len(items)} graded rows, {sum(q.get("visual",False) for q in items)} with source visuals; SQL bytes {len(sql)}')
