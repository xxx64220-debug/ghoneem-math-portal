"""Content integrity and independent exact-arithmetic checks for the EST release."""
import json,math,statistics
from collections import Counter
from pathlib import Path
from fractions import Fraction as F

root=Path(__file__).resolve().parents[1]
bank=json.loads((root/'content/est-banks-2026/reviewed-bank.json').read_text())
qs={q['assets']['source_code']:q for q in bank['questions']}
assert len(qs)==271
def check(code,value,values,tol=1e-8):
 matches=[i for i,c in enumerate(values) if abs(float(value-c))<=tol]
 assert len(matches)==1,(code,value,values)
 assert qs[code]['correct']=='ABCD'[matches[0]],(code,qs[code]['correct'],matches)

# Recompute original numerical values, independently of the prose answer key.
check('FA 004',max(abs(3*x-2) for x in [F(-1,2),F(7,2)]),[F(-7,2),F(1,2),F(7,2),F(17,2)])
check('FA 021',F(-9,10)*F(3,4),[0,1,F(-27,40),2])
check('FA 027',22*F(16,11),[16,22,32,44])
check('FA 041',math.floor((1950-79)/.44),[4250,4251,4252,4253])
check('FA 047',round(91072+16*F(94640-91072,10)),[96781,96780,96782,96779])
check('FA 061',(119+math.sqrt(119**2-4*3430))/4,[F(49,2),35,49,70])
check('DAP 001',(16*179.325-14*178.8)/2,[181,183,185,186])
check('DAP 002',6*78-5*75,[90,93,95,98])
check('DAP 006',round(10000/(1+.08/12)**60,2),[5989.30,6500.50,6680.13,6712.10])
check('DAP 007',round(13000*1.025**4,2),[13567.45,14100.24,14349.57,16544.13])
check('DAP 008',math.perm(8,5),[40,620,960,6720])
check('DAP 010',sum(all(c in '13579' for c in str(n)) for n in range(17,45)),[16,7,6,5])
check('DAP 013',round((11000-26*11*10.7)/(26*15),1),[16.6,17.8,20.4,36.1])
check('DAP 014',round(100*6/sum([2,3,2,8,6,4,2,1,11,9,3,6]),2),[3.41,5.27,9.52,10.53])
check('DAP 023',statistics.median([21,22,22,27,29])-statistics.median([12,15,15,18,20]),[5,7,13,20])
check('DAP 025',statistics.mean([20,15,30,20,10,55,60]),[20,30,60,210])
check('DAP 030',statistics.mean([1771.9,1393.34,1268.93,1251.92,1158.86]),[1137.2,1351.82,1368.99,1622.18])
check('DAP 031',round(statistics.mean([1678,2091,1245,1566,2100,1989,1888]),1),[2511.4,1888,1793.9,1672.5])
check('DAP 034',statistics.median([5,5,1,11,7,4,8,9,13,14,11,5])+5,[11,12,12.5,13.5])
check('DAP 037',round(100*(1771.9-1268.93)/1268.93,2),[-27.17,-39.64,27.17,39.64])
check('DAP 038',round(100*(2100-1245)/1245),[34,60,67,69])
check('DAP 040',2091*1.2,[4182,2509.2,2420.6,2007.6])
check('DAP 049',F(sum(n%2==0 or n%5==0 for n in range(1,51)),100),[.7,.6,.35,.3])
check('DAP 051',F(9,20)**2,[.2025,.45,.671,.90])
check('DAP 052',F(3*2*2,math.comb(7,3)),[F(12,343),F(2,35),F(72,343),F(12,35)])
check('DAP 054',F(sum(a+b<4 for a in range(1,7) for b in range(1,7)),36),[F(1,36),F(1,12),F(5,36),F(1,6)])
check('DAP 055',round(float(F(27*26,37*36)),3),[.456,.479,.501,.527])
check('DAP 056',(1393.34-1668.86)/6,[-45.92,-39.36,39.36,45.92])
check('DAP 068',round(abs(194.3*3+2020.4-2550)),[13,26,53,100])
check('DAP 071',sum([19,17,16,15,22,20,19,21,18,16,15]),[128,131,198,200])
check('DAP 072',1000*sum([4,3,3,7,9,9,9,9,7,11,5,10]),[80000,81000,84000,86000])
check('DAP 074',statistics.median([14,16,16,17,23,23,24,36,36,39,39,39,40,41]),[24,25,30,36])
assert abs((2j-3)/(1j-5)-(17-7j)/26)<1e-14
assert qs['AAF 003']['correct']=='C'
assert abs((2+1j)/(1j-7)-(-13-9j)/50)<1e-14
assert qs['AAF 005']['correct']=='A'
assert qs['AAF 007']['correct']=='C'
for x in [-3,0,F(1,2),2,7]:assert (2*x-1)**2+3*(2*x-1)-1==4*x*x+2*x-3
check('AAF 018',F(65,-8)-F(1,2),[F(-69,8),F(-65,8),F(-61,8),F(-9,2)])
check('AAF 033',2*(2*F(3,2)**3+3*F(3,2)**2-1),[4.5,12.5,25,26])
check('AAF 037',8*(F(-3,2)**3+3*F(-3,2)-1),[-225,-213,-71,-24])
assert (3-math.sqrt(9+40))/2==-2 and qs['AAF 041']['correct']=='B'
for y in map(F,[-3,-2,2,3,5]):assert 3*y/(2*y*(y+1))+4/(4*y*(y-1))==(6*y*y-2*y+4)/(4*y*(y*y-1))
assert qs['AAF 064']['correct']=='D'
check('GT 012',round(F(100,136),1),[.4,.5,.6,.7])
check('GT 014',3*(F(20,3)-3)-1,[F(8,3),8,10,12])
assert F(21,2)+22==(2*F(21,2)-3)+(F(21,2)+4) and qs['GT 021']['correct']=='A'

# The clean-bank questions have no trusted complete key; verify their calculations.
check('HOA 001',(14*F(5,7)+2)/3,[2,3,4,5])
assert all(5*x+3*(6-x)==2*x+18 for x in range(7)) and qs['HOA 002']['correct']=='B'
check('HOA 006',6/F(-2,3)-2,[11,4,-4,-11])
y=F(qs['HOA 009']['correct']);assert (3*y-2*(4-2*y))/3==(-11+3*(2+3*y))/5
check('HOA 044',5*F(2000,15),[F(400,3),F(2000,3),400,550])
check('PSD 006',F(2,3)*474,[316,158,352,238])
check('PSD 009',F(168275*156,127),[237900,208500,136993,206700])
check('PSD 010',F(3*102-7*34,7-3),[21,19,17,15])
check('PSD 011',F(11,14)*350,[75,125,175,275])
check('PSD 015',F(16*525,1)/F(7,4)/60,[70,80,125,245])
check('PSD 018',100*(F(5,4)*F(85,100)-1),[8.625,7.25,6.25,5.625])
check('PAM 002',math.sqrt(F(125,100)*F(18,10)),[F(2,3),F(3,2),F(2,5),F(5,3)])
check('PAM 003',(-2)**2-5*(-2)-6,[13,8,0,30])
check('PAM 005',F(-2+6,2),[1,2,3,4])
assert qs['PAM 010']['correct']=='7' and 4*2**2-2*2-5==7
for x,y in [(2,3),(-1,4),(3,F(1,2)),(0,8)]:assert x*(2*x*x-4*y*y)**2==4*x**5-16*x**3*y*y+16*x*y**4
assert qs['PAM 018']['correct']=='C'
check('PAM 023',2*(F(1,2)-3)*(F(1,2)+2),[2,-4.5,2.5,-12.5])
assert all(x**3-2*x*x+2*x-4==(x-2)*(x*x+2) for x in [-3,-1,0,2,5]) and qs['HOA 040']['correct']=='2'
check('GTC 002',F(54,360)*(16+36+12),[15,9.6,5.4,2.4])
assert qs['GTC 006']['correct']=='20' and 12*16/2==96 and math.hypot(12,16)==20
check('GTC 015',F(90+11-10,2+5),[F(181,7),13,-7,F(1,7)])
assert F(qs['GTC 018']['correct'])==F(1,2) and 4*F(1,2)**2+4==5

byid={q['id']:q for q in qs.values()}
full=[e for e in bank['exams'] if e['assessment_type']=='full_exam']
assert len(full)==5 and len({i for e in full for i in e['question_ids']})==250
for e in bank['exams']:
 assert len(e['question_ids'])==len(set(e['question_ids']))
 assert all(i in byid for i in e['question_ids'])
 assert not e['is_published'] and e['review_policy']=='full_review'
 if e['assessment_type']=='full_exam':
  assert len(e['question_ids'])==50 and e['duration_seconds']==4500
  assert Counter(byid[i]['assets']['domain'] for i in e['question_ids'])==Counter(FA=15,DAP=15,AAF=15,GT=5)
lessons=[e for e in bank['exams'] if e['assessment_type']=='lesson_exam']
assert len(lessons)==20 and {i for e in lessons for i in e['question_ids']}==set(byid)
for q in qs.values():
 assert 'correct' not in q['assets'] and 'explanation' not in q['assets']
 if q['type']=='mcq':assert q['correct'] in [c['key'] for c in q['choices']]
 if q['assets'].get('image'):assert (root/'web'/q['assets']['image'].split('.site/',1)[1]).is_file()
print('PASS: independent arithmetic checks, corrected source keys, 271 valid records, all lesson coverage, 5 disjoint balanced papers, 75-minute configuration, and private keys.')
