"""Archive unusable originals; reuse verified counterparts; create one explicit adaptation."""
import json,uuid,base64,hashlib,re
from pathlib import Path
D=Path(__file__).parent;ROOT=D.parents[1]
b=json.loads((D/'before.json').read_text());uid=lambda s:str(uuid.uuid5(uuid.NAMESPACE_URL,'ghoneem:est-cleanup:20261015:'+s))
old=b['original'];image=(ROOT/'assets/question-bank/MA-30.png').read_bytes()
assert hashlib.sha256(image).hexdigest()==old['assets']['image_sha256']
new={
'id':uid('MA-30'),'track_id':'est2','topic':old['topic'],'difficulty':old['difficulty'],'type':'mcq',
'stem':'Instructor-reviewed practice. The graph shows an increasing exponential function f with f(−2) = 16. Which choice describes the complete set of real x for which f(x) > 16?',
'choices':[{'key':'F','text':'x > −2'},{'key':'G','text':'x > 0'},{'key':'H','text':'−2 < x < 2'},{'key':'J','text':'x < −2'}],
'correct':'F','explanation':'Because f is strictly increasing and f(−2) = 16, values to the right of x = −2 give f(x) > 16; values to the left give f(x) < 16. At x = −2 there is equality, so the endpoint is excluded. The complete solution is x > −2 (F). G and H omit valid values; J is on the wrong side. The original graph is retained. J is an instructor-authored distractor, not a claim about the unavailable original choice typography.',
'assets':{'source':'Eng. Abdelrahman Ghoneem — instructor-reviewed practice','source_code':'GH-EST2-EXP-GRAPH-20261015','source_question_id':'GH-EST2-EXP-GRAPH-20261015','content_origin':'instructor_adaptation','adapted_from_question_id':old['id'],'adaptation_reason':'Source markdown has an incomplete infinity-sign distractor. Complete, explicit practice choices are authored separately; the original remains archived.','source_archive_library_id':'libfile_bf57f23ca344819199a3207a9fbcf774','original_source_file':'moh.md','original_source_sha256':old['assets']['source_sha256'],'original_image_sha256':old['assets']['image_sha256'],'original_image_url':old['assets']['image'],'figure':['data:image/png;base64,'+base64.b64encode(image).decode()],'figure_caption':'Authentic supplied MA-30 graph; practice wording and choices are instructor-authored.','figure_required':True,'lesson_subtopic':'Exponential inequalities from a graph','curriculum_lesson':old['topic'],'answer_review_status':'independently_solved','verified_release':'20261015_est_cleanup'}
}
canonical={q['id']:q for q in b['canon']}
archive=[]
for q in b['archive']:
 r=q['replacement_id'] if q['replacement_ready'] else None
 if not r:
  m=re.search(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}',q['assets']['release_hold_reason'])
  assert m,q['id'];r=m[0];assert canonical[r]['ready'] and canonical[r]['track_id']==q['track_id']
 archive.append({'id':q['id'],'track_id':q['track_id'],'hash':q['hash'],'replacement_id':r,'disposition':'archived_duplicate' if 'duplicate' in q['assets']['release_hold_reason'].lower() else 'archived_source_defect','reason':q['assets']['release_hold_reason']})
archive.append({'id':old['id'],'track_id':'est2','hash':old['hash'],'replacement_id':new['id'],'disposition':'archived_source_defect','reason':'The source distractor J reads ∞ < x < −2; complete original choice evidence is unavailable. A separately labeled instructor practice version supplies complete choices.'})
exams=[]
for e in b['exams']:
 if 'Historical version' in e['title']:continue
 ids=[new['id'] if q==old['id'] else q for q in e['question_ids']]
 assert len(ids)==len(set(ids))
 ex={k:v for k,v in e.items() if k not in ('attempts','assignments','hash')}
 title=e['title'].replace('Math Level 2','Math')+' — Reviewed 15 Oct 2026'
 hist=e['attempts']>0
 exams.append({'before':ex,'hash':e['hash'],'new_id':uid('exam:'+e['id']) if hist else e['id'],'question_ids':ids,'title':title,'has_history':hist,'attempts':e['attempts'],'assignment_hash':next(x['assignment_hash'] for x in b['exam_guards'] if x['id']==e['id'])})
sources=[]
for s in b['sources']:
 removed= s['source_code']!='PSD 132'
 sources.append({**s,'status':'excluded' if removed else 'needs_source_repair','note':s['review_note']+'\nDisposition 2026-10-15: '+('Intentionally removed by instructor curriculum request; retain source evidence only, not available practice.' if removed else 'Original source remains archived; use the separately verified explicit-rounding practice adaptation. A ready archive label must not override live eligibility.')})
assert len(archive)==172 and len(exams)==8 and sum(x['has_history'] for x in exams)==1 and len(sources)==15
guards={q['id']:q for q in b['members']+json.loads((D/'replacement-guards.json').read_text())}
packet={'archive':archive,'question':new,'exams':exams,'sources':sources,'members':list(guards.values())}
(D/'packet.json').write_text(json.dumps(packet,ensure_ascii=False,indent=2)+'\n')
(D/'apply.sql').write_text((D/'apply.template.sql').read_text().replace('__PACKET__',"'"+json.dumps(packet,ensure_ascii=False).replace("'","''")+"'::jsonb"))
(D/'rollback.sql').write_text((D/'rollback.template.sql').read_text().replace('__PACKET__',"'"+json.dumps(packet,ensure_ascii=False).replace("'","''")+"'::jsonb"))
print('Built: 172 archives (159 EST I, 13 EST II), 172 usable replacement links, 1 explicit adaptation, 8 assessment repairs (7 unused, 1 new version), 15 archive-status corrections.')
