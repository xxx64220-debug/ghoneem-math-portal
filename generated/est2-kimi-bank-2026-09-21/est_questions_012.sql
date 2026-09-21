begin;
with imported(id,track_id,topic,difficulty,type,stem,choices,assets,correct,explanation) as (values
('1003f7b0-8a16-5af0-b4d0-8aea0df4ee57'::uuid,'est','"Sequences, Complex Numbers & Advanced Algebra"'::jsonb,'medium','mcq','"The first and second terms of a geometric sequence are a and ab, in that order. What is the 643rd term of the sequence?"'::jsonb,'[{"key":"A","text":"(ab)⁶⁴²"},{"key":"B","text":"(ab)⁶⁴³"},{"key":"C","text":"a⁶⁴²b"},{"key":"D","text":"a⁶⁴³b"},{"key":"E","text":"ab⁶⁴²"}]'::jsonb,'{"source":"Kimi Agent Math PDF Question Bank (4)","source_file":"pt2.md","source_sha256":"dc3f96cb13caae485d8f8df3913a14000c0cee73962cf2be70e8202d99a231b9","source_question_id":"P2-59","import_batch":"est2-kimi-bank-2026-09-21","curriculum_lesson":"Sequences, Complex Numbers & Advanced Algebra"}'::jsonb,'"E"'::jsonb,'"Source-keyed answer from pt2.md (P2-59)."'::jsonb),
('b20ab444-8ed7-5542-aaeb-18a0ba638c83'::uuid,'est','"Plane Geometry, Measurement & Transformations"'::jsonb,'medium','mcq','"Points A, B, and C are three distinct points that lie on the same line. If the length of AB is 19 meters and the length of BC is 13 meters, then what are all the possible lengths, in meters, for AC?"'::jsonb,'[{"key":"F","text":"6 only"},{"key":"G","text":"32 only"},{"key":"H","text":"6 and 32 only"},{"key":"J","text":"Any number less than 32 or greater than 6"},{"key":"K","text":"Any number greater than 32 or less than 6"}]'::jsonb,'{"source":"Kimi Agent Math PDF Question Bank (4)","source_file":"pt2.md","source_sha256":"dc3f96cb13caae485d8f8df3913a14000c0cee73962cf2be70e8202d99a231b9","source_question_id":"P2-60","import_batch":"est2-kimi-bank-2026-09-21","curriculum_lesson":"Plane Geometry, Measurement & Transformations"}'::jsonb,'"H"'::jsonb,'"Source-keyed answer from pt2.md (P2-60)."'::jsonb)
), inserted as (
 insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
 select i.id,i.track_id,i.topic #>> '{}',i.difficulty,i.type,i.stem #>> '{}',i.choices,i.assets
 from imported i
 where not exists (select 1 from public.questions e where e.track_id='est' and lower(regexp_replace(e.stem,'[^a-z0-9]+','','g'))=lower(regexp_replace(i.stem #>> '{}','[^a-z0-9]+','','g')))
 on conflict (id) do update set topic=excluded.topic,difficulty=excluded.difficulty,type=excluded.type,stem=excluded.stem,choices=excluded.choices,assets=excluded.assets
 returning id
)
insert into public.question_keys(question_id,correct,explanation)
select i.id,i.correct,i.explanation #>> '{}' from imported i join public.questions q on q.id=i.id
on conflict (question_id) do update set correct=excluded.correct, explanation=excluded.explanation;
commit;
