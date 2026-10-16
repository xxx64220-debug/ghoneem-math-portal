"""Independent adaptation check and disposition consistency (not a full-bank certificate)."""
import json,math,base64,hashlib
from pathlib import Path
D=Path('content-releases/20261015_est_cleanup')
p=json.loads((D/'packet.json').read_text());q=p['question']
f=lambda x:32*2**(x/2)
assert f(-2)==16 and f(0)==32
predicates={'F':lambda x:x>-2,'G':lambda x:x>0,'H':lambda x:-2<x<2,'J':lambda x:x<-2}
sample=[n/4 for n in range(-40,41)]+[-2.000001,-1.999999]
valid=[k for k,fn in predicates.items() if all((f(x)>16)==fn(x) for x in sample)]
assert valid==[q['correct']]==['F']
assert len({c['text'] for c in q['choices']})==4
assert q['assets']['content_origin']=='instructor_adaptation'
assert 'instructor-authored distractor' in q['explanation']
data=base64.b64decode(q['assets']['figure'][0].split(',')[1],validate=True)
assert hashlib.sha256(data).hexdigest()==q['assets']['original_image_sha256']
assert data==Path('assets/question-bank/MA-30.png').read_bytes()
assert len(p['archive'])==172 and len({x['id'] for x in p['archive']})==172
assert sum(x['track_id']=='est' for x in p['archive'])==159
assert sum(x['disposition']=='archived_duplicate' for x in p['archive'])==133
assert all(x['replacement_id']!=x['id'] and x['reason'] for x in p['archive'])
assert len(p['exams'])==8 and sum(x['has_history'] for x in p['exams'])==1
for e in p['exams']:
 old=e['before']['question_ids'];new=e['question_ids']
 assert len(old)==len(new)==len(set(new))
 assert sum(a!=b for a,b in zip(old,new))==1
 assert q['id'] in new and q['assets']['adapted_from_question_id'] not in new
assert len(p['sources'])==15
assert sum(x['status']=='excluded' for x in p['sources'])==14
print('PASS: monotone exponential inequality, all four choices/endpoints, authentic embedded PNG; 172 reversible archives, 133 duplicates, 8 single-item substitutions and 15 source-label corrections.')
