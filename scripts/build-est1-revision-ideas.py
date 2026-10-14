"""Build the one-time EST I Final Revision idea expansion release."""

from collections import Counter
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "content-releases/20260929_est1_revision_ideas"

manifest = json.loads((OUT / "manifest.json").read_text())
fingerprints = json.loads((OUT / "fingerprints.json").read_text())

lesson_blocks = [
    ("Angles and polygons", 11),
    ("Area and perimeter", 10),
    ("Logic and sets", 5),
    ("Matrices", 2),
    ("Logarithms and exponentials", 5),
    ("Polynomial division and remainder", 5),
    ("Sequences", 10),
    ("Volume and surface area", 12),
]

assert len(manifest) == 60
assert len({row["id"] for row in manifest}) == 60
assert len({row["idea"] for row in manifest}) == 60
assert set(fingerprints) == {row["id"] for row in manifest}
assert all(len(value) == 32 for value in fingerprints.values())

rows = []
offset = 0
for lesson, count in lesson_blocks:
    for row in manifest[offset : offset + count]:
        rows.append({**row, "lesson": lesson, "fingerprint": fingerprints[row["id"]]})
    offset += count
assert offset == len(manifest)

blob = json.dumps(rows, ensure_ascii=False, separators=(",", ":")).replace("'", "''")
expected_by_lesson = json.dumps(dict(lesson_blocks), separators=(",", ":")).replace("'", "''")

sql = f"""begin;
lock table public.questions, public.question_keys, public.revision_items, public.audit_log in share row exclusive mode;

create temporary table est1_revision_idea_release on commit drop as
select * from jsonb_to_recordset('{blob}'::jsonb)
 as r(id uuid,lesson text,idea text,fingerprint text);

do $est1_revision_ideas$
declare
 v_rows integer;
 v_expected_by_lesson constant jsonb := '{expected_by_lesson}'::jsonb;
begin
 if exists(select 1 from public.audit_log where action='revision.est1_idea_expansion.20260929') then
  raise exception 'EST I revision idea expansion already applied; do not rerun';
 end if;
 if (select count(*) from public.revision_items)<>2207
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1261
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>530
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>416
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>240 then
  raise exception 'Revision catalogue changed; re-review before expanding EST I';
 end if;
 if (select count(*) from est1_revision_idea_release)<>60
    or (select count(distinct id) from est1_revision_idea_release)<>60
    or (select count(distinct (lesson,idea)) from est1_revision_idea_release)<>60 then
  raise exception 'EST I revision release manifest is incomplete or duplicated';
 end if;
 if (select jsonb_object_agg(lesson,n) from (
       select lesson,count(*) n from est1_revision_idea_release group by lesson order by lesson
     ) x)<>v_expected_by_lesson then
  raise exception 'EST I revision release lesson distribution changed';
 end if;
 if exists(
  select 1 from est1_revision_idea_release x
  left join public.questions q on q.id=x.id
  left join public.question_keys k on k.question_id=q.id
  where q.id is null or q.track_id<>'est' or q.topic<>x.lesson
   or nullif(q.assets->>'verified_release','') is null
   or nullif(q.assets->>'release_hold_reason','') is not null
   or jsonb_typeof(k.correct) not in ('string','array')
   or length(btrim(k.explanation))=0
   or public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)<>x.fingerprint
 ) then raise exception 'Selected EST I source changed or is no longer eligible'; end if;
 if exists(select 1 from est1_revision_idea_release x join public.revision_items r on r.question_id=x.id) then
  raise exception 'Selected EST I question is already in Final Revision';
 end if;
 if exists(
  select 1 from est1_revision_idea_release x
  join public.revision_items r on r.lesson=x.lesson and r.idea=x.idea
 ) then raise exception 'Selected EST I idea already exists in its lesson'; end if;
 if exists(
  select 1 from est1_revision_idea_release x
  join public.questions q on q.id=x.id
  join public.questions q2 on md5(lower(regexp_replace(q2.stem,'\\s+',' ','g'))||q2.choices::text)
    =md5(lower(regexp_replace(q.stem,'\\s+',' ','g'))||q.choices::text)
  join public.revision_items r on r.question_id=q2.id
 ) then raise exception 'Selected EST I content duplicates an existing revision item'; end if;

 insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
 select x.id,x.lesson,x.idea,q.difficulty,array['est']::text[],x.fingerprint,true,
  jsonb_build_object(
   'collections',jsonb_build_array('unique'),
   'bank_occurrences',1,
   'takeaway','Key skill: '||x.idea||'.',
   'math_format',case when q.stem like '%\\(%' or q.stem like '%\\[%' then 'latex' else 'plain' end,
   'release','20260929-est1-idea-expansion'
  )
 from est1_revision_idea_release x join public.questions q on q.id=x.id;
 get diagnostics v_rows=row_count;
 if v_rows<>60 then raise exception 'EST I revision insertion count is incorrect'; end if;

 insert into public.audit_log(action,target_type,target_id,meta)
 select 'revision.est1_idea_expansion.item.20260929','question',x.id::text,
  jsonb_build_object('track','est','lesson',x.lesson,'idea',x.idea,'fingerprint',x.fingerprint)
 from est1_revision_idea_release x;
 get diagnostics v_rows=row_count;
 if v_rows<>60 then raise exception 'EST I revision item audit is incomplete'; end if;

 if (select count(*) from public.revision_items)<>2267
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>300
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
        where q.track_id='est' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>578
    or exists(select 1 from est1_revision_idea_release x join public.revision_items r on r.question_id=x.id where not r.active or r.programmes<>array['est']::text[])
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1261
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>416 then
  raise exception 'Post-release EST I revision verification failed';
 end if;

 insert into public.audit_log(action,target_type,target_id,meta)
 values ('revision.est1_idea_expansion.20260929','release','20260929',
  jsonb_build_object('track','est','added_questions',60,'added_ideas',60,
   'catalogue_questions',590,'catalogue_ideas',300,'lessons',v_expected_by_lesson,
   'classification_only',true,'new_answer_certification',false));
end $est1_revision_ideas$;

commit;

select q.track_id,count(*) total,
 count(*) filter(where r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)) ready,
 count(distinct (r.lesson,r.idea)) ideas
from public.revision_items r
join public.questions q on q.id=r.question_id
join public.question_keys k on k.question_id=q.id
group by q.track_id order by q.track_id;
"""

(OUT / "apply.sql").write_text(sql)
(OUT / "audit.json").write_text(
    json.dumps(
        {
            "questions": len(rows),
            "ideas": len({(row["lesson"], row["idea"]) for row in rows}),
            "lessons": dict(Counter(row["lesson"] for row in rows)),
            "classification_only": True,
            "new_answer_certification": False,
        },
        indent=2,
    )
    + "\n"
)

selected_blob = json.dumps(rows, ensure_ascii=False, separators=(",", ":")).replace("'", "''")
fixture = f"""-- Disposable fixture for content-releases/20260929_est1_revision_ideas/apply.sql.
insert into public.tracks(id,name) values ('sat','SAT'),('est','EST I'),('est2','EST II') on conflict do nothing;
alter table public.revision_items add column if not exists focus jsonb not null default '{{"collections":[],"bank_occurrences":0,"takeaway":""}}';
alter table public.revision_items drop constraint if exists revision_items_programmes_check;
alter table public.revision_items add constraint revision_items_programmes_check
 check(cardinality(programmes)>0 and programmes <@ array['sat','est','est2']::text[]);

create or replace function public.revision_question_fingerprint(
 p_stem text,p_choices jsonb,p_assets jsonb,p_correct jsonb,p_explanation text
) returns text language sql immutable security invoker set search_path=public,pg_temp as $$
 select coalesce(p_assets->>'fixture_fingerprint',md5(jsonb_build_array(
  p_stem,p_choices,coalesce(p_assets,'{{}}'::jsonb)-'curriculum_lesson'-'lesson_subtopic'-'lesson_original_topic'-'lesson_taxonomy_version',
  p_correct,p_explanation
 )::text))
$$;

with fixture(track_id,n) as (values ('sat',1261),('est',530),('est2',416)), q as (
 select md5(track_id||'-revision-fixture-'||g)::uuid id,track_id,g
 from fixture cross join lateral generate_series(1,n) g
)
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select id,track_id,case when track_id='est' then 'Existing EST lesson' else 'Existing lesson' end,
 'medium','mcq',track_id||' fixture question '||g,'[{{"key":"A","text":"1"}}]'::jsonb,'{{}}'::jsonb from q;

insert into public.question_keys(question_id,correct,explanation)
select id,'"A"'::jsonb,'Fixture explanation.' from public.questions;

with fixture(track_id,n) as (values ('sat',1261),('est',530),('est2',416)), q as (
 select md5(track_id||'-revision-fixture-'||g)::uuid id,track_id,g
 from fixture cross join lateral generate_series(1,n) g
)
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
select q.id,case when q.track_id='est' then 'Existing EST lesson' else 'Existing lesson' end,
 case when q.track_id='est' then 'Existing idea '||(((q.g-1)%240)+1) else 'Existing idea '||q.g end,
 'medium',array[q.track_id]::text[],
 case when (q.track_id='est' and q.g<=12) or (q.track_id='est2' and q.g=1) then 'stale'
      else public.revision_question_fingerprint(p.stem,p.choices,p.assets,k.correct,k.explanation) end,
 true,'{{"collections":[],"bank_occurrences":1,"takeaway":"Fixture"}}'::jsonb
from q join public.questions p on p.id=q.id join public.question_keys k on k.question_id=q.id;

with selected as (
 select * from jsonb_to_recordset('{selected_blob}'::jsonb)
  as r(id uuid,lesson text,idea text,fingerprint text)
)
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select id,'est',lesson,'medium','mcq','Selected fixture '||id,
 '[{{"key":"A","text":"1"}}]'::jsonb,jsonb_build_object('verified_release','fixture','fixture_fingerprint',fingerprint)
from selected;

insert into public.question_keys(question_id,correct,explanation)
select q.id,'"A"'::jsonb,'Selected fixture explanation.'
from public.questions q left join public.question_keys k on k.question_id=q.id where k.question_id is null;
"""
(ROOT / "tests/est1_revision_ideas_fixture.sql").write_text(fixture)

db_test = """do $$
begin
 if (select count(*) from public.revision_items)<>2267 then raise exception 'revision total'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590 then raise exception 'EST I total'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>416 then raise exception 'EST II changed'; end if;
 if (select count(*) from public.audit_log where action='revision.est1_idea_expansion.item.20260929')<>60 then raise exception 'item audit'; end if;
 if (select count(*) from public.audit_log where action='revision.est1_idea_expansion.20260929')<>1 then raise exception 'release audit'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est' and r.programmes=array['est']::text[] and r.focus#>'{collections}'='["unique"]'::jsonb)<>60 then raise exception 'EST I release scope'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where q.track_id='est' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>578 then raise exception 'ready total'; end if;
 if (select count(*) from public.questions)<>2267 or (select count(*) from public.question_keys)<>2267 then raise exception 'question content changed'; end if;
end $$;
select 'PASS: 60 EST I ideas added; EST II and question content preserved' as result;
"""
(ROOT / "tests/est1_revision_ideas.sql").write_text(db_test)
print("Built guarded EST I revision release: 60 questions, 60 ideas, 8 lessons.")
