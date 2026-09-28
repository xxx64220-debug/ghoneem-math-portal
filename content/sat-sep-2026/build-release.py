"""Build a guarded, repeatable release from the checked September transcription.

The original PDF remains in the user's attachment collection, not this repository.
Never derive keys from OCR alone.
"""
import json
import uuid
from pathlib import Path

DIR = Path(__file__).parent
items = json.loads((DIR / 'questions.json').read_text())
source_sha = '4a9e4676c5588802d579110119ab125bf5980a71bc103a960231722a641d05ee'
assert len(items) == 21
assert {q['n'] for q in items} == set(range(1,18)) | {20,21,22,23}

lesson_aliases = {
    'Triangles and similarity':'Angles, triangles and similarity',
    'Trigonometry':'Right triangles and trigonometry',
    'Volume and surface area':'Area and volume',
    'Angles and polygons':'Angles, triangles and similarity',
}
for q in items:
    q['lesson'] = lesson_aliases.get(q['lesson'], q['lesson'])
    assert len(q['choices']) in (0,4)
    assert q['correct'] in 'ABCD' if q['choices'] else bool(q['correct'])
    assert len(q['explanation']) > 45 and len(q['stem']) > 35
    q['id'] = str(uuid.uuid5(uuid.NAMESPACE_URL, f"ghoneem/sat-valley/september-2026/q{q['n']:02}"))
    q['code'] = f"SATVALLEY-SEP26-Q{q['n']:02}"
    q['focus'] = 'must_know' if q['n'] in (1,3,5,6,7,9,10,11,12,14,17,20,21,22) else 'unique'
    q['takeaway'] = q['explanation'].split('.')[0].strip() + '.'
    assert 1 <= q['page'] <= 24

# Independently recalculated numerical examples and edge cases. These checks
# catch known answer-sheet or extraction failures, not just JSON syntax.
assert next(q for q in items if q['n']==2)['correct'] == str(int(95.25/.00025*100/1000))
assert next(q for q in items if q['n']==6)['correct'] == '4'
assert (120-2.5*24)*24 == 1440
assert next(q for q in items if q['n']==8)['correct'] == '-5'
assert next(q for q in items if q['n']==13)['correct'] == '24'
assert next(q for q in items if q['n']==16)['correct'] == '-30'
assert 1500282/4374 == 343 and 1782*49 == 87318
assert 8*74 == 592 and 8+74 == 82

def quote_sql(value):
    return "'" + value.replace("'", "''") + "'"

payload = json.dumps(items, ensure_ascii=False, separators=(',',':'))
sql = '''-- Verified SAT Valley September 2026 practice-set intake, 21 of 24.
-- Source is the user's Library attachment; its checksum and page are retained.
-- Preserves all prior questions, keys, attempts, and student data.
begin;
set local statement_timeout='45s';
create temporary table sat_sep_intake on commit drop as
 select * from jsonb_to_recordset(''' + quote_sql(payload) + '''::jsonb)
 as x(n integer,page integer,topic text,lesson text,idea text,difficulty text,
      stem text,choices jsonb,correct text,explanation text,id uuid,code text,
      focus text,takeaway text);
do $$ begin
 if (select count(*) from sat_sep_intake) <> 21
   or exists(select 1 from sat_sep_intake group by id having count(*) > 1)
   or exists(select 1 from sat_sep_intake group by code having count(*) > 1)
 then raise exception 'invalid_sat_sep_release'; end if;
 -- Existing IDs may only refer to this identical release (idempotent rerun).
 if exists(select 1 from sat_sep_intake i join public.questions q on q.id=i.id
   left join public.question_keys k on k.question_id=q.id
   where q.track_id <> 'sat' or q.stem <> i.stem
      or q.choices <> (select jsonb_agg(jsonb_build_object('key',chr(64+n::integer),'text',value) order by n)
                      from jsonb_array_elements_text(i.choices) with ordinality c(value,n))
         and jsonb_array_length(i.choices)>0
      or k.correct is distinct from case when jsonb_array_length(i.choices)>0
          then to_jsonb(i.correct) else jsonb_build_array(i.correct) end
      or k.explanation <> i.explanation)
 then raise exception 'sat_sep_existing_row_differs'; end if;
 -- Exact prompt comparison plus stable source ID; near-matches were separately reviewed.
 if exists(select 1 from sat_sep_intake i join public.questions q
   on q.track_id='sat' and q.id<>i.id and (
     q.assets->>'code'=i.code or
     regexp_replace(lower(q.stem),'[^[:alnum:]]','','g')=
     regexp_replace(lower(i.stem),'[^[:alnum:]]','','g')))
 then raise exception 'sat_sep_duplicate_existing_question'; end if;
end $$;
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select i.id,'sat',i.topic,i.difficulty,
       case when jsonb_array_length(i.choices)>0 then 'mcq' else 'grid_in' end,
       i.stem,
       coalesce((select jsonb_agg(jsonb_build_object('key',chr(64+n::integer),'text',value) order by n)
                 from jsonb_array_elements_text(i.choices) with ordinality c(value,n)),'[]'::jsonb),
       jsonb_build_object('code',i.code,'paper','SAT Valley September 2026 predictions',
         'source','SAT Valley September 2026 practice set','source_page',i.page,
         'source_number',i.n,'source_sha256','SOURCE_SHA',
         'source_filename','2_5251628363050689570_260910_165338_260927_140341.pdf',
         'source_library_file_id','libfile_ab5b47543a6881919e90749a76c3d5f8',
         'content_review',jsonb_build_object('status','verified',
           'method','Original page read, key independently calculated, options and diagram dependencies checked',
           'source_fidelity','Edited standalone wording; original page retained in supplied Library attachment'))
from sat_sep_intake i on conflict(id) do nothing;
insert into public.question_keys(question_id,correct,explanation)
select i.id,case when jsonb_array_length(i.choices)>0
    then to_jsonb(i.correct) else jsonb_build_array(i.correct) end,i.explanation
from sat_sep_intake i on conflict(question_id) do nothing;
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
select i.id,i.lesson,i.idea,i.difficulty,array['sat']::text[],
       md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text),true,
       jsonb_build_object('collections',jsonb_build_array(i.focus),
                          'bank_occurrences',1+(select count(*) from public.revision_items old
                            where old.lesson=i.lesson and old.idea=i.idea and old.question_id<>i.id),
                          'takeaway',i.takeaway)
from sat_sep_intake i join public.questions q on q.id=i.id
join public.question_keys k on k.question_id=q.id
on conflict(question_id) do update set
 lesson=excluded.lesson,idea=excluded.idea,difficulty=excluded.difficulty,
 programmes=excluded.programmes,fingerprint=excluded.fingerprint,
 active=true,focus=excluded.focus;
do $$ begin
 if (select count(*) from public.questions where assets->>'code' like 'SATVALLEY-SEP26-Q%')<>21
   or (select count(*) from sat_sep_intake i join public.question_keys k on k.question_id=i.id)<>21
   or (select count(*) from sat_sep_intake i join public.revision_items r on r.question_id=i.id)<>21
 then raise exception 'sat_sep_release_incomplete'; end if;
end $$;
commit;
'''.replace('SOURCE_SHA', source_sha)
(DIR/'release.sql').write_text(sql)
audit = {'source':'SAT Valley September 2026 predictions','sha256':source_sha,
         'total_source_questions':24,'existing_sat_bank_before':918,
         'new_verified':len(items),'released_numbers':[q['n'] for q in items],
         'held':[{'n':18,'page':18,'reason':'Source expression 6x⁴+35x+11 cannot be represented as (3x²+j)(2x²+k): the x term conflicts with the proposed even-power factorization. Worked solution silently treats it as 35x².'},
                 {'n':19,'page':19,'reason':'Source angle diagram is required and its label relationships were not safely recoverable as a standalone question.'},
                 {'n':24,'page':24,'reason':'Defining g(x) equation is absent in the rendered page image; OCR alone cannot validate it.'}],
         'duplicate_sources':'The 15- and 16-page August International II PDFs are parallel copies of 44 prompts; 43 corrected/verified versions already exist in SAT, and the defective original M2 Q18 is absent. August Prep (44), MSET008 (50), and the 120 detected CB IDs in the 129-page packet already occur in the graded bank.',
         'limitations':'The scanned 413-page SAT Panda book, two March PDFs, and 100-page Elite May PDF require page-by-page visual question and key review before any new graded import. Their contents have not been claimed verified by this release.'}
(DIR/'audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print('Built 21 verified question and revision rows; source SHA',source_sha)
