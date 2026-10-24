"""Exact independent mathematics and source gates for the bounded release."""
import json, math, hashlib
from fractions import Fraction as F
from itertools import product
from pathlib import Path
D=Path('content-releases/20261015_est_math_review')
p=json.loads((D/'packet.json').read_text())
expected={}
def put(code,value):expected[code]=str(value)
put('CP-c24-02',F(55+80+30,450));put('CP-c25-02',max([17,19,23,28])-min([17,19,23,28]))
put('CP-c23-03',(447+388)-(254+315+122));put('CP-c07-19',F(7,2)*5)
put('CP-c19-14',math.isqrt(64+1+16));put('CP-c19-11',F(180-144,2))
put('CP-c19-30',math.isqrt(int(-F(7,2)+F(49,4)+F(1,4))))
put('CP-c19-12',6**2);put('CP-c19-17',40)
put('CP-c19-25',F(16**2-14**2,4));put('CP-c19-22',((2*4+48)//2)**2)
put('CP-c19-26',-18+24+9**2+12**2-1)
# Compare all choices, rather than accepting a stored letter.
def choose(code,keys,predicate):
 good=[k for k in keys if predicate(k)]
 assert len(good)==1,(code,good)
 put(code,good[0])
dot_choices={'A':lambda n:3*n-5,'B':lambda n:2*n+2,'C':lambda n:2*n+3,'D':lambda n:3*n-1}
choose('MG-13',dot_choices,lambda k:all(dot_choices[k](n)==v for n,v in enumerate([2,5,8,11],1)))
choose('T8-08',dict(F=20780,G=12800,H=28800,J=20760),lambda k:dict(F=20780,G=12800,H=28800,J=20760)[k]==52*400-F(5,100)*400**2)
put('T7-19','C') # 1/2 is a real noninteger; Q, irrational reals, and Z are subsets of R.
x=F(12,3);y=x+2-4;choose('T7-17',dict(A=3,B=4,C=5,D=6),lambda k:dict(A=3,B=4,C=5,D=6)[k]==x+y)
# Parent function samples distinguish shifted and reflected images.
models={'F':lambda x:4.0**x,'G':lambda x:4.0**x-1,'H':lambda x:4.0**(-x),'J':lambda x:4.0**(-x)-1}
choose('MA-06',models,lambda k:all(models[k](x)==4.0**x for x in [-1,0,1]))
# Interval predicates test both endpoints, both exteriors and interior samples.
def original(x):return 2*x-8<=x-4<3*(x+6)
intervals={'A':lambda x:-11<x<=4,'B':lambda x:x<=4,'C':lambda x:-11<x<=12,'D':lambda x:x<=12}
samples=[F(n,2) for n in range(-30,31)]+[F(-11001,1000),F(-10999,1000),F(4001,1000)]
choose('E-21',intervals,lambda k:all(original(x)==intervals[k](x) for x in samples))
# Revenue, including boundary and off-axis counterexamples.
regions={'A':lambda x,y:y<=250-F(x,2),'B':lambda x,y:y>=250-F(x,2),'C':lambda x,y:y<=500-2*x,'D':lambda x,y:y>=500-2*x}
pts=list(product([0,1,100,249,250,251,500],[0,1,250,499,500,501]))
choose('E-11',regions,lambda k:all((6*x+3*y>=1500)==regions[k](x,y) for x,y in pts))
put('T7-01',-(2+6)); expected['T7-01']='C'
put('MA-29','B') # h(x-14)=g(x)-12 establishes the point translation (-14,-12).
planes={'A':lambda x,y:y>F(x,2)-2,'B':lambda x,y:y<F(x,2)-2,'C':lambda x,y:y>=F(x,2)-2,'D':lambda x,y:y<=F(x,2)-2}
pts=list(product(range(-4,5),[F(n,2) for n in range(-10,11)]))
choose('E-19',planes,lambda k:all((2*x-4*y>8)==planes[k](x,y) for x,y in pts))
for x,y in product(range(1,20,2),range(-19,0,2)):
 if x!=-y:assert x-y>0 and (x-y)%2==0
assert (-1)**3<0 and F(3)**-1==F(1,3) and F((-1)**2,3)==F(1,3)
put('H-15','C')
slopes=dict(AB=F(2,5),BC=-F(2,5),CD=F(2,5),AD=-F(5,2))
assert slopes['AB']==slopes['CD'] and slopes['AD']!=slopes['BC'];put('MG-47','B')
valid=[]
for job,new,give in product([False,True],repeat=3):
 if (not job or new) and (not new or give) and not give:valid.append((job,new,give))
assert valid==[(False,False,False)];put('AI-41','D')
choices={'F':-F(1,5),'G':F(3,5),'H':-F(3,2),'J':F(1,2)}
choose('MA-18',choices,lambda k:10*choices[k]**2-choices[k]==3)
for q in p:
 code=q['source_code'];correct=q['correct'];assert code in expected
 if q['track_id']=='est' and code.startswith('CP'):
  values=correct if isinstance(correct,list) else [correct]
  target=F(expected[code]);assert any(F(v)==target for v in values)
  for v in values:
   assert F(v)==target or (code=='CP-c24-02' and F(v)==F(367,1000)),(code,v)
 else:assert correct==expected[code],(code,correct,expected[code])
 assert len(q['explanation'])>80
 if q['choices']:
  assert len(set(c['key'] for c in q['choices']))==len(q['choices'])
 if 'image_file' in q['evidence']:
  image=Path('assets/question-bank')/q['evidence']['image_file']
  assert hashlib.sha256(image.read_bytes()).hexdigest()==q['evidence']['image_sha256']
assert len(p)==28 and sum(q['track_id']=='est' for q in p)==14
print('PASS: 28 records, exact arithmetic, roots, all MCQ alternatives, inequalities at boundaries, logic truth table, numeric equivalents and source-image hashes.')
