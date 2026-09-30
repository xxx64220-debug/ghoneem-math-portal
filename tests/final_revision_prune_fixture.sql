create table tracks(id text primary key,name text not null);
insert into tracks values ('sat','SAT'),('est','EST I'),('est2','EST II');

create table questions(
 id uuid primary key,track_id text not null references tracks(id),topic text not null,
 difficulty text not null,type text not null,stem text not null,choices jsonb not null,assets jsonb not null
);
create table question_keys(
 question_id uuid primary key references questions(id),correct jsonb not null,explanation text not null
);
create table revision_items(
 question_id uuid primary key references questions(id),lesson text not null,idea text not null,
 difficulty text not null,programmes text[] not null,fingerprint text not null,
 active boolean not null default true,
 focus jsonb not null default '{"collections":[],"bank_occurrences":0,"takeaway":""}'::jsonb
);
create table audit_log(
 id bigserial primary key,action text not null,target_type text,target_id text,
 meta jsonb not null default '{}',at timestamptz not null default now()
);

create table exams(id uuid primary key,question_ids uuid[] not null);
create table revision_sessions(id uuid primary key,snapshot jsonb not null,answers jsonb not null);
create table attempts(id uuid primary key,score integer,status text);
create table attempt_answers(attempt_id uuid,question_id uuid,answer jsonb,primary key(attempt_id,question_id));
create table attempt_results(attempt_id uuid,question_id uuid,is_correct boolean,primary key(attempt_id,question_id));
create table daily_quizzes(track_id text,day date,question_ids uuid[],primary key(track_id,day));
create table daily_progress(user_id uuid,track_id text,day date,quiz_score integer,points integer,primary key(user_id,track_id,day));
create table practice_notebook(user_id uuid,question_id uuid,tries integer,correct_streak integer,primary key(user_id,question_id));

create function revision_question_fingerprint(
 p_stem text,p_choices jsonb,p_assets jsonb,p_correct jsonb,p_explanation text
) returns text language sql immutable as $$
 select md5(
  coalesce(p_stem,'')||'|'||coalesce(p_choices::text,'')||'|'||
  coalesce(p_assets::text,'')||'|'||coalesce(p_correct::text,'')||'|'||
  coalesce(p_explanation,'')
 )
$$;

create temporary table prune_spec(
 track text,total integer,ready integer,ideas integer,ready_ideas integer,lessons integer,
 groups integer,keep integer,easy integer,medium integer,hard integer,
 group_easy integer,group_medium integer,group_hard integer
);
insert into prune_spec values
 ('sat',1341,1341,326,326,20,350,456,84,294,78,65,214,71),
 ('est',590,578,300,298,22,333,438,111,248,79,81,184,68),
 ('est2',496,495,368,367,24,407,450,193,148,109,162,144,101);

create temporary table ready_groups as
select s.*,g as group_no,
 ((g-1)%s.ready_ideas)+1 as idea_no,
 case when g<=s.group_easy then 'easy'
      when g<=s.group_easy+s.group_medium then 'medium'
      else 'hard' end as difficulty,
 case when g<=s.group_easy then g<=s.easy-s.group_easy
      when g<=s.group_easy+s.group_medium
       then g-s.group_easy<=s.medium-s.group_medium
      else g-s.group_easy-s.group_medium<=s.hard-s.group_hard end as second_slot
from prune_spec s cross join lateral generate_series(1,s.groups) g;

create temporary table multi_groups as
select track,group_no,row_number() over(partition by track order by group_no) as multi_no
from ready_groups where second_slot;

create temporary table ready_rows as
select *,1 as duplicate_no from ready_groups
union all
select g.*,2 as duplicate_no
from ready_groups g join multi_groups m using(track,group_no)
union all
select g.*,3+((e-1)/(s.keep-s.groups)) as duplicate_no
from prune_spec s
cross join lateral generate_series(1,s.ready-s.keep) e
join multi_groups m on m.track=s.track and m.multi_no=((e-1)%(s.keep-s.groups))+1
join ready_groups g on g.track=m.track and g.group_no=m.group_no;

create temporary table fixture_rows as
select
 md5(track||'-ready-'||group_no||'-'||duplicate_no)::uuid as id,
 track,group_no,idea_no,difficulty,duplicate_no,true as ready
from ready_rows
union all
select
 md5(s.track||'-stale-'||g)::uuid,
 s.track,s.keep+g,
 case when s.track='est' then s.ideas-((g-1)%2) else s.ideas end,
 'medium',1,false
from prune_spec s
cross join lateral generate_series(1,s.total-s.ready) g;

insert into questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select
 f.id,f.track,
 case when not f.ready and f.track='est' and f.idea_no=300 then 'Inequalities and absolute value'
      when not f.ready then 'Quadratics and polynomials'
      else 'Lesson '||f.track||' '||(((f.idea_no-1)%s.lessons)+1) end,
 f.difficulty,'mcq','Fixture question '||f.id,
 '[{"key":"A","text":"1"},{"key":"B","text":"2"}]'::jsonb,
 jsonb_build_object('verified_release','fixture','lesson_subtopic','Skill '||f.idea_no)
from fixture_rows f join prune_spec s on s.track=f.track;

insert into question_keys(question_id,correct,explanation)
select id,'"A"'::jsonb,'Fixture worked explanation.' from questions;

insert into revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
select
 f.id,q.topic,case when not f.ready and f.track='est' and f.idea_no=300 then 'Optimising a linear expression'
      when not f.ready and f.track='est' then 'Reading a parabola graph'
      when not f.ready then 'Common polynomial factor'
      else 'Idea '||f.idea_no end,
 case when not f.ready and (f.track='est2' or f.idea_no=300) then 'hard' else f.difficulty end,array[f.track]::text[],
 case when f.ready then revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)
      else 'stale-fingerprint' end,
 true,
 jsonb_build_object(
  'collections',
  case when not f.ready and (f.track='est2' or f.idea_no=300) then '["unique"]'::jsonb
       when f.duplicate_no>=3 then '["must_know","unique"]'::jsonb
       when f.duplicate_no=2 then '["must_know"]'::jsonb
       else '[]'::jsonb end,
  'bank_occurrences',1,
  'takeaway',case when f.duplicate_no>=3 then 'Specific reviewed method.' else 'Key skill: fixture.' end
 )
from fixture_rows f
join questions q on q.id=f.id
join question_keys k on k.question_id=f.id;

insert into exams values (
 '10000000-0000-0000-0000-000000000001',
 array[(select id from questions order by id limit 1)]
);
insert into revision_sessions values (
 '20000000-0000-0000-0000-000000000001',
 '[{"question_id":"fixture","stem":"Frozen"}]'::jsonb,
 '{"fixture":"A"}'::jsonb
);
insert into attempts values ('30000000-0000-0000-0000-000000000001',1,'graded');
insert into attempt_answers select
 '30000000-0000-0000-0000-000000000001',id,'"A"'::jsonb from questions order by id limit 1;
insert into attempt_results select
 '30000000-0000-0000-0000-000000000001',id,true from questions order by id limit 1;
insert into daily_quizzes values ('sat','2026-09-30',array[(select id from questions order by id limit 1)]);
insert into daily_progress values (
 '40000000-0000-0000-0000-000000000001','sat','2026-09-30',1,5
);
insert into practice_notebook select
 '40000000-0000-0000-0000-000000000001',id,1,1 from questions order by id limit 1;
