import json,math
from fractions import Fraction as F
from pathlib import Path
d=json.loads((Path(__file__).resolve().parents[1]/'content-releases/20261005_clean_notes/review.json').read_text())
q={(x['assets']['source_page'],x['assets']['source_block']):x for x in d['verified_questions']}
assert len(q)==12 and len(d['duplicates'])==6 and len(d['held'])==2
assert len({x['id'] for x in q.values()})==12
def key(p,b,v): assert q[p,b]['correct']==v,(p,b,v)
key(2,1,'E'); assert 3*(F(27,4)-(2*F(3,2)**2-8))==F(123,4)
key(2,2,'A'); assert 10**2-7**2==51
poly=lambda n:(n-1)**4+4*n-11
roots=[]
for a,b in [(-1.,0.),(2.,3.)]:
    for _ in range(90):
        m=(a+b)/2
        if poly(a)*poly(m)<=0:b=m
        else:a=m
    roots.append((a+b)/2)
assert all(abs(poly(r))<1e-12 for r in roots)
assert [round(x,2) for x in roots]==[-.96,2.21]
# The derivative is negative for n<0, zero at 0, positive for n>0; exactly two roots.
assert poly(0)<0
opts=[float(c['text']) for c in q[3,1]['choices']]
assert [i for i,o in enumerate(opts) if any(round(r,2 if i in [1,2,3] else 3)==o for r in roots)]==[1]
key(3,1,'B'); assert 'approximates' in q[3,1]['stem']
assert all(x*x+4*x-12==y for x,y in zip([-5,-3,-1,1,3,5],[-7,-15,-15,-7,9,33]))
assert (-9)**2+4*(-9)-12==33; key(4,1,'33')
for m1,m2 in [(1,2),(2,1),(-2,-1),(4,-4)]: assert (F(1,m2-m1)>0)==(m1<m2)
key(5,1,'B'); assert 3500*F(88,100)*F(105,100)==3234;key(8,2,'3234')
assert 5*(7*5-4)==155;key(9,1,'5')
assert F(114,100)*F(104,100)==F(11856,10000);key(9,2,'D')
assert 7*F(-1,7)==-1;key(10,1,'B')
assert 4*80-3*76==92;key(10,2,'C')
assert F(2,5)*F(3,4)==F(3,10);key(11,3,'A')
assert [F(*map(int,c['text'].split(':')))==F(3,10) for c in q[11,3]['choices']]==[True,False,False,False]
assert F(15,2)*25==F(375,2);key(12,1,'187.5')
# Missing-format triangle's exact area; no rounding tolerance is invented.
x=math.sqrt(3); y=6-x*x
assert math.isclose(math.hypot(x,y),math.hypot(2*math.sqrt(3)-x,y))
assert math.isclose(2*math.sqrt(3)*y/2,3*math.sqrt(3))
cases=[(c,i,50-c-i) for c in range(51) for i in range(51-c) if 3*c-2*i==75]
assert cases==[(25,0,25),(27,3,20),(29,6,15),(31,9,10),(33,12,5),(35,15,0)]
for x in q.values():
    assert x['track_id']=='est' and x['assets']['curriculum_lesson']==x['topic']
    assert not x['assets'].get('release_hold_reason')
    assert r'\n' not in x['stem']
    if x['type']=='mcq': assert sum(c['key']==x['correct'] for c in x['choices'])==1
print('PASS: all twelve answers, six exclusions and two source holds')
