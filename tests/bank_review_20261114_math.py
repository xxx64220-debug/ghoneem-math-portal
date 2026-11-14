"""Independent arithmetic/domain checks for the repaired mathematical items."""
import json, math, statistics, cmath
from fractions import Fraction as F
from pathlib import Path
p=Path('content-releases/20261114_bank_review')
m=json.loads((p/'manifest.json').read_text())
new={q['assets']['source_ids_adapted'][0]:q for q in m['additions']}
checks=0
def check(condition):
 global checks
 assert condition
 checks+=1
def numeric(source,value):
 check(float(new[source]['correct'])==value)
numeric('1115c92c-eca5-5c40-b42f-f782066e4eff',round(20*math.sin(math.radians(65)),2))
numeric('a7e0c938-c48b-50d8-88b3-8388c07f0560',round(5280*12/(28*math.pi)))
check(F(22,7)*5**2*7==550)  # Existing canonical version explicitly uses 22/7.
check('d155cd26-9e65-58a5-ac5b-26a21eba28e2' not in new)
check(math.isclose(math.log(math.sqrt(10)-1,3)+math.log(math.sqrt(10)+1,3),2))
check(-math.sqrt(10)<1)  # Reject the extraneous algebraic root.
check(new['2da9d842-d0a0-5b81-a3e7-831e75a4f515']['correct']=='B')
check(math.isclose(7**2+10**2-2*7*10*math.cos(math.pi/3),79))
check(new['98cb24bf-e675-5d2e-a4c0-bd834cbbc0f2']['correct']=='A')
check(2*F(11,2)==11)
check(new['a66e7923-397b-5cd5-995c-04205246199d']['correct']=='A')
check(F(17,2)**2==F(289,4))
check(new['d0ffb261-513f-551b-88c4-9b6845e98178']['correct']=='B')
roots=[x for x in [F(-1,3),F(3,2),F(-3,2),F(1,3)] if 6*x*x-7*x-3==0 and x>0]
check(roots==[F(3,2)])
check(new['9b4f5a2d-27d7-5210-922a-31e2556e7130']['correct']=='B')
scores=[70,70,80,70,80];after=scores+[90,95]
check(F(sum(after),len(after))-F(sum(scores),len(scores))==F(37,7))
check(statistics.median(after)-statistics.median(scores)==10)
check(new['9b45a010-891a-5c72-aeb0-4346e6f82c3f']['correct']=='B')
data=[75,70,80,70,80,90,95,70,70,75,80,80,90,95]
check(statistics.mean(data)==statistics.median(data)==80)
check(new['93b5da55-a8b7-58f0-a38c-4e4fc3d1fcb1']['correct']=='B')
z=cmath.rect(4,math.pi/3)
check(math.isclose(z.real,2) and math.isclose(z.imag,2*math.sqrt(3)))
check(new['e79575f2-6d3f-55d4-a583-f6b42f9f949e']['correct']=='A')
check((8-2)*180/8==135)
check(new['fddc7217-091d-5eb2-9649-52643c66cac0']['correct']=='A')
check([x<F(1,2) for x in [F(101,200),F(17,33),F(7,12),F(2,5)]]==[False,False,False,True])
check(new['b6763c00-7ba0-5573-a0ce-4434dd00d24c']['correct']=='D')
# Repaired SAT statements and replacement worked explanations.
check(F(90,360)*2*F(1,6)==F(1,12))
check(140**2+171**2==221**2)
check((180-115)+(180-118)==127)
check(math.isclose(math.atan2(140,171)+math.atan2(171,140),math.pi/2))
check(16*10+18**2==22**2 and F(22*18,2)==198)
check([k for k in [-8,12,39,43] if (27-k)**2<=144]==[39])
data=[91,96,88,91,84]
check(statistics.mean(data+[100])>statistics.mean(data) and statistics.median(data+[100])==statistics.median(data)==91)
check((7-2,7+2)==(5,9))
# Selected nontrivial release computations, including strict endpoints and domain.
poly=lambda x:3*x**4+5*x**3-64*x*x-164*x-80
check([poly(x) for x in [5,-4,F(-2,3)]]==[0,0,0] and poly(2)==-576)
check(F(239400,19*12)*F(4,5)==840)
check(F(134400,14*12)==800)
check(F(4500*2*2,100)==180)
A=[8,11,12,15,21,27]
check([statistics.pvariance(A)>statistics.pvariance([9,12,13,16,22,h]) for h in [23,28,29]]==[True,False,False])
check(F(52**2,2)-208*18==-2392)
check(F(21*21*9,3)==1323)
check(round(1.1*3600/1609,1)==2.5)
check([int(math.isqrt(w+85))**2==w+85 for w in [-21,15,64,315]]==[True,True,False,True])
check(36*(F(-5,9)+6)==196 and 36*F(-5,9)*6==-120)
check(F(17,16)+17==17*F(17,16))
check(15*3+34*(-8)==-227)
check(F(1,3)-F(2,11)>0)
check(F(22,44)==F(1,2))
check(F(350,500)*100==70 and F(20,50)==F(2,5))
check(F(60,1000)*100==6)
check(len(new)==12 and len({q['id'] for q in new.values()})==12)
print(f'{checks} independent mathematical checks passed')
