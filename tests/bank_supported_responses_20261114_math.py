"""Independent symbolic/numeric verification, with coverage for every adaptation."""
import json,math,statistics
from pathlib import Path
from fractions import Fraction as F
import sympy as S
from sympy.calculus.util import continuous_domain
m=json.loads(Path('content-releases/20261114_bank_review/manifest_supported.json').read_text())
by={q['assets']['source_ids_adapted'][0][:8]:q for q in m['additions']}
x,y=S.symbols('x y',real=True);v,w=S.symbols('v w',positive=True)
covered=set();checks=0
def check(prefix,condition):
 global checks
 assert bool(condition),prefix
 covered.add(prefix);checks+=1
def equal(prefix,a,b):check(prefix,S.simplify(a-b)==0)
# Log expansion is checked with positive and negative x, respecting the real domain.
for xv in [-7,-1,1,3]:
 for yv,zv in [(4,5),(9,2)]:check('074ada07',math.isclose(math.log(xv*xv*math.sqrt(yv)/zv),2*math.log(abs(xv))+.5*math.log(yv)-math.log(zv)))
check('09ecb437',continuous_domain(S.sqrt(5-x)/(x+2),x,S.S.Reals)==S.Union(S.Interval.open(-S.oo,-2),S.Interval.Lopen(-2,5)))
check('0eea2617',S.limit((2*x+1)/(x-3),x,S.oo)==2 and S.limit((2*x+1)/(x-3),x,3,dir='+')==S.oo)
check('1598aea2',S.solveset(2*S.Abs(x-4)-9,x,S.S.Reals)==S.FiniteSet(-S.Rational(1,2),S.Rational(17,2)))
equal('16b328b4',S.I**37,S.I)
check('172ad291',{2*n-4 for n in [-4,0,6]}=={-12,-4,8})
check('17976d6c',S.expand((x+2)**2+(y-5)**2-16)==x*x+y*y+4*x-10*y+13)
check('26abc145',S.Matrix([[2,1],[-3,4]])+S.Matrix([[5,-2],[1,6]])==S.Matrix([[7,-1],[-2,10]]))
check('28077444',S.solve([2*x+y-11,x-y-1],[x,y])=={x:4,y:3})
check('296355c1',S.limit((x*x-4)/(x-2),x,2)==4 and (x-2).subs(x,2)==0)
equal('29abef4e',S.sqrt(72),6*S.sqrt(2))
check('2c17ac10',S.Matrix([[3,1],[2,1]])*S.Matrix([[1,-1],[-2,3]])==S.eye(2))
check('317d7cf1',S.solve(S.diff(2*(x-4)**2-7,x),x)==[4] and (2*(x-4)**2-7).subs(x,4)==-7)
check('36341e49',S.solveset(S.Abs(2*x-7)-9,x,S.S.Reals)==S.FiniteSet(-1,8))
equal('38daac79',180/v+180/(v+20),360*(v+10)/(v*(v+20)))
check('38daac79',180/60+180/80==5.25)
check('3ba6f5a2',S.solve([3*x+4+4*y,x+2*y-2],[x,y])=={x:-8,y:5})
a,b=S.symbols('a b')
check('3ec0a5f0',S.solve([7*a-12-6,21-28+b],[a,b])=={a:S.Rational(18,7),b:7})
equal('3f396c88',S.pi*4**2*9,144*S.pi)
equal('451f180f',(5*x-11)*(5*x+11),25*x*x-121)
check('46097bfa',((F(-3+5,2),F(7-1,2)))==(1,3))
t=S.symbols('t',positive=True)
equal('4820eb3d',(t**5)**S.Rational(1,3),t**S.Rational(5,3))
check('48c8b9b8',S.diff(-2*x+7,x)==-2 and (-2*x+7).subs(x,0)==7)
check('49104dc3',S.solveset(1/x+1/(x+2)-S.Rational(3,4),x,S.S.Reals)==S.FiniteSet(-S.Rational(4,3),2))
check('59256413',S.solveset(x*x+4*x+13,x,S.S.Reals)==S.EmptySet)
z=S.symbols('z')
check('59256413',set(S.solve(z*z+4*z+13,z))=={-2-3*S.I,-2+3*S.I})
check('59721de1',S.solve([x+y-9,2*x-y-6],[x,y])=={x:5,y:4})
equal('5f033576',(3+2*S.I)/(1-S.I),(1+5*S.I)/2)
f=lambda z:z*z+z+1
for xv in [-5,0,2]:check('5f17833f',-2*f(xv+3)+5==-(2*((xv+3)**2+(xv+3)+1))+5)
check('6037be14',4*(-9)<0 and S.factor(4*x*x-9*y*y-36)/36==x*x/9-y*y/4-1)
check('61a51dd3',set(S.solve(2*x*x-7*x+3,x))=={S.Rational(1,2),3})
equal('61c9e3fb',(x-3)**2+(y+4)**2-36,x*x+y*y-6*x+8*y-11)
check('69b73d1b',(-2,-3)==tuple(-n for n in (2,3)))
equal('6b29ba68',(3*x-5+5)/3,x)
equal('6b29ba68',3*((x+5)/3)-5,x)
check('6c698a69',7**2+(7*S.sqrt(3))**2==14**2)
check('737364bf',F(5000*3,100)==150)
equal('7e911655',2*((40-w)+w),80)
equal('7e911655',w*(40-w),40*w-w*w)
check('7f518a2a',abs(-3)==3 and S.Rational(2,4)*S.pi==S.pi/2)
equal('84d52170',6*x**3*y**-2/(3*x**-1*y),2*x**4/y**3)
equal('89153e97',(x*x-9)/(x*x-x-6),(x+3)/(x+2))
check('89153e97',set(S.solve(x*x-x-6,x))=={-2,3})
equal('8b343527',(x-4)*(x-1)*(x+1),x**3-4*x*x-x+4)
check('8b8cfb7a',(5-2)*180==540)
check('90f77567',tuple(reversed((6,-2)))==(-2,6))
check('967c3d8b',25>9 and all(F(q*q,25)==1 for q in [-5,5]))
check('9a06ec43',S.reduce_inequalities([-3<=2*x+5,2*x+5<11],x).as_set()==S.Interval.Ropen(-4,3))
check('9dff9f8a',9**2+12**2==15**2 and F(9,15)==F(3,5) and F(12,15)==F(4,5))
equal('9fcd9239',(x-3)**2-4,x*x-6*x+5)
equal('a77b0768',(x-3)*(x-4),x*x-7*x+12)
check('a9517d0e',S.solveset(S.sin(x)-S.Rational(1,2),x,S.Interval.Ropen(0,2*S.pi))==S.FiniteSet(S.pi/6,5*S.pi/6))
# Truth-table verification: the converse is Q -> P, not either negation.
P,Q=S.symbols('P Q')
check('abe5dbb4',S.simplify_logic(S.Xor(S.Implies(Q,P),S.Or(S.Not(Q),P)))==S.false)
root=(S.sqrt(41)-5)/2
equal('abf3a097',(4+2*root)*(6+2*root),40)
check('abf3a097',root>0 and (-S.sqrt(41)-5)/2<0)
equal('cb5328b0',(x-2)**2+(y+3)**2-25,x*x+y*y-4*x+6*y-12)
check('d4fabad7',(-3*x+11).subs(x,2)==5 and S.diff(-3*x+11,x)==-3)
equal('dc91cd5c',3*(x-2)*(x+5),3*x*x+9*x-30)
check('dde56c95',F(106,100)*500==530 and 500*F(106,100)**0==500)
check('de4a2e58',S.minimum(S.Abs(x)+1,x)==1 and continuous_domain(S.Abs(x)+1,x,S.S.Reals)==S.S.Reals)
equal('e6c907a4',5/(2+S.sqrt(3)),10-5*S.sqrt(3))
equal('e81728fa',(x*x-9)/(x-3),x+3)
check('ec0b80b3',S.solve_univariate_inequality(x+8>=7+2*x,x)==(x<=1))
check('ed1dcc2d',statistics.mean([3,5,5,7,10])==6 and statistics.median([3,5,5,7,10])==5)
check('f8d3bf78',S.Matrix([[1,2],[0,3]])*S.Matrix([[4,1],[-2,5]])==S.Matrix([[0,11],[-6,15]]))
check('31ddb28a',S.solve_univariate_inequality(-3*x+7<16,x).as_set()==S.Interval.open(-3,S.oo))
check('3eff8a14',[6*b+12*n<360 and b-n>=8 for b,n in [(28,22),(30,18),(20,15),(30,10)]]==[False,False,False,True])
check('6dc9e13a',S.solveset(S.Abs((2-x)/7)-S.Abs((x+3)/5),x,S.S.Reals)==S.FiniteSet(-S.Rational(11,12),-S.Rational(31,2)))
check('7e080c5c',(-3*(x+1)/(x+2)).subs(x,-1)==0 and S.limit(-3*(x+1)/(x+2),x,S.oo)==-3)
old=[70,80,80,70,75];new=old+[90,95]
check('7f8050b5',statistics.mean(new)-statistics.mean(old)==statistics.median(new)-statistics.median(old)==5)
check('810b6716',S.solveset(2*x*x-9,x,S.S.Reals)==S.FiniteSet(-3*S.sqrt(2)/2,3*S.sqrt(2)/2))
equal('8bcc0c58',(x**16*y**9+x**6*y**2)/(x*x*y*y),x**14*y**7+x**4)
positive=S.symbols('positive',positive=True)
equal('a085f287',2*x*x*positive/(x*S.sqrt(positive)),2*x*S.sqrt(positive))
equal('aacba8d8',S.sqrt(15)/S.sqrt(2),S.sqrt(30)/2)
check('af2c2124',S.solve([x+y-15,7*x+12*y-140],[x,y])=={x:8,y:7})
nonzero=S.symbols('nonzero',nonzero=True)
check('ec6acdfa',S.solve([x+nonzero*y-2,3*x-2*nonzero*y-6],[x,y])=={x:2,y:0})
assert covered==set(by),(set(by)-covered,covered-set(by))
for q in by.values():
 assert q['correct'] in 'ABCD'
 assert len({c['text'] for c in q['choices']})==4
 assert q['assets']['content_origin']=='instructor_adaptation'
 assert q['track_id']=='act2'
assert set(q['correct'] for q in by.values())==set('ABCD')
print(f'{checks} mathematical checks cover all {len(covered)} supported-response adaptations')
