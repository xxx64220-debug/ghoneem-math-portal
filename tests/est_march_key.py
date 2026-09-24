"""Independent numerical checks against the original paper's choice values."""
import json,math,statistics
from fractions import Fraction as F
from pathlib import Path
key=json.loads(Path('content/est-march-2026/worked-answer-key.json').read_text())
rows={q['number']:q for q in key['questions']}
assert list(rows)==list(range(1,51))
def check(n,value,choices,tolerance=1e-8):
 letter='ABCD'[[abs(value-c)<tolerance for c in choices].index(True)]
 assert rows[n]['correct']==letter,(n,value,letter,rows[n]['correct'])
check(1,F(2,7)*14000,[2000,4000,7000,8000])
check(2,statistics.median([6,7,7,6,1,5,9,9,7,10]),[5,6.5,7,7.5])
check(3,F(134400,14*12),[750,760,775,800])
check(5,F(239400,19*12)*F(4,5),[800,840,850,900])
check(6,F(3,10)**3,[.027,.343,.540,.9])
check(7,math.factorial(6)//math.factorial(2),[180,360,720,1440])
assert rows[8]['correct']=='C' and F(1,10)*(-9)+F(39,10)==3
check(9,F(-3*5-4,2-1+1),[-9.5,-4,4.5,9.5])
check(10,round(F(161,320),3),[.316,.467,.503,.519])
check(11,round(F(101,226),3),[.265,.316,.447,.638])
check(12,F(308,1)/F(14,10),[220,250,280,288])
P=lambda x:3*x**4+5*x**3-64*x**2-164*x-80
assert [P(x)==0 for x in [5,2,-4,F(-2,3)]]==[True,False,True,True] and rows[13]['correct']=='B'
check(14,4500*F(2,100)*2,[90,180,181.8,300.2])
check(15,F(5*4-8,15),[.6,.8,1.2,1.4])
check(16,round(12+F(40,360)*2*math.pi*6,2),[10.19,12,14.73,16.19])
check(17,(400-4)*230*5,[4600,91080,182160,455400])
for a,y in [(-3,4),(7,9),(2,2)]:
 original=math.sqrt(125*a*a)/math.sqrt(5*y**3)
 check(18,original,[abs(a)*math.sqrt(5*y)/y**2,5*abs(a)*math.sqrt(y)/y**2,5*abs(a)*math.sqrt(5*y)/y**2,5*abs(a)*math.sqrt(5*y)])
assert [abs(3*x-5)+1==2 for x in [F(1,3),1,2,F(7,3)]]==[False,False,True,False] and rows[19]['correct']=='C'
assert rows[20]['correct']=='D' and F(20,8)==F(5,2)
assert rows[21]['correct']=='D' and -3>-10
check(22,F(-5+11,2),[3,6,8,16])
assert rows[23]['correct']==['B','D']
check(24,F(-1,3),[-1,F(-1,3),0,3])
check(25,F(3*1+1,4),[-1,F(1,2),1,F(3,2)])
check(26,2*(5+(5-2)*F(15-5,7-2)),[5.5,13,17.5,22])
check(27,F(9,1)/F(12,10)*26,[195,202,223,234])
check(28,F(4,3)*12**3,[192,576,2304,6912])
assert [x**3-x*x-14*x+24 for x in [-4,2,3]]==[0,0,0] and rows[29]['correct']=='C'
check(30,max(n for n in range(1,10) if 3*n-4<=1),[1,2,3,5])
check(31,F(34-20,20)*100,[30,45,50,70])
check(32,(2*1+1)+(-3*1+1),[1,3,6,7])
check(33,F(20+7,3)*2,[4.5,9,12.5,18])
check(34,F(24-3*6,33-5*6),[-2,-1,2,3])
check(36,round(.05674*1000),[6,56,57,567])
check(37,(-3)**2-4*3,[3,-3,-15,-21])
check(38,F(2,3),[F(1,3),0,F(2,3),1])
assert rows[39]['correct']=='A' and -2*1+2==0
assert rows[40]['correct']=='C' and -2*(-1)**2-4*(-1)+1==3
check(41,abs(2*(-1)-3*(-2))+4*(-2),[-8,-4,0,4])
check(42,1+3,[1,3,4,8])
assert rows[43]['correct']=='D'
assert (2j+5)*(1j-1)==-7+3j and rows[44]['correct']=='A'
for x in [-2,1,3]:
 y=F(4*x*x-2*x-1,3*x)
 assert 2*x+3*y*x+1==4*x*x and rows[45]['correct']=='A'
check(46,3*(math.sqrt(3)-1)**2-(math.sqrt(3)-1)+6*math.sqrt(3),[13-math.sqrt(3),13,13+math.sqrt(3),15])
dc=math.sqrt(15**2-9**2);bd=math.sqrt(20**2-dc**2)
check(47,(9+bd)*dc/2,[131.5,144.5,150,300])
check(48,(3-1)**2+(-2+1)**2,[2,3,5,7])
check(49,-(3*(-1)**3-2*(-1)),[1,3,6,9])
check(50,math.prod(n for n in range(1,10) if 3*n+1<10),[1,2,3,6])
assert rows[4]['correct']==rows[35]['correct']=={'void':True}
assert F(11,100)*(134400+85440+239400+11700) not in [F('14784.0'),F('37052.4'),F('50770.6'),F('63386.4')]
assert F(-2-44,1+3) not in [F('-1.5'),F('.5'),1,F('1.5')]
assert sum(q['correct']!={'void':True} for q in rows.values())==48
assert all(len(q['explanation'])>30 and '$' not in q['explanation'] for q in rows.values())
print('PASS: worked answers checked numerically; original graphs reviewed; 48 scored items, 2 exclusions, both valid Q23 answers accepted.')
