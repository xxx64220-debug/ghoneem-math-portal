"""Map previously verified uploaded SAT papers into the revision catalogue.

Only existing, previously reviewed questions with a private key and a full
explanation qualify. This script never inserts a new graded question.
"""
import json
from pathlib import Path

HERE = Path(__file__).parent
GROUPS = {
 'Angles, triangles and similarity': ['Angle bisectors','Triangle angles','Angles and parallel lines','Parallel lines','Cofunction identities'],
 'Area and volume': ['Perimeter','Area','Similar solids','Volume ratios'],
 'Circles': ['Circles','Equations of circles','Arc length','Area of circles','Circle geometry','Sector area'],
 'Exponential models': ['Exponential growth','Exponential models','Exponential decay','Interpreting exponentials'],
 'Functions and graphs': ['Constant functions','Cubic graphs','Evaluating functions','Function transformations','Transformations','Interpreting functions','Odd functions','Linear and exponential'],
 'Linear equations': ['Linear equations','Equations from graphs','Equations of lines','Infinitely many solutions','Unique solutions'],
 'Linear inequalities': ['Compound inequalities'],
 'Linear systems': ['Intersections','Systems with no solution','Tangent systems'],
 'Lines and linear models': ['Linear equations from graphs','Linear models','Interpreting linear models','Linear functions'],
 'Percentages': ['Percent change','Percentages'],
 'Polynomials': ['Distinct roots','Factoring','Factor theorem','Expanding polynomials','Factored forms','Factoring by grouping','Roots and factors','Roots of polynomials','Zeros of polynomials','Distinct zeros','Polynomial graphs','Intermediate value','Remainder theorem','Polynomial division'],
 'Probability': ['Probability','Conditional probability'],
 'Quadratics': ['Discriminant','Quadratic formula','Solving quadratics','Vertex form','Vertex form models','Maximum of a quadratic','Quadratic models'],
 'Rational expressions and equations': ['Rational expressions','Removable discontinuities','Rational equations','Continued fractions'],
 'Ratios, rates and units': ['Ratios','Proportional relationships','Unit conversion'],
 'Rearranging formulas': ['Rearranging formulas'],
 'Right triangles and trigonometry': ['Geometric mean','Right triangle trigonometry','Radians and degrees','Trigonometric identities','Unit circle','Unit circle coordinates','Exact values','Solving trig equations'],
 'Scatterplots and models': ['Line of best fit','Linear models from scatterplots','Reading scatterplots'],
 'Statistical inference': ['Margin of error','Generalizing from samples'],
 'Statistics': ['Standard deviation','Comparing means','Mean','Reading tables']
}
topic_map={}
for lesson,topics in GROUPS.items():
 for topic in topics:
  assert topic not in topic_map, topic
  topic_map[topic]=lesson

# Selected core methods join the default focused collection; the rest remain
# accessible under "All revision" rather than crowding the curated priority.
FOCUSED = {
 'AUGINT2-M2-05':'unique', 'AUGINT2-M2-10':'must_know',
 'AUGINT2-M2-12':'must_know',
 'AUGINT2-M2-21':'unique',
 'AUGPRED-M2-13':'must_know', 'MSET008-25':'unique',
 'MSET008-28':'unique', 'MSET008-49':'must_know'
}

def quote(value):
 return "'"+value.replace("'","''")+"'"

mapping=json.dumps([{'topic':t,'lesson':l} for t,l in sorted(topic_map.items())],ensure_ascii=False)
focus=json.dumps([{'code':c,'collection':v} for c,v in sorted(FOCUSED.items())])
sql='''-- Backfill revision from existing independently verified SAT items.
-- The source questions and private keys are never edited.
begin;
set local statement_timeout='45s';
create temporary table sat_topic_map on commit drop as
 select * from jsonb_to_recordset('''+quote(mapping)+'''::jsonb) as t(topic text,lesson text);
create temporary table sat_focus_map on commit drop as
 select * from jsonb_to_recordset('''+quote(focus)+'''::jsonb) as t(code text,collection text);
create temporary table sat_backfill on commit drop as
 select q.id,q.topic,q.difficulty,q.assets->>'code' code,m.lesson,q.stem,q.choices,q.assets,
        k.correct,k.explanation
 from public.questions q
 join public.question_keys k on k.question_id=q.id
 left join public.revision_items r on r.question_id=q.id
 left join sat_topic_map m on m.topic=q.topic
 where q.track_id='sat'
   and q.assets->>'paper' in ('2026 Aug Int II','August Prediction','MSET008')
   and q.assets#>>'{content_review,status}'='verified'
   and nullif(q.assets->>'release_hold_reason','') is null
   and length(btrim(k.explanation))>=20
   and jsonb_typeof(k.correct) in ('string','array')
   and r.question_id is null;
do $$ begin
 if (select count(*) from sat_backfill)<>114
    or exists(select 1 from sat_backfill where lesson is null)
    or exists(select 1 from sat_focus_map f left join sat_backfill q on q.code=f.code where q.id is null)
 then raise exception 'sat_revision_backfill_source_changed'; end if;
end $$;
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
select q.id,q.lesson,q.topic,q.difficulty,array['sat']::text[],
       md5(jsonb_build_array(q.stem,q.choices,q.assets,q.correct,q.explanation)::text),
       true,jsonb_build_object('collections',case when f.collection is null then '[]'::jsonb
                                                  else jsonb_build_array(f.collection) end,
                               'bank_occurrences',0,
                               'takeaway',case when f.collection is null then ''
                                  else 'Review this source question and its checked worked solution.' end)
from sat_backfill q left join sat_focus_map f on f.code=q.code
on conflict(question_id) do nothing;
do $$ begin
 if (select count(*) from sat_backfill q join public.revision_items r on r.question_id=q.id)<>114
 then raise exception 'sat_revision_backfill_incomplete'; end if;
end $$;
commit;
'''
(HERE/'revision-backfill.sql').write_text(sql)
print('Mapped',len(topic_map),'recorded SAT topics to',len(GROUPS),'revision lessons.')
