"""Build the reviewed EST expansion from committed editorial labels. Does not write to a database."""
from pathlib import Path
import json,collections,re,ast
root=Path(__file__).resolve().parents[1];out=root/'content/est-revision-2026-09-28'
def load(p):return json.loads(p.read_text())
def save(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
rows=load(out/'reviewed-labels.json');ex=load(out/'exclusions.json')
id='b74a7035-6a5d-5e36-b526-1ea412b9a92e'
rows=[q for q in rows if q['id']!=id];ex[id]={'reference':'HOA 074','reason':'Exact problem duplicate of AAF 009; counted only once.'};save(out/'exclusions.json',ex)
old={q['id']:q for q in load(out.parent/'final-revision-2026-09-27/manifest.json')};focus={q['id']:q for q in load(out.parent/'final-revision-2026-09-27/focus.json')}
fixes=[{'id':'234fb49d-42d5-58b8-a248-7116d39e0b91','before':'5190012b4128a242bf297c9f76b00b9c','after':'95170157f3cd7192e97c586264f4e97e','explanation':'From −1/(2x − 1) = √3, we get 2x − 1 = −1/√3. Multiplying by 3 gives 6x = 3 − 3/√3 = 3 − √3, which is choice A.'},{'id':'0cbfc70e-50ea-5fdc-9a2d-f8119fc9b5cb','before':'6177a61bcdf6ce8902c645f05d8955ca','after':'490dea3ce043e01e036099a36fe849e7','stem':'Which of the inequalities below represents the shaded region in the figure?'}]
save(out/'source-fixes.json',fixes)
# Reuse editorial foundations, extending named essential skills to the new topics.
tree=ast.parse((root/'scripts/build-revision-focus.py').read_text());essential=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='essential' for t in n.targets))
for lesson,patterns in {'Coordinate geometry':['Midpoint','Distance formula','Fourth vertex'], 'Logarithms':['Solving exponential equations'], 'Sequences':['Sum of consecutive','Consecutive integers'], 'Counting methods':['Permutations without replacement','Permutations with repeated letters'], 'Statistical inference':['Population estimates'], 'Complex numbers':['Complex arithmetic'], 'Rational expressions and equations':['Vertical and horizontal asymptotes'], 'Statistics':['Median from frequency','Mean from graphs','Estimated mean'], 'Rearranging formulas':['Isolating a variable'], 'Quadratics':['Discriminant','Axis of symmetry from roots']}.items():essential.setdefault(lesson,[]).extend(patterns)
counts=collections.Counter((q['lesson'],q['idea']) for q in rows)
for q in rows:
 if q['id'] in old:q['programmes']=old[q['id']]['programmes']
 f=next((f for f in fixes if f['id']==q['id']),None)
 if f:q['original_fingerprint']=f['before'];q['fingerprint']=f['after']
 tags=[]
 if any(re.search(p,q['idea']) for p in essential.get(q['lesson'],[])):tags.append('must_know')
 if counts[q['lesson'],q['idea']]>=4:tags.append('repeated')
 prev=focus.get(q['id'],{})
 if q['unique'] or 'unique' in prev.get('collections',[]):tags.append('unique')
 q['focus']={'collections':tags,'bank_occurrences':counts[q['lesson'],q['idea']],'takeaway':prev.get('takeaway') or 'Key skill: '+q['idea']+'.','math_format':q['math_format'],'source_label':q['source_document'],'source_reference':q['source_reference']}
rows.sort(key=lambda q:q['id']);save(out/'manifest.json',rows)
lessons=[]
for l in sorted({q['lesson'] for q in rows}):
 qs=[q for q in rows if q['lesson']==l];lessons.append({'lesson':l,'questions':len(qs),'ideas':len({q['idea'] for q in qs}),'difficulty':dict(collections.Counter(q['difficulty'] for q in qs))})
audit={'questions':len(rows),'previous_est_questions':254,'added':len(rows)-254,'ideas':len(counts),'lessons':lessons,'sources':dict(collections.Counter(q['source_document'] for q in rows)),'difficulty':dict(collections.Counter(q['difficulty'] for q in rows)),'collections':{c:sum(c in q['focus']['collections'] for q in rows) for c in ['must_know','repeated','unique']},'priority':sum(bool(q['focus']['collections']) for q in rows),'excluded':len(ex),'sparse_lessons':[l for l in lessons if l['questions']<5 or l['ideas']<3]};save(out/'audit.json',audit)
# Guard against concurrent source edits. Source fixes and metadata publish atomically.
j=lambda x:json.dumps(x,ensure_ascii=False).replace("'","''")
sql="begin;\ncreate temp table est_revision_release on commit drop as select * from jsonb_to_recordset('"+j(rows)+"'::jsonb) as r(id uuid,lesson text,idea text,difficulty text,programmes text[],fingerprint text,original_fingerprint text,focus jsonb);\n"
sql+="""do $$ begin
if exists(select 1 from est_revision_release r left join public.questions q on q.id=r.id left join public.question_keys k on k.question_id=q.id where q.id is null or q.track_id<>'est' or nullif(q.assets->>'release_hold_reason','') is not null or coalesce(r.original_fingerprint,r.fingerprint) is distinct from md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text) or jsonb_typeof(k.correct) not in ('string','array') or length(btrim(k.explanation))=0) then raise exception 'est_revision_source_changed'; end if;
end $$;
"""
for f in fixes:
 if 'stem' in f:sql+="update public.questions set stem='"+f['stem'].replace("'","''")+"' where id='"+f['id']+"';\n"
 else:sql+="update public.question_keys set explanation='"+f['explanation'].replace("'","''")+"' where question_id='"+f['id']+"';\n"
sql+="""do $$ begin
if exists(select 1 from est_revision_release r join public.questions q on q.id=r.id join public.question_keys k on k.question_id=q.id where r.fingerprint<>md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text)) then raise exception 'est_revision_postfix_mismatch'; end if;
end $$;
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,focus)
select id,lesson,idea,difficulty,programmes,fingerprint,focus from est_revision_release
on conflict(question_id) do update set lesson=excluded.lesson,idea=excluded.idea,difficulty=excluded.difficulty,programmes=excluded.programmes,fingerprint=excluded.fingerprint,focus=excluded.focus,active=true;
commit;
"""
(out/'release.sql').write_text(sql)
# Guard new and legacy revision sessions on the server.
s=(root/'content-releases/2026-09-27-revision-focus-schema.sql').read_text()
s=s.replace(" into qs from jsonb_array_elements(s.snapshot) with ordinality e(q,n);", " into qs from jsonb_array_elements(s.snapshot) with ordinality e(q,n) where p_track<>'est' or q->>'source'='est';\n if qs is null then raise exception 'revision_session_not_found'; end if;")
s=s.replace("'completed',s.completed_at is not null", "'completed',not exists(select 1 from jsonb_array_elements(qs) q where q->'feedback'='null'::jsonb)")
s=s.replace(" if p_action='state'", " if p_track='est' then scope_:='est';source_:='est';end if;\n if p_action='state'")
s=s.replace("where q->>'id'=qid;", "where q->>'id'=qid and (p_track<>'est' or q->>'source'='est');")
s=s.replace("(select count(*) from jsonb_object_keys(s.answers))=jsonb_array_length(s.snapshot)","not exists(select 1 from jsonb_array_elements(s.snapshot) q where (p_track<>'est' or q->>'source'='est') and not s.answers ? (q->>'id'))")
s=s.replace("where r.active and", "where r.active and (p_track<>'est' or q.track_id='est') and jsonb_typeof(k.correct) in ('string','array') and")
s=s.replace("and completed_at is null order by created_at", "and completed_at is null and exists(select 1 from jsonb_array_elements(snapshot) q where (p_track<>'est' or q->>'source'='est') and not answers ? (q->>'id')) order by created_at")
s=s.replace("and completed_at is not null;", "and not exists(select 1 from jsonb_array_elements(snapshot) q where (p_track<>'est' or q->>'source'='est') and not answers ? (q->>'id'));")
(root/'content-releases/2026-09-28-est-revision-schema.sql').write_text(s)
print(json.dumps(audit,indent=2))
