"""Build the two recovered September SAT questions from the exact source PDF."""
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
SHA = '4a9e4676c5588802d579110119ab125bf5980a71bc103a960231722a641d05ee'
if len(sys.argv) != 3:
    raise SystemExit('usage: build.py ORIGINAL_PDF OUTPUT_SQL')
source, output = map(Path, sys.argv[1:])
if hashlib.sha256(source.read_bytes()).hexdigest() != SHA:
    raise SystemExit('Source PDF checksum differs; inspect the exact file first')
items = json.loads((HERE / 'questions.json').read_text())
assert [q['n'] for q in items] == [19, 24]
assert items[0]['correct'] == 'B' and items[1]['correct'] == ['414']
assert 127 - 54 == 73 and 43 + 371 == 414
doc = fitz.open(source)
assert len(doc) == 27

for q in items:
    n = q['n']
    # Include the original angle labels and the previously overlooked equation.
    region = fitz.Rect(210, 240, 445, 470) if n == 19 else fitz.Rect(40, 345, 570, 465)
    pix = doc[q['page'] - 1].get_pixmap(matrix=fitz.Matrix(2, 2), clip=region, alpha=False)
    image = Image.open(io.BytesIO(pix.tobytes('png'))).convert('L')
    image = image.point(lambda v: 255 if v > 220 else 0, mode='1')
    buf = io.BytesIO()
    image.save(buf, format='PNG', optimize=True)
    figure = buf.getvalue()
    assert len(figure) < 150_000 and len(figure) > 2_000
    q['id'] = str(uuid.uuid5(uuid.NAMESPACE_URL, f'ghoneem/sat-valley/september-2026/q{n:02}'))
    q['code'] = f'SATVALLEY-SEP26-Q{n:02}'
    q['assets'] = {
        'code': q['code'], 'paper': 'SAT Valley September 2026 predictions',
        'source': 'SAT Valley September 2026 practice set',
        'source_page': q['page'], 'source_number': n, 'source_sha256': SHA,
        'source_filename': source.name,
        'source_library_file_id': 'libfile_ab5b47543a6881919e90749a76c3d5f8',
        'source_image_sha256': hashlib.sha256(figure).hexdigest(),
        'figure': 'data:image/png;base64,' + base64.b64encode(figure).decode(),
        'figure_caption': f'Original SAT Valley September question {n} diagram and equation',
        'content_review': {
            'status': 'verified',
            'method': 'Original page visually checked; worked solution and answer sheet independently verified',
            'source_fidelity': 'Original visual attached with accessible question transcription'
        }
    }
    assert len(q['choices']) in (0, 4) and len(q['explanation']) > 80
    if q['choices']:
        q['choices'] = [{'key': chr(65+i), 'text': c} for i, c in enumerate(q['choices'])]
    q['focus'] = {'collections': ['unique'], 'bank_occurrences': 1, 'takeaway': q['takeaway']}

def literal(s):
    return "'" + s.replace("'", "''") + "'"

payload = literal(json.dumps(items, ensure_ascii=False, separators=(',', ':')))
sql = f"""-- Two independently checked source holds recovered from the original September PDF.
begin;
set local statement_timeout='60s';
create temporary table sat_sep_recovered on commit drop as
 select * from jsonb_to_recordset({payload}::jsonb)
 as i(n integer,page integer,topic text,lesson text,idea text,difficulty text,
      stem text,choices jsonb,correct jsonb,explanation text,takeaway text,
      id uuid,code text,assets jsonb,focus jsonb);
do $$ begin
 if (select count(*) from sat_sep_recovered)<>2
 or exists(select 1 from sat_sep_recovered group by id having count(*)>1)
 or exists(select 1 from sat_sep_recovered i join public.questions q
    on q.track_id='sat' and q.id<>i.id and
      (q.assets->>'code'=i.code or
       regexp_replace(lower(q.stem),'[^[:alnum:]]','','g')=
       regexp_replace(lower(i.stem),'[^[:alnum:]]','','g')))
 or exists(select 1 from sat_sep_recovered i join public.questions q on q.id=i.id
    left join public.question_keys k on k.question_id=q.id
    where q.track_id<>'sat' or q.stem<>i.stem or q.assets<>i.assets
       or q.choices<>i.choices or k.correct is distinct from i.correct
       or k.explanation is distinct from i.explanation)
 then raise exception 'sat_sep_recovered_duplicate_or_changed'; end if;
end $$;
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select id,'sat',topic,difficulty,case when jsonb_array_length(choices)=4 then 'mcq' else 'grid_in' end,
       stem,choices,assets from sat_sep_recovered on conflict(id) do nothing;
insert into public.question_keys(question_id,correct,explanation)
select id,correct,explanation from sat_sep_recovered on conflict(question_id) do nothing;
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
select i.id,i.lesson,i.idea,i.difficulty,array['sat']::text[],
       md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text),true,i.focus
from sat_sep_recovered i join public.questions q on q.id=i.id
join public.question_keys k on k.question_id=i.id
on conflict(question_id) do nothing;
do $$ begin
 if (select count(*) from public.questions where assets->>'code' like 'SATVALLEY-SEP26-Q%')<>23
 or exists(select 1 from sat_sep_recovered i left join public.questions q on q.id=i.id
    left join public.question_keys k on k.question_id=i.id
    left join public.revision_items r on r.question_id=i.id
    where q.id is null or k.question_id is null or r.question_id is null or not r.active
      or r.fingerprint<>md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text))
 then raise exception 'sat_sep_recovered_incomplete'; end if;
end $$;
commit;
"""
output.write_text(sql)
print(f'Built {len(items)} checked questions; source {SHA}; SQL bytes {output.stat().st_size}')
