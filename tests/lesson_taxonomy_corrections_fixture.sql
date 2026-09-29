insert into public.audit_log(action,target_type,target_id,meta)
values ('question.lesson_taxonomy.20260929','release','fixture','{}');

with x(id,track_id,old_lesson) as (values
 ('12039edd-0ed2-4caf-847b-1f8b79633f6d'::uuid,'sat','Statistics and data analysis'),
 ('5f8bdfe2-cb1a-409e-b86a-1f4c6fd5c15a'::uuid,'sat','Triangles and similarity'),
 ('98b55bd5-6947-41a1-8d69-5f942958b2f4'::uuid,'sat','Triangles and similarity'),
 ('9d7495b1-b96a-431f-b79d-6d76a5a220a3'::uuid,'sat','Triangles and similarity'),
 ('a443a041-cac2-43fb-89c5-19e7039d8f56'::uuid,'sat','Triangles and similarity'),
 ('bffede21-7eb9-449a-9ff9-c8fff021ae10'::uuid,'sat','Triangles and similarity'),
 ('ca2b3234-ea0e-4328-9cc7-ac8d9e9e32cf'::uuid,'sat','Triangles and similarity'),
 ('ff6f428b-3bba-4c63-aa81-05c6afba57a6'::uuid,'sat','Triangles and similarity'),
 ('086ff1ee-3885-4c3c-ab7d-cf4685e399e4'::uuid,'sat','Quadratics and polynomials'),
 ('1acd1ade-28f1-4ee4-8c84-855f427629e2'::uuid,'sat','Quadratics and polynomials'),
 ('61de8416-5bda-4d8c-aaf3-14f52feb16ff'::uuid,'sat','Quadratics and polynomials'),
 ('e5897815-836d-4eb7-8da2-1d7873e5f913'::uuid,'sat','Quadratics and polynomials'),
 ('da7220f9-fad9-570f-a8df-5500fe4f5823'::uuid,'est','Quadratics and polynomials')
)
insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
select id,track_id,old_lesson,'medium','mcq','taxonomy fixture '||id::text,
 '[{"key":"A","text":"fixture"}]'::jsonb,
 jsonb_build_object('image','fixture.png','table',jsonb_build_array(jsonb_build_array('x','y')),
  'lesson_subtopic','fixture detail','lesson_original_topic','fixture original',
  'curriculum_lesson',old_lesson,'lesson_taxonomy_version','20260929')
from x;

insert into public.question_keys(question_id,correct,explanation)
select id,to_jsonb('A'::text),'fixture explanation' from public.questions where stem like 'taxonomy fixture %';

insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint)
select id,topic,'fixture detail','medium',array[track_id],md5(id::text)
from public.questions where stem like 'taxonomy fixture %';

insert into public.exams(id,track_id,title,duration_seconds,question_ids,shuffle,review_policy,max_attempts,is_published)
select '11111111-1111-4111-8111-111111111111','sat','Taxonomy preservation fixture',900,array_agg(id order by id),false,'full_review',1,false
from public.questions where stem like 'taxonomy fixture %';
