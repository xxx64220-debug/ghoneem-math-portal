"""Build a bounded metadata review and four evidence-backed exam substitutions."""
from pathlib import Path
import json,uuid
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'content-releases/20261005_remaining_skill_review'
load=lambda n:json.loads((OUT/(n+'.json')).read_text())
decisions=load('decisions');guards=load('guards')
newid=str(uuid.uuid5(uuid.NAMESPACE_URL,'ghoneem:20261005:inverse-proportion-review'))
guards['mapping']['dc220155-bbb4-ddc2-6f65-aa31fc55dd7a']=newid
(OUT/'guards.json').write_text(json.dumps(guards,indent=2)+'\n')
adapt={'id':newid,'track_id':'est','topic':'Ratios, percentages and unit conversion','difficulty':'medium','type':'mcq','stem':'X and Y are inversely proportional. When x = 4, y = 5. What is y² when x = 3, rounded to two decimal places?','choices':[{'key':k,'text':v} for k,v in zip('ABCD',['44.44','6.67','25.00','9.00'])],'correct':'A','explanation':'Inverse proportion means xy is constant. Here xy = 4 × 5 = 20. At x = 3, y = 20/3, so y² = 400/9 = 44.444… . Rounded to two decimal places, this is 44.44, choice A.','assets':{'source':'Eng Abdelrahman Ghoneem — reviewed instructor adaptation','source_question_id':'GH-REVIEW-20261005-inverse-proportion','content_origin':'instructor_adaptation','source_ids_adapted':['dc220155-bbb4-ddc2-6f65-aa31fc55dd7a'],'curriculum_lesson':'Ratios, percentages and unit conversion','lesson_subtopic':'Inverse proportion and squared values','lesson_taxonomy_version':'20261005','verified_release':'20261005-remaining-skill-review','answer_review_status':'independently_solved'}}
holds={
'02ac14b4-f84e-6e9f-1ab3-1427f41cdef7':'Stored point A(−3,44) and B(1,−2) give slope −11.5, absent from the choices. Preserve the original until source coordinates are verified.',
'92118004-2f60-6326-dab8-e6ad8b7911e7':'The question asks to simplify A(x) but provides no definition of A(x); option powers are OCR-corrupted. Preserve the source until its missing expression is verified.',
'331de3d6-88c5-6cf4-3195-fd9efc2019d6':'The new mean is 910/57 ≈ 15.9649, or 16.0 to one decimal place. No stored choice is correct; 15.9 is not the rounded result.',
'dc220155-bbb4-ddc2-6f65-aa31fc55dd7a':'The requested power is stored as y* and the choices contain OCR annotation fragments. The original exponent must be verified; a separately authored squared-value adaptation is available.'}
changes=[]
byid={d['id']:d for d in decisions}
for g in guards['exams']:
 e=g['exam'];ids=[guards['mapping'].get(q,q) for q in e['question_ids']]
 topics={adapt['topic'] if q==newid else 'Statistics and data analysis' if q=='389099ff-c93c-5290-9688-3fc4ea0f5ffa' else byid[q]['topic'] for q in ids}
 lesson=next(iter(topics)) if len(topics)==1 else 'Mixed skills'
 changes.append({'id':e['id'],'title':'EST I — '+lesson+' — Source practice '+e['id'][:8],'question_ids':ids})
packet={'decisions':decisions,'guards':guards,'adaptation':adapt,'holds':holds,'changes':changes}
(OUT/'packet.json').write_text(json.dumps(packet,indent=2)+'\n')
literal="'"+json.dumps(packet,separators=(',',':')).replace("'","''")+"'::jsonb"
sql="""begin;
lock table public.questions,public.question_keys,public.revision_items,public.exams,public.assignments,public.attempts in share row exclusive mode;
create table portal_private.skill_review_20261005_backup(kind text not null,id uuid not null,payload jsonb not null,after_hash text,primary key(kind,id));
alter table portal_private.skill_review_20261005_backup enable row level security;
revoke all on portal_private.skill_review_20261005_backup from public,anon,authenticated;
grant all on portal_private.skill_review_20261005_backup to service_role;
do $review$
declare data_ jsonb:=%s; x jsonb; q_ public.questions; k_ public.question_keys; e_ public.exams; a_ jsonb; n_ integer;
begin
 -- Refuse stale packets, changed audiences, new attempts or unexpected revision membership.
 for x in select * from jsonb_array_elements(data_->'decisions') loop
  select * into q_ from public.questions where id=(x->>'id')::uuid;
  select * into k_ from public.question_keys where question_id=q_.id;
  if md5(jsonb_build_object('q',to_jsonb(q_),'k',to_jsonb(k_))::text) is distinct from x->>'hash' then raise exception 'Concurrent question change: %%',x->>'id'; end if;
  insert into portal_private.skill_review_20261005_backup values('question',q_.id,jsonb_build_object('q',to_jsonb(q_),'k',to_jsonb(k_)),null);
 end loop;
 if (select count(*) from public.revision_items where question_id in(select (j.value->>'id')::uuid from jsonb_array_elements(data_->'decisions') j(value)))<>jsonb_array_length(data_->'guards'->'revisions') then raise exception 'Concurrent revision membership'; end if;
 for x in select * from jsonb_array_elements(data_->'guards'->'revisions') loop
  if (select md5(to_jsonb(r)::text) from public.revision_items r where question_id=(x->>'id')::uuid) is distinct from x->>'hash' then raise exception 'Concurrent revision change'; end if;
 end loop;
 for x in select * from jsonb_array_elements(data_->'guards'->'exams') loop
  select * into e_ from public.exams where id=(x->'exam'->>'id')::uuid;
  if md5(to_jsonb(e_)::text) is distinct from x->>'hash' then raise exception 'Concurrent exam change'; end if;
  if exists(select 1 from public.attempts where exam_id=e_.id) then raise exception 'Exam now has student history'; end if;
  if (select md5(coalesce(jsonb_agg(to_jsonb(a) order by id),'[]'::jsonb)::text) from public.assignments a where exam_id=e_.id) is distinct from x->>'assignment_hash' then raise exception 'Concurrent assignment change'; end if;
  insert into portal_private.skill_review_20261005_backup values('exam',e_.id,jsonb_build_object('exam',to_jsonb(e_),'assignment_hash',x->>'assignment_hash'),null);
 end loop;
 if (select md5(jsonb_build_object('q',to_jsonb(q),'k',to_jsonb(k))::text) from public.questions q join public.question_keys k on k.question_id=q.id where q.id='389099ff-c93c-5290-9688-3fc4ea0f5ffa') is distinct from data_->'guards'->>'weighted_hash' then raise exception 'Concurrent weighted adaptation change'; end if;
 if exists(select 1 from public.exams e where e.is_published and e.question_ids && array(select key::uuid from jsonb_each_text(data_->'holds')) and e.id not in(select (j.value->>'id')::uuid from jsonb_array_elements(data_->'changes') j(value))) then raise exception 'Unexpected published use of a held question'; end if;
 if exists(select 1 from public.revision_items where active and question_id in(select key::uuid from jsonb_each_text(data_->'holds'))) then raise exception 'Unexpected active revision use'; end if;
 -- Only taxonomy fields change for the 146 records. These fields are excluded from revision fingerprints.
 for x in select * from jsonb_array_elements(data_->'decisions') loop
  update public.questions set topic=x->>'topic',assets=coalesce(assets,'{}'::jsonb)||jsonb_build_object('curriculum_lesson',x->>'topic','lesson_subtopic',x->>'skill','lesson_original_topic',coalesce(assets->>'lesson_original_topic',topic),'lesson_taxonomy_version','20261005') where id=(x->>'id')::uuid;
 end loop;
 for x in select jsonb_build_object('id',key,'reason',value) from jsonb_each_text(data_->'holds') loop
  update public.questions set assets=assets||jsonb_build_object('release_hold_reason',x->>'reason','answer_review_status','blocked_source_verification','replacement_question_id',data_->'guards'->'mapping'->>(x->>'id')) where id=(x->>'id')::uuid;
 end loop;
 a_:=data_->'adaptation';
 insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets) values((a_->>'id')::uuid,a_->>'track_id',a_->>'topic',a_->>'difficulty',a_->>'type',a_->>'stem',a_->'choices',a_->'assets');
 insert into public.question_keys(question_id,correct,explanation) values((a_->>'id')::uuid,a_->'correct',a_->>'explanation');
 insert into portal_private.skill_review_20261005_backup values('adaptation',(a_->>'id')::uuid,a_,null);
 for x in select * from jsonb_array_elements(data_->'changes') loop
  update public.exams set title=x->>'title',question_ids=array(select value::uuid from jsonb_array_elements_text(x->'question_ids')) where id=(x->>'id')::uuid;
  if not (select portal_private.exam_content_ready(question_ids,track_id) from public.exams where id=(x->>'id')::uuid) then raise exception 'Corrected exam is not eligible'; end if;
 end loop;
 if exists(select 1 from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id where r.active and r.fingerprint is distinct from public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)) then raise exception 'Stale active revision fingerprint'; end if;
 update portal_private.skill_review_20261005_backup b set after_hash=case when kind='exam' then (select md5(to_jsonb(e)::text) from public.exams e where e.id=b.id) else (select md5(jsonb_build_object('q',to_jsonb(q),'k',to_jsonb(k))::text) from public.questions q join public.question_keys k on k.question_id=q.id where q.id=b.id) end;
end $review$;
commit;
"""%literal
(OUT/'apply.sql').write_text(sql)
print('Built 146 classifications, 19 canonical lesson corrections, four retained source holds, one authored adaptation and five safely renamed/current exams.')
