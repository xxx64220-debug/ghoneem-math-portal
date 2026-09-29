"""Build the guarded SAT and EST II Final Revision idea expansion release."""

from collections import Counter
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "content-releases/20260929_est2_sat_revision_ideas"

manifest = json.loads((OUT / "manifest.json").read_text())
fingerprints = json.loads((OUT / "fingerprints.json").read_text())

assert len(manifest) == 80
assert Counter(row["track"] for row in manifest) == {"sat": 40, "est2": 40}
assert len({row["id"] for row in manifest}) == 80
assert len({(row["track"], row["lesson"], row["idea"]) for row in manifest}) == 80
assert set(fingerprints) == {row["id"] for row in manifest}
assert all(len(value) == 32 for value in fingerprints.values())

rows = [{**row, "fingerprint": fingerprints[row["id"]]} for row in manifest]
lesson_counts = Counter((row["track"], row["lesson"]) for row in rows)
expected_by_track = Counter(row["track"] for row in rows)

blob = json.dumps(rows, ensure_ascii=False, separators=(",", ":")).replace("'", "''")
expected_lessons = json.dumps(
    {f"{track}|{lesson}": count for (track, lesson), count in sorted(lesson_counts.items())},
    separators=(",", ":"),
).replace("'", "''")

sql = f"""begin;
lock table public.questions, public.question_keys, public.revision_items, public.audit_log in share row exclusive mode;

create temporary table est2_sat_revision_idea_release on commit drop as
select * from jsonb_to_recordset('{blob}'::jsonb)
 as r(id uuid,track text,lesson text,idea text,fingerprint text);

do $est2_sat_revision_ideas$
declare
 v_rows integer;
 v_expected_lessons constant jsonb := '{expected_lessons}'::jsonb;
begin
 if exists(select 1 from public.audit_log where action='revision.est2_sat_idea_expansion.20260929') then
  raise exception 'SAT and EST II revision idea expansion already applied; do not rerun';
 end if;
 if (select count(*) from public.revision_items)<>2267
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1261
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>416
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>248
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>300
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>288 then
  raise exception 'Revision catalogue changed; re-review before expanding SAT and EST II';
 end if;
 if (select count(*) from est2_sat_revision_idea_release)<>80
    or (select count(*) from est2_sat_revision_idea_release where track='sat')<>40
    or (select count(*) from est2_sat_revision_idea_release where track='est2')<>40
    or (select count(distinct id) from est2_sat_revision_idea_release)<>80
    or (select count(distinct (track,lesson,idea)) from est2_sat_revision_idea_release)<>80 then
  raise exception 'SAT and EST II revision release manifest is incomplete or duplicated';
 end if;
 if (select jsonb_object_agg(track||'|'||lesson,n) from (
       select track,lesson,count(*) n from est2_sat_revision_idea_release group by track,lesson order by track,lesson
     ) x)<>v_expected_lessons then
  raise exception 'SAT and EST II revision release lesson distribution changed';
 end if;
 if exists(
  select 1 from est2_sat_revision_idea_release x
  left join public.questions q on q.id=x.id
  left join public.question_keys k on k.question_id=q.id
  where q.id is null or q.track_id<>x.track or q.topic<>x.lesson
   or x.track not in ('sat','est2')
   or nullif(q.assets->>'verified_release','') is null
   or nullif(q.assets->>'release_hold_reason','') is not null
   or jsonb_typeof(k.correct) not in ('string','array')
   or length(btrim(k.explanation))=0
   or k.explanation ~* '^Source-keyed answer'
   or (q.type='mcq' and (
       jsonb_typeof(k.correct)<>'string'
       or jsonb_array_length(q.choices)<2
       or not exists(select 1 from jsonb_array_elements(q.choices) c where c->>'key'=k.correct#>>'{{}}')
      ))
   or public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)<>x.fingerprint
 ) then raise exception 'Selected SAT or EST II source changed or is no longer eligible'; end if;
 if exists(select 1 from est2_sat_revision_idea_release x join public.revision_items r on r.question_id=x.id) then
  raise exception 'Selected SAT or EST II question is already in Final Revision';
 end if;
 if exists(
  select 1 from est2_sat_revision_idea_release x
  join public.revision_items r on r.lesson=x.lesson and lower(trim(r.idea))=lower(trim(x.idea))
  join public.questions q on q.id=r.question_id and q.track_id=x.track
 ) then raise exception 'Selected SAT or EST II idea already exists in its track and lesson'; end if;
 if exists(
  select 1 from est2_sat_revision_idea_release x
  join public.questions q on q.id=x.id
  join public.questions q2 on md5(lower(regexp_replace(q2.stem,'\\s+',' ','g'))||q2.choices::text)
    =md5(lower(regexp_replace(q.stem,'\\s+',' ','g'))||q.choices::text)
  join public.revision_items r on r.question_id=q2.id
 ) then raise exception 'Selected SAT or EST II content duplicates an existing revision item'; end if;

 insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
 select x.id,x.lesson,x.idea,q.difficulty,array[x.track]::text[],x.fingerprint,true,
  jsonb_build_object(
   'collections',jsonb_build_array('unique'),
   'bank_occurrences',1,
   'takeaway','Key skill: '||x.idea||'.',
   'math_format',case when q.stem like '%\\(%' or q.stem like '%\\[%' or q.stem like '%$%' then 'latex' else 'plain' end,
   'release','20260929-est2-sat-idea-expansion'
  )
 from est2_sat_revision_idea_release x join public.questions q on q.id=x.id;
 get diagnostics v_rows=row_count;
 if v_rows<>80 then raise exception 'SAT and EST II revision insertion count is incorrect'; end if;

 insert into public.audit_log(action,target_type,target_id,meta)
 select 'revision.est2_sat_idea_expansion.item.20260929','question',x.id::text,
  jsonb_build_object('track',x.track,'lesson',x.lesson,'idea',x.idea,'fingerprint',x.fingerprint)
 from est2_sat_revision_idea_release x;
 get diagnostics v_rows=row_count;
 if v_rows<>80 then raise exception 'SAT and EST II revision item audit is incomplete'; end if;

 if (select count(*) from public.revision_items)<>2347
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1301
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>456
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>288
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>300
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>328
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
        where q.track_id='sat' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>1301
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
        where q.track_id='est' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>578
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
        where q.track_id='est2' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>455
    or exists(select 1 from est2_sat_revision_idea_release x join public.revision_items r on r.question_id=x.id
              where not r.active or r.programmes<>array[x.track]::text[])
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590 then
  raise exception 'Post-release SAT and EST II revision verification failed';
 end if;

 insert into public.audit_log(action,target_type,target_id,meta)
 values ('revision.est2_sat_idea_expansion.20260929','release','20260929',
  jsonb_build_object(
   'tracks',jsonb_build_object('sat',40,'est2',40),
   'added_questions',80,'added_ideas',80,
   'catalogue_questions',jsonb_build_object('sat',1301,'est',590,'est2',456),
   'catalogue_ideas',jsonb_build_object('sat',288,'est',300,'est2',328),
   'lessons',v_expected_lessons,
   'classification_only',true,'new_answer_certification',false));
end $est2_sat_revision_ideas$;

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
            "questions": 80,
            "ideas": 80,
            "tracks": dict(sorted(expected_by_track.items())),
            "lessons": {
                track: dict(sorted((lesson, count) for (t, lesson), count in lesson_counts.items() if t == track))
                for track in sorted(expected_by_track)
            },
            "classification_only": True,
            "new_answer_certification": False,
        },
        indent=2,
    )
    + "\n"
)

fixture_blob = json.dumps(rows, ensure_ascii=False, separators=(",", ":")).replace("'", "''")
fixture = f"""-- Disposable fixture for the SAT and EST II revision-idea release.
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

with fixture(track_id,n,ideas,stale) as (
 values ('sat',1261,248,0),('est',590,300,12),('est2',416,288,1)
), q as (
 select md5(track_id||'-dual-revision-fixture-'||g)::uuid id,track_id,g,ideas,stale
 from fixture cross join lateral generate_series(1,n) g
)
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select id,track_id,'Existing '||track_id||' lesson','medium','mcq',track_id||' fixture question '||g,
 '[{{"key":"A","text":"1"}},{{"key":"B","text":"2"}}]'::jsonb,'{{}}'::jsonb from q;

insert into public.question_keys(question_id,correct,explanation)
select id,'"A"'::jsonb,'Fixture explanation.' from public.questions;

with fixture(track_id,n,ideas,stale) as (
 values ('sat',1261,248,0),('est',590,300,12),('est2',416,288,1)
), q as (
 select md5(track_id||'-dual-revision-fixture-'||g)::uuid id,track_id,g,ideas,stale
 from fixture cross join lateral generate_series(1,n) g
)
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
select q.id,'Existing '||q.track_id||' lesson','Existing idea '||(((q.g-1)%q.ideas)+1),
 'medium',array[q.track_id]::text[],
 case when q.g<=q.stale then 'stale'
      else public.revision_question_fingerprint(p.stem,p.choices,p.assets,k.correct,k.explanation) end,
 true,'{{"collections":[],"bank_occurrences":1,"takeaway":"Fixture"}}'::jsonb
from q join public.questions p on p.id=q.id join public.question_keys k on k.question_id=q.id;

with selected as (
 select * from jsonb_to_recordset('{fixture_blob}'::jsonb)
  as r(id uuid,track text,lesson text,idea text,fingerprint text)
)
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select id,track,lesson,'medium','mcq','Selected fixture '||id,
 '[{{"key":"A","text":"1"}},{{"key":"B","text":"2"}}]'::jsonb,
 jsonb_build_object('verified_release','fixture','fixture_fingerprint',fingerprint)
from selected;

insert into public.question_keys(question_id,correct,explanation)
select q.id,'"A"'::jsonb,'Selected fixture explanation.'
from public.questions q left join public.question_keys k on k.question_id=q.id where k.question_id is null;
"""
(ROOT / "tests/est2_sat_revision_ideas_fixture.sql").write_text(fixture)

db_test = """do $$
begin
 if (select count(*) from public.revision_items)<>2347 then raise exception 'revision total'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1301 then raise exception 'SAT total'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590 then raise exception 'EST I changed'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>456 then raise exception 'EST II total'; end if;
 if (select count(*) from public.audit_log where action='revision.est2_sat_idea_expansion.item.20260929')<>80 then raise exception 'item audit'; end if;
 if (select count(*) from public.audit_log where action='revision.est2_sat_idea_expansion.20260929')<>1 then raise exception 'release audit'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id
     where r.focus->>'release'='20260929-est2-sat-idea-expansion' and q.track_id='sat'
       and r.programmes=array['sat']::text[] and r.focus#>'{collections}'='["unique"]'::jsonb)<>40 then raise exception 'SAT release scope'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id
     where r.focus->>'release'='20260929-est2-sat-idea-expansion' and q.track_id='est2'
       and r.programmes=array['est2']::text[] and r.focus#>'{collections}'='["unique"]'::jsonb)<>40 then raise exception 'EST II release scope'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
     where q.track_id='sat' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>1301 then raise exception 'SAT ready total'; end if;
 if (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
     where q.track_id='est2' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>455 then raise exception 'EST II ready total'; end if;
end $$;
select 'PASS: 40 SAT and 40 EST II ideas added; EST I and question content preserved' as result;
"""
(ROOT / "tests/est2_sat_revision_ideas.sql").write_text(db_test)

print("Built guarded SAT + EST II revision release: 80 questions, 80 ideas.")
