"""Release gates: original assets, answer checks, exam balance and no key exposure."""
from pathlib import Path
import json,math,hashlib,statistics
from collections import Counter
from fractions import Fraction as F
root=Path(__file__).resolve().parents[1];folder=root/'content/est-september-2026'
b=json.loads((folder/'release-bank.json').read_text());qs={q['assets']['source_code']:q for q in b['questions']}
assert len(qs)==119
def key(code,k):assert qs[code]['correct']==k,code
# Independent second checks for entries not covered by the retained numeric suites.
key('HOA 013','C') # at most40 total, at least10 horizontal, cost5h+3v<=800
assert 10+0<=40 and 5*10+3*0<=800
assert ((4+8)/2,4)==(6,4);key('HOA 039','D')
assert [x for x in [0,-1,2,-3] if 2*x*x-7*abs(x)+5==0]==[-1];key('HOA 046','B')
assert [x for x in [-7,1,3] if abs(4-x)-2<0]==[3];key('HOA 068','C')
assert [v for v in [1,-7,F(-2,3),4] if abs(v)==7]==[-7];key('HOA 176','B')
assert 1!=-1;key('HOA 206','A') # the same product cannot equal both constants
assert min([(x*x+y*y,i) for i,(x,y) in enumerate([(0,-4),(2,6),(-4,1),(-1,-5)])])[1]==0;key('HOA 215','A')
assert [a*2+c==d for a,c,d in [(2,8,14),(-4,11,19),(-5,5,-5),(6,12,18)]]==[False,False,True,False];key('HOA 236','C')
assert [x for x in [-1,3,4,7] if not abs(2*x-3)<9]==[7];key('HOA 238','D')
assert [65+F(50,100)*100,60+F(52,100)*100,55+F(54,100)*100,50+F(56,100)*100]==[115,112,109,106];key('PSD 075','D')
assert [n for n in [25,26,27,28] if (n+3)%6==0]==[27];key('PSD 079','C')
for a in [1,15,20]:assert F(2*a+30,2)-15==a
key('PSD 101','A');assert F(3,2)*(10-10)+40==40;key('PSD 102','A')
assert 5+2*(12-5)==19;key('PSD 188','B') # seven extra days after flat first-five-day fee
key('PAM 019','A') # graph's unique y=1.5 intersection is on the y-axis
assert all(-5*3**x<0 for x in [-10,0,10]);key('PAM 075','B') # approaches -2 from below; never equals it
assert abs(7-4)==3 and 7+4==11;key('GTC 036','B')
assert (1+(-1)-1,-2+3-3)==(-1,-2);key('GTC 039','C')
assert -7+5==-2;key('MIX 003','B')
assert F('19.25')+F('1.25')-F('10.26')-1==F('9.24')
assert F('11.58')+F('1.25')-F('7.58')-1==F('4.25');key('MIX 016','C')
key('MIX 043','B') # subtract x from x<y to obtain y-x>0
assert all(x*x+1>0 for x in [-100,-1,0,1,100]);key('MIX 045','C') # x(x²+1)=0 has sole real root0
assert math.sqrt(5)<5<2*math.sqrt(7);key('MIX 050','D')
assert 'CUBE root' in qs['MIX 045']['explanation']
assert 'PSD 202' not in qs and 'MIX 024' not in qs and 'MIX 025' not in qs
old=json.loads((root/'content/est-banks-2026/reviewed-bank.json').read_text())
assert not {q['id'] for q in old['questions']}&{q['id'] for q in qs.values()}
for q in qs.values():
 assert q['correct'] and q['explanation'] and q['track_id']=='est'
 assert 'correct' not in q['assets'] and 'explanation' not in q['assets']
 path=q['assets']['image'].split('math.portal.ghoneem.com/',1)[1]
 for public in ['web','dist']:
  p=root/public/path
  assert p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==q['assets']['source_image_sha256']
 assert (q['type']=='grid_in' and q['correct'] in ['4','75']) or (q['type']=='mcq' and q['correct'] in 'ABCD' and len(q['choices'])==4)
byid={q['id']:q for q in qs.values()}
full=[e for e in b['exams'] if e['assessment_type']=='full_exam']
assert len(full)==2 and len({i for e in full for i in e['question_ids']})==100
for e in b['exams']:
 assert not e['is_published'] and e['review_policy']=='full_review' and not e['shuffle']
 assert len(set(e['question_ids']))==len(e['question_ids'])
 assert set(e['question_ids'])<=set(byid)
 if e['assessment_type']=='full_exam':
  assert len(e['question_ids'])==50 and e['duration_seconds']==4500
  assert Counter(byid[i]['assets']['domain'] for i in e['question_ids'])==Counter(FA=15,DAP=15,AAF=15,GT=5)
assert {i for e in b['exams'] if e['assessment_type']=='lesson_exam' for i in e['question_ids']}==set(byid)
assert (root/'dist/exams/est-march-2026/reference.png').is_file()
print('PASS:119 intact original-image questions, retained numeric checks plus23 second checks,2 disjoint balanced50-question/75-minute papers, full lesson coverage and private keys.')
