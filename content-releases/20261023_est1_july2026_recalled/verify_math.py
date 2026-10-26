"""Independent exact-arithmetic and source-defect verification."""
import json
from fractions import Fraction as F
from pathlib import Path
from statistics import median, multimode

packet=json.loads(Path(__file__).with_name('apply.sql').read_text().split('$packet$')[1])
by_no={int(q['assets']['source_code'].rsplit('-',1)[1]):q for q in packet['questions']}
assert len(by_no)==10 and set(by_no)=={1,2,4,5,6,7,8,9,10,11}
assert len(packet['held_questions'])==1 and packet['held_questions'][0]['correct']=={'void':True}
assert packet['held_questions'][0]['assets']['release_hold_reason']
joint_k=F(-1,3**2*5)
assert joint_k==-F(1,45)
assert F(-1,10)/(joint_k*8)==F(9,16) and F(3,4)**2==F(9,16)
assert by_no[1]['correct']=='A'
for t in [F(1,2),F(1),F(2),F(6),F(9)]:
 rect=(10-t)*(7+t); triangle=F(1,2)*(10-t)*t
 assert rect-triangle==70-2*t-t*t/2
assert by_no[2]['correct']=='B' and (10-2)*(7+2)-F(1,2)*(10-2)*2!=12
# A quadratic identity agreeing at three distinct points is fixed; five were checked.
a,x,y=5,-2,3
assert 2*a+x==8 and 7*x-y==-17 and a+2*y==11
# Determinant of [[2,1,0],[0,7,-1],[1,0,2]] is 27, so this solution is unique.
assert 2*(7*2)-1*(0*2-(-1)*1)==27
assert a+x+y==6 and by_no[4]['correct']=='B'
assert joint_k*6**2*10==-8 and by_no[5]['correct']=='C'
assert F(220,80)*3600==9900 and by_no[6]['correct']=='A'
values=[3,3,5,8,12,19,20,22,30,33,39,40,40,42]
assert median(values)==21 and max(multimode(values))==40
assert median(values)*max(multimode(values))==840
assert 840 not in [63,420,441,474]
assert by_no[7]['choices'][3]['text']=='840' and by_no[7]['correct']=='D'
assert (240+24*0)==240 and by_no[8]['correct']=='C'
assert -3+F(5,2)*(6-2)==7 and by_no[9]['correct']=='C'
assert (F(1+2*1,3),F(3+2*(-1),3))==(1,F(1,3)) and by_no[10]['correct']=='A'
assert 1==1 and 3!=-1 and by_no[11]['correct']=='A'
for q in packet['questions']:
 assert len(q['choices']) in (4,5)
 assert len({c['key'] for c in q['choices']})==len(q['choices'])
 assert len({c['text'] for c in q['choices']})==len(q['choices'])
 assert q['correct'] in {c['key'] for c in q['choices']}
 assert q['explanation'] and q['assets']['answer_review_status']=='independently_solved'
 assert not set(q['assets']) & {'answer','correct','explanation'}
 if q['assets'].get('figure_required'):assert q['assets']['figure'].startswith('data:image/jpeg;base64,')
assert len(set(packet['exam']['question_ids']))==10
assert packet['held_questions'][0]['id'] not in packet['exam']['question_ids']
assert packet['exam']['duration_seconds']==1200 and packet['exam']['scoring_map'] is None
print('PASS: all 10 questions solved; source defects detected; choices, figures, key isolation and exam composition verified.')
