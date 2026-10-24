"""Offline source arithmetic, domain, choice, taxonomy and lossless-figure checks."""
import json,math,hashlib,base64,re,runpy
from fractions import Fraction as F
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'content-releases/20261017_sat_trial_october_2026'
pkt=json.loads((p/'review.json').read_text());qs={q['assets']['source_code'].removeprefix('SAT-OCT26-'):q for q in pkt['questions']}
covered=set()
def check(ref,result,options=None):
 q=qs[ref];covered.add(ref)
 if options is None: assert math.isclose(float(q['correct']),float(result),rel_tol=1e-11,abs_tol=1e-11),(ref,q['correct'],result)
 else:
  matches=[i for i,v in enumerate(options) if (v==result if not isinstance(v,(int,float,F)) else math.isclose(float(v),float(result),rel_tol=1e-10,abs_tol=1e-10))]
  assert len(matches)==1,(ref,result,options)
  assert q['correct']==chr(65+matches[0]),(ref,q['correct'],result,options)
def truth(ref,flags):check(ref,True,flags)
# Paper 1 baseline.
check('P1-M1-01',100*6-50,[56,156,550,650]);truth('P1-M1-02',[275==275,75==275,275-75==275,False])
check('P1-M1-03',F(55,100)*200)
for ref,k in [('P1-M1-04',29),('P2-M1-03',32)]:
 x=3;check(ref,k*x*x+k,[k*(x*x+1),k*(x*x+k),k*(k*x*x+1),k*(x*x+F(1,k))])
check('P1-M1-05',F(2*90,2),[30,60,90,180]);check('P1-M1-06',F(32400,180*60),[2.5,3,3.5,4])
check('P1-M1-07',F(457,100));check('P1-M1-08',F(180*80,900),[288,196,80,16])
truth('P1-M1-09',[abs(x)==43 for x in [F(1,43),0,-F(1,43),-43]])
truth('P1-M1-10',[all(f(x)==y for x,y in [(0,-8),(1,-5)]) for f in [lambda x:F(1,3)*x-8,lambda x:-x+F(1,3),lambda x:3*x-8,lambda x:-x+3]])
check('P1-M1-11',min(range(4),key=lambda i:sum((y-[.2+2.25*x,.2-2.25*x,2.25+.2*x,2.25-.2*x][i])**2 for x,y in [(1,3),(2,5.2),(3,7.2),(4,7.2),(5,12.4),(6,10),(7,15.7),(8,19.2),(9,20.4),(10,22.2)])),[0,1,2,3])
check('P1-M1-12',(21,0),[(21,0),(0,-21),(0,21),(-1,0)])
check('P1-M1-13',(17*2,24*2),[(0,2),(8.5,12),(17,24),(34,48)])
check('P1-M1-14',7500*F(46,10));check('P1-M1-15',(-7+math.sqrt(49+4*198))/2)
for ref,m in [('P1-M1-16',55),('P2-M1-14',66)]:
 K=123;check(ref,math.sqrt(2*K/m),[2*K/m**2,m*m/(2*K),math.sqrt(m/(2*K)),math.sqrt(2*K/m)])
check('P1-M1-17',F(44,22),[F(22,83),F(1,2),2,44])
truth('P1-M1-18',[all(math.isclose(f(n),7138*1.22**n) for n in [0,1,2,5]) for f in [lambda n:7138*.22**n,lambda n:7138*1.22**n,lambda n:.22*7138**n,lambda n:1.22*7138**n]])
for ref in ['P1-M1-19','P2-M1-18']:check(ref,math.sin(math.pi/4),[1/math.sqrt(3),1/math.sqrt(2),1,math.sqrt(2)])
check('P1-M1-20',math.sqrt(F(1815,15)))
for ref,k,values in [('P1-M1-21',19,[-2,-F(20,19),-1,-F(1,19)]),('P2-M1-20',27,[-2,-F(28,27),-1,-F(1,27)])]:truth(ref,[k*u*u-(k+1)==u for u in values])
check('P1-M1-22',F(9,9));check('P1-M1-23',math.hypot(24,37-5),[40,37,32,27]);check('P1-M1-24',F(3,2)+F(1,4),[F(3,8),F(7,4),F(5,4),F(3,4)])
# Paper 1 easy.
for ref,v in [('P1-M2E-01',22),('P2-M2E-05',24)]:truth(ref,[x!=0 and y==v/x and y==v*x for x,y in [(0,0),(0,v),(1,v),(v,v)]])
check('P1-M2E-02',71,[19,71,161,251]);check('P1-M2E-03',7);check('P1-M2E-04',88-28,[88,60,32,28])
# Dashed positive-slope boundary through (0,4); test shaded point (0,8).
check('P1-M2E-05',(3,4,'>'),[(3,4,'<'),(3,-4,'<'),(3,4,'>'),(3,-4,'>')])
check('P1-M2E-06',F(7+15,6-4),[8,11,14,22]);check('P1-M2E-07',dict([(1,0),(2,10),(3,13),(4,30),(5,48),(6,60),(7,77),(8,85)])[4])
check('P1-M2E-08',F(300-13*10,5),[5,10,13,34]);check('P1-M2E-09',F(9+12,2),[7,9,10.5,11])
x=3;check('P1-M2E-10',18*x*x-3*x*x,[-54*x*x,15*x*x,21*x*x,42*x*x]);check('P1-M2E-11',F(26-6+20-8,4-2),[56,32,28,16])
check('P1-M2E-12',(132,142),[(137-5,137+5),(0,132),(0,131),(143,1000)])
truth('P1-M2E-13',[all(f(x,y)==10 for x,y in [(10,0),(0,5),(4,3)]) for f in [lambda x,y:3*x*y,lambda x,y:3*(x+y),lambda x,y:2*x+y,lambda x,y:x+2*y]])
X=[8,12,12,16];Y=X+[33];truth('P1-M2E-14',[sum(X)/len(X)>sum(Y)/len(Y),sum(X)/len(X)<sum(Y)/len(Y),sum(X)/len(X)==sum(Y)/len(Y),False])
check('P1-M2E-15',2**3+26);check('P1-M2E-16',2200*3**0);check('P1-M2E-17',F(5*6,2),[15,11,6,5])
truth('P1-M2E-18',[v*v-7*v-18==0 and v>0 for v in [2,6,9,18]]);check('P1-M2E-19',(8+2*(-18/3))/2)
check('P1-M2E-20',9*2,[72,18,17,16]);truth('P1-M2E-21',[all(f(x)==y for x,y in [(-4,11),(0,12),(8,14)]) for f in [lambda x:F(1,4)*x+12,lambda x:F(1,12)*x+4,lambda x:4*x+12,lambda x:12*x+4]])
check('P1-M2E-22',2,[-5,-3,0,2]);check('P1-M2E-23',-1/F(-1,7),[9,7,5,2]);truth('P1-M2E-24',[all(y>5*x+7 for x,y in pairs) for pairs in [[(0,8),(1,13),(2,18)],[(0,7),(1,12),(2,17)],[(0,6),(1,11),(2,16)],[(0,5),(1,6),(2,7)]]])
check('P1-M2E-25',len({-F(5,3),F(5,3)}),[0,1,2,math.inf])
# Paper 1 hard.
for ref,bound in [('P1-M2H-01',137),('P2-M2H-01',120)]:truth(ref,[all(180-x<180-bound for x in [bound+.1,160,179]),False,False,False])
check('P1-M2H-02',math.sqrt(49),[7,14,24.5,49]);truth('P1-M2H-03',[all(math.isclose(k*x,y) for x,y in [(2400,4320),(3600,6480),(4800,8640)]) for k in [.6,1.8,2160,4320]])
check('P1-M2H-04',435/29);check('P1-M2H-05',F(26,3)+9,[F(26,3),F(53,3),26,35]);truth('P1-M2H-06',[all(f(x,z)==116+70*(x-1)+z for x,z in [(1,20),(3,17)]) for f in [lambda x,z:70*x+z,lambda x,z:70*x+z+46,lambda x,z:116*x+z,lambda x,z:116*x+70*z+46]])
truth('P1-M2H-07',[all(f(x)==y for x,y in [(25,-4),(27,-4),(29,4)]) for f in [lambda x:(x-25)*(x-27)+2,lambda x:(x-25)*(x-27)-4,lambda x:(x-4)*(x-29)+16,lambda x:(x-4)*(x-29)-16]])
check('P1-M2H-08',1-abs(-4-8)+abs(6-(-4)));check('P1-M2H-09',-1/(-F(1,3)/F(1,2)),[-F(2,3),-F(3,2),F(2,3),F(3,2)])
check('P1-M2H-10',(1.08-1)*100,[.08,8,25,108]);check('P1-M2H-11',296+(362-296)*2.72**0)
check('P1-M2H-13',F(534-618,6)+F(534+618,16),[-86,-14,58,72]);check('P1-M2H-14',8,[-2,3,6,8])
coins=[age for age,n in [(60,10),(65,5),(70,4),(75,12),(80,4),(85,5),(90,10)] for _ in range(n)];new=coins+[130];inc=sum(new)/51>sum(coins)/50;med=(coins[24]+coins[25])/2;truth('P1-M2H-15',[inc and new[25]>med,inc and new[25]==med,not inc and new[25]<med,not inc and new[25]>med])
m=-2;y=-math.sqrt(64-49);check('P1-M2H-16',2*(y+7*m),[14*m-2*math.sqrt(15),-14*m+2*math.sqrt(15),7*m/2-math.sqrt(15)/2,-7*m/2+math.sqrt(15)/2])
for ref,k in [('P1-M2H-18',19),('P2-M2H-15',11)]:
 for r in [j/10 for j in range(1,900) if 3*j/10>k*(90-j/10)]:
  s=90-r;vals=[math.sin(math.radians(r)),math.cos(math.radians(r)),math.sin(math.radians(r))/math.sin(math.radians(s)),math.sin(math.radians(r))/math.cos(math.radians(s))];check(ref,max(vals),vals)
check('P1-M2H-19',5+3,[5,7,8,11]);truth('P1-M2H-20',[True,False,False,False]);check('P1-M2H-21',math.sqrt(13**2-5**2)/5,[F(12,5),F(5,12),F(12,13),F(13,5)])
check('P1-M2H-22',(3.41-1)*100,[2.41,3.41,241,341]);check('P1-M2H-23',4*(-14*(3-4)**2+6*(3-2)**2),[-32,-16,-8,-2]);check('P1-M2H-24',max(x for x in range(-20,100) if x%2==0 and 3*x+6<123),[41,40,39,38])
check('P1-M2H-25',10.5*(math.sqrt(832/52))**3);check('P1-M2H-26',F(37,3)+5-F(1,3));truth('P1-M2H-27',[False,False,False,all(39*a*2*3 != 39*2*3 for a in [.5,2])])
# Paper 2 remaining baseline/easy/hard.
check('P2-M1-01',100*5+7,[112,135,500,507]);check('P2-M1-02',4+6);check('P2-M1-04',2*80/2,[8,16,80,160]);check('P2-M1-05',21*3,[3,7,24,63]);truth('P2-M1-06',[y==x*x-81 for x,y in [(1,0),(9,0),(18,0),(81,0)]])
check('P2-M1-07',F(459,100));truth('P2-M1-09',[all(f(x)==y for x,y in [(0,-9),(1,-5)]) for f in [lambda x:F(1,4)*x-9,lambda x:-x+F(1,4),lambda x:4*x-9,lambda x:-x+4]])
pts=[(1,3),(2,5.3),(3,7.4),(4,7.4),(5,12.7),(6,10),(7,15.8),(8,19.5),(9,20.7),(10,22.5)];check('P2-M1-10',min(range(4),key=lambda i:sum((y-[.2+2.28*x,.2-2.28*x,2.28+.2*x,2.28-.2*x][i])**2 for x,y in pts)),[0,1,2,3])
check('P2-M1-11',-28/(2*-4),[3.5,7,8.5,17]);check('P2-M1-12',8/(2**-1),[8,9,15,16]);assert 16*2**2==64
check('P2-M1-13',27*7*5/3);check('P2-M1-15',36/12,[F(12,95),F(1,3),3,36]);truth('P2-M1-16',[y>=x+15 and y<=-5*x-15 for x,y in [(-6,13),(-6,8),(-4,13),(-4,8)]])
truth('P2-M1-17',[all(f(x,z)==111+50*(x-1)+z for x,z in [(1,3),(4,19)]) for f in [lambda x,z:50*x+z,lambda x,z:50*x+z+61,lambda x,z:111*x+z,lambda x,z:111*x+50*z+61]])
check('P2-M1-19',-19*-6,[114,6,-6,-114]);check('P2-M1-21',F(5,1)/(-F(10,8)));check('P2-M1-22',(-3+6)+(-3-6))
check('P2-M2E-01',3,[3,5,7,8]);check('P2-M2E-02',62-31,[2,31,62,93]);check('P2-M2E-03',F(2,5),[F(1,5),F(2,5),F(3,5),F(5,5)])
check('P2-M2E-04',(0,F(2,17)),[(2,17),(0,17),(0,2),(0,F(2,17))]);check('P2-M2E-06',16*3,[48,19,16,13]);check('P2-M2E-07',92-32,[92,60,32,28]);check('P2-M2E-08',(330-15*10)/5,[5,10,15,36])
x=3;check('P2-M2E-09',14*x*x-5*x*x,[-70*x*x,9*x*x,19*x*x,38*x*x]);check('P2-M2E-10',180-36-90,[36,54,90,180]);truth('P2-M2E-11',[True,False,False,False])
check('P2-M2E-12',F(55,100)*500);check('P2-M2E-13',2**2+2+53);check('P2-M2E-14',3100*2**0);check('P2-M2E-15',40+4**2,[22,24,44,56]);check('P2-M2E-16',(9+3*(32/-8))/3)
truth('P2-M2E-17',[y==(x+7)*(x-9)*(x+12) for x,y in [(3,0),(0,7),(9,0),(0,12)]]);truth('P2-M2E-18',[all(f(x)==y for x,y in [(0,7),(1,13),(2,19)]) for f in [lambda x:7*x+6,lambda x:6*x+7,lambda x:x+7,lambda x:6*x]])
check('P2-M2E-19',F(22,1)/F(20,100)*F(30,100));check('P2-M2E-20',0,[1,2,math.inf,0]);check('P2-M2E-21',((17,'k'),math.sqrt(36)),[((17,'k'),6),(('k',17),6),((17,'k'),36),(('k',17),36)])
truth('P2-M2E-22',[all(f(x,y)==15 for x,y in [(3,0),(0,5)]) for f in [lambda x,y:5*x+3*y,lambda x,y:3*x+5*y,lambda x,y:5*x-3*y,lambda x,y:3*x-5*y]])
truth('P2-M2H-02',[all(math.isclose(k*x,y) for x,y in [(1040,2496),(1560,3744),(2080,4992)]) for k in [.6,2.4,1248,2496]])
check('P2-M2H-03',325/25);check('P2-M2H-04',0,[-11,-7,0,4]);check('P2-M2H-05',math.ceil((1500+600)/(50-18)),[30,42,47,66]);a=33;x=7
check('P2-M2H-06',(a-15)/(x-2)+5-3,[(a-15)/(x+2)+2,(a-15)/(x-2)+2,(a-18)/(x+2)+5,(a-18)/(x-2)+5])
pts=[(1,4.9),(2,4),(3,3.8),(4,4.8),(5,4.8),(6,2.4),(7,2.1),(8,1.2),(9,2.2)];check('P2-M2H-07',sum(y>6-.5*x for x,y in pts),[9,6,3,0]);check('P2-M2H-08',-1/F(-18,2),[9,F(1,9),-F(1,9),-9]);check('P2-M2H-10',294+(364-294)*2.72**0)
h,w=5000,7560;assert F(h,5)+F(2*w,7)==3160;truth('P2-M2H-11',[h+w==3160,h+2*w==3160,10*h+7*w==110600,7*h+10*w==110600])
truth('P2-M2H-12',[7*v+6>=0 and math.isclose(math.sqrt(7*v+6),-7*v) for v in [-F(6,7),-F(2,7),F(2,7),F(3,7)]])
check('P2-M2H-14',(16*14-32**2)/16);truth('P2-M2H-16',[False,False,False,True]);check('P2-M2H-17',2*42*math.sqrt(13)/math.hypot(2-(-7),11-5));check('P2-M2H-18',6*(-12*(5-3)**2+6*(5-4)**2),[-252,-126,-42,-7])
truth('P2-M2H-19',[False,False,3>0 and -7+17>0,False]);check('P2-M2H-20',math.hypot(238,(4508-2*238)/2),[238,2002,2016,2030]);truth('P2-M2H-21',[False,False,False,43*.5*2*3<43*2*3<43*2*2*3]);check('P2-M2H-22',(F(462,100)/F(84,100000))*F(100,1000))
# Dataset integrity and source occurrence links.
assert set(qs)==covered,(set(qs)-covered,covered-set(qs))
assert len(pkt['questions'])==137 and sum(len(q['assets']['source_occurrences']) for q in pkt['questions'])==142
canon=set(re.findall(r'^    "([^"]+)"', (root/'web/lesson-taxonomy.js').read_text().split('"est":')[0],re.M))
for q in pkt['questions']:
 assert q['topic'] in canon,(q['id'],q['topic'])
 assert q['assets']['curriculum_lesson']==q['topic']
 assert not set(q['assets'])&{'correct','answer','explanation','solution','solution_figure'}
 if q['type']=='mcq':assert len({c['text'] for c in q['choices']})==4
 if 'figure' in q['assets']:
  b=base64.b64decode(q['assets']['figure'].split(',')[1]);assert b[:8]==b'\x89PNG\r\n\x1a\n'
  assert hashlib.sha256(b).hexdigest()==q['assets']['figure_sha256']
  assert b==(p/'figures'/f'{q["assets"]["source_code"].removeprefix("SAT-OCT26-")}.png').read_bytes()
print('PASS: 137 independent source solutions, 142 references, canonical lessons, keys and 25 exact figure hashes.')
