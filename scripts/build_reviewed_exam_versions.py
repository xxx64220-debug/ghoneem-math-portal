"""Build explicit instructor adaptations; never reconstruct unknown source diagrams."""
from pathlib import Path
import json, math, uuid, html

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'content-releases/20261005_reviewed_exam_versions'
load=lambda name:json.loads((OUT/(name+'.json')).read_text())
old=load('before'); exams=load('exams'); guards=load('guards'); lessons={q['id']:q['lesson'] for q in load('lessons')}
uid=lambda text:str(uuid.uuid5(uuid.NAMESPACE_URL,'ghoneem:20261005:reviewed:'+text))
def text(x,y,s,size=15,anchor='middle'):
 return f'<text x="{x:.2f}" y="{y:.2f}" font-size="{size}" text-anchor="{anchor}" fill="#15263d">{html.escape(str(s))}</text>'
def line(a,b,color='#243e5c',width=2):
 return f'<line x1="{a[0]:.2f}" y1="{a[1]:.2f}" x2="{b[0]:.2f}" y2="{b[1]:.2f}" stroke="{color}" stroke-width="{width}"/>'
def circle(p,r=4,color='#1264a3'):
 return f'<circle cx="{p[0]:.2f}" cy="{p[1]:.2f}" r="{r}" fill="{color}"/>'
def svg(body,w=420,h=330,label='Instructor practice diagram'):
 return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="100%" role="img" aria-label="{html.escape(label)}"><rect x="0" y="0" width="{w}" height="{h}" fill="white"/>{body}</svg>'
def axes(xmin,xmax,ymin,ymax,w=420,h=300,ticksx=(),ticksy=()):
 left,right,top,bottom=48,w-26,25,h-40
 xy=lambda x,y:(left+(x-xmin)/(xmax-xmin)*(right-left),bottom-(y-ymin)/(ymax-ymin)*(bottom-top))
 body=line(xy(xmin,0),xy(xmax,0),'#708196',1)+line(xy(0,ymin),xy(0,ymax),'#708196',1)
 for x in ticksx:
  p=xy(x,0);body+=line((p[0],p[1]-4),(p[0],p[1]+4),'#708196',1)+text(p[0],p[1]+20,x,12)
 for y in ticksy:
  p=xy(0,y);body+=line((p[0]-4,p[1]),(p[0]+4,p[1]),'#708196',1)+text(p[0]-10,p[1]+4,y,12,'end')
 body+=text(right-1,xy(0,0)[1]-8,'x',13)+text(xy(0,0)[0]+14,top+2,'y',13)
 return xy,body
def curve(fn,xy,xmin,xmax,ymin,ymax):
 pieces=[];current=[]
 for i in range(501):
  x=xmin+(xmax-xmin)*i/500;y=fn(x)
  if ymin<=y<=ymax:current.append(xy(x,y))
  elif current:pieces.append(current);current=[]
 if current:pieces.append(current)
 return ''.join('<polyline points="'+' '.join(f'{x:.2f},{y:.2f}' for x,y in p)+'" fill="none" stroke="#1264a3" stroke-width="2.5"/>' for p in pieces if len(p)>1)
def circle_diagram(kind):
 center=(200,165);r=115
 point=lambda deg:(center[0]+r*math.cos(math.radians(deg)),center[1]-r*math.sin(math.radians(deg)))
 angles={'A':0,'B':60,'C':180,'D':280} if kind=='chords' else {'A':150,'B':220,'C':290,'D':0}
 pts={k:point(v) for k,v in angles.items()}
 b=f'<circle cx="200" cy="165" r="115" fill="none" stroke="#708196" stroke-width="2"/>'
 for k,p in pts.items():
  deg=angles[k];b+=circle(p)+text(p[0]+18*math.cos(math.radians(deg)),p[1]-18*math.sin(math.radians(deg))+5,k)
 if kind=='chords':
  b+=line(pts['A'],pts['C'])+line(pts['B'],pts['D'])
  # Actual intersection of AC and BD, calculated from the plotted coordinates.
  a,c=pts['B'],pts['D'];t=(165-a[1])/(c[1]-a[1]);p=(a[0]+t*(c[0]-a[0]),165)
  b+=circle(p,3)+text(p[0]-9,p[1]+22,'P')+text(p[0]+33,p[1]-17,'80°',14)+text(318,80,'arc AB = 60°',13)
 else:
  for a,c in [('A','B'),('B','C'),('C','D'),('D','A')]:b+=line(pts[a],pts[c])
  b+=text(144,231,'(2y + 10)°',14)+text(274,164,'(y + 20)°',14)
 return svg(b,label='Intersecting chords AC and BD' if kind=='chords' else 'Cyclic quadrilateral ABCD')
def similarity_diagram():
 A,C,B,D=(75,50),(75,260),(355,260),(232.5,260)
 b=line(A,C)+line(C,B)+line(B,A)+line(A,D)
 for name,p in [('A',A),('C',C),('B',B),('D',D)]:b+=circle(p,3)+text(p[0]+(-14 if name in ['A','C'] else 0),p[1]+(-10 if name=='A' else 22),name)
 b+=text(240,38,'∠CAD = ∠ABC',15)+line((75,244),(91,244),width=1)+line((91,244),(91,260),width=1)
 return svg(b,label='Triangle ACB with D between C and B; specified equal angles')
def function_diagram(kind):
 if kind=='decreasing':
  xy,b=axes(-1,4.6,-2,8,ticksx=(0,1,2,3,4),ticksy=(2,4,6,8));b+=curve(lambda x:x*(x-3)**2,xy,-1,4.6,-2,8)
  for x,y in [(1,4),(3,0)]:b+=circle(xy(x,y))+text(xy(x,y)[0]+25,xy(x,y)[1]-12,f'({x}, {y})',12)
 elif kind=='domain':
  xy,b=axes(-3.2,4.2,-16,16,ticksx=(-3,-2,-1,0,1,2,3,4),ticksy=(-10,10));b+=curve(lambda x:(x+2)*(x-1)*(x-3),xy,-3.2,4.2,-16,16)
  for x in [-2,1,3]:b+=circle(xy(x,0))
 else:
  xy,b=axes(-.5,6.7,-.7,7,ticksx=(0,1,2,3,4,5,6),ticksy=(2,4,6))
  for x,y in [(0,6),(1,4),(2,2),(3,0),(4,2),(5,4),(6,6)]:b+=circle(xy(x,y),4.5)
 return svg(b,420,300,label={'decreasing':'Graph of x cubed minus 6x squared plus 9x','domain':'Graph of (x+2)(x-1)(x-3)','range':'Seven discrete points, with no connecting lines'}[kind])
def inverse_diagram():
 panels=[('Given: f(x) = √x',lambda x:math.sqrt(x),0,4),('A: y = √x, x ≥ 0',lambda x:math.sqrt(x),0,4),('B: y = x², x ≤ 0',lambda x:x*x,-2,0),('C: y = x², x ≥ 0',lambda x:x*x,0,2),('D: y = −√x, x ≥ 0',lambda x:-math.sqrt(x),0,4)]
 b=''
 for i,(name,fn,lo,hi) in enumerate(panels):
  gx=122 if i==0 else (0 if i%2 else 244);gy=0 if i==0 else (185 if i<3 else 370)
  xy,a=axes(-2.5,4.5,-2.5,4.5,232,165,ticksx=(0,2,4),ticksy=(-2,2,4));a+=curve(fn,xy,lo,hi,-2.5,4.5)
  b+=f'<g transform="translate({gx} {gy+22})">{a}</g>'+text(gx+116,gy+18,name,16)
 return svg(b,488,560,label='Given square root function and four labeled candidate inverse graphs')
def inequality_diagram():
 xy,b=axes(-.5,12.5,-.5,6.8,ticksx=(0,3,6,9,12),ticksy=(2,4,6))
 poly=[xy(6,2),xy(12.5,12.5/3),xy(12.5,6.8),xy(6,6.8)]
 b+='<polygon points="'+' '.join(f'{x:.2f},{y:.2f}' for x,y in poly)+'" fill="#d1e8fa"/>'+line(xy(0,0),xy(12.5,12.5/3))+line(xy(6,-.5),xy(6,6.8))
 b+=circle(xy(6,2))+text(xy(6,2)[0]-12,xy(6,2)[1]+26,'(6, 2)',12)+text(xy(9,5.7)[0],xy(9,5.7)[1],'Shaded region',12)
 return svg(b,420,300,label='Shading above y=x/3 and right of x=6; both boundaries solid')

definitions=[]
def add(code,track,old_ids,lesson,idea,stem,options,key,explanation,diagram=None,reason='Clarify an ambiguous source item in an explicitly authored adaptation.'):
 choices=[{'key':chr(65+i),'text':s} for i,s in enumerate(options)]
 definitions.append({'id':uid(code),'code':code,'track_id':track,'topic':lesson,'difficulty':'medium','type':'mcq','stem':stem,'choices':choices,'correct':key,'explanation':explanation,'assets':{'source':'Eng Abdelrahman Ghoneem — reviewed instructor adaptation','source_question_id':'GH-REVIEW-20261005-'+code,'source_ids_adapted':old_ids,'content_origin':'instructor_adaptation','adaptation_reason':reason,'curriculum_lesson':lesson,'lesson_subtopic':idea,'lesson_taxonomy_version':'20260929','verified_release':'20261005-reviewed-exam-versions','answer_review_status':'independently_solved',**({'svg':diagram,'figure_required':True,'figure_caption':'Instructor-created diagram from the explicit mathematical givens; not a recovered source image.'} if diagram else {})},'replaces':old_ids})
def ids(prefix):return [q['id'] for q in old if re_stem(q['stem']).startswith(prefix)]
def re_stem(s):
 import re
 return re.sub(r'^Q\d+\.\s*','',s).replace('\n',' ')
add('pool-dose','est',ids('A 1.2 m³ pool'),'Ratios, percentages and unit conversion','Direct proportion','A pool treatment requires 9 millilitres of concentrate for every 1.2 cubic metres of water. At the same dosing rate, how many millilitres are required for 26 cubic metres of water?',['195','202','223','234'],'A','A. The dosing rate is 9 ÷ 1.2 = 7.5 millilitres per cubic metre. For 26 cubic metres, 7.5 × 26 = 195 millilitres. These are different quantities related by a dosing rate, not an invalid conversion between gallons and cubic metres.')
add('factor-condition','est',ids('If x − 3 and x + 2'),'Quadratics and polynomials','Factors and polynomial roots','The polynomial p(x) has factors x − 3 and x + 2, and p(0) = 0. Which expression could be p(x)?',['x³ − x² − 6x','x³ + x² − 6x','x³ − 5x² + 6x','x³ − 7x − 6'],'A','A. The three required roots are 3, −2 and 0. Choice A factors as x(x − 3)(x + 2). B fails at x = 3, C fails at x = −2, and D has p(0) = −6. The added p(0) = 0 condition makes A uniquely correct.')
add('fair-spinners','est',ids('Spinner 1 has sections'),'Probability and conditional probability','Independent equally likely outcomes','Two fair spinners have equal-sized sectors. Spinner 1 has sectors labeled 1, 2, 3, 4, and Spinner 2 has sectors labeled 1, 2, 3. They are spun independently once each. What is the probability that the product is even?',['1/4','1/3','1/2','2/3','3/4'],'D','D. There are 4 × 3 = 12 equally likely ordered sector pairs. An odd product needs both labels odd: 2 × 2 = 4 pairs. Thus P(even product) = 1 − 4/12 = 2/3.')
add('weighted-mean','est',ids('A teacher gives a test'),'Statistics and data analysis','Weighted mean after removing observations','Class A has 30 students with a mean test score of 15.8; Class B has 20 students with a mean of 16.2; Class C has 10 students with a mean of 17.2. One student from each class scored 20. After removing those three scores, what is the mean of the remaining scores, rounded to one decimal place?',['15.1','16.0','16.2','16.7'],'B','B. The original sum is 30(15.8) + 20(16.2) + 10(17.2) = 970 for 60 students. Removing three scores of 20 leaves 910 for 57 students. The new mean is 910/57 = 15.964912…, which rounds to 16.0, not 15.9.')
add('replacement-height','est',ids('Three people have heights'),'Statistics and data analysis','Mean with one replacement','Three people have heights 160 cm, 170 cm and 180 cm. The person who is 170 cm tall leaves and another person joins. The new mean height is 175 cm. What is the new person’s height?',['165 cm','170 cm','172 cm','185 cm','190 cm'],'D','D. The two remaining people have a total height of 160 + 180 = 340 cm. A mean of 175 for three people requires a total of 525 cm. The newcomer is 525 − 340 = 185 cm tall. The departing person is now explicitly identified.')
add('independent-penalties','est',ids('P(scoring a penalty)'),'Probability and conditional probability','Independent repeated trials','A player has a 0.3 probability of scoring on each penalty shot. The results of the shots are independent. What is the probability that the player scores on all three of three shots?',['0.027','0.343','0.540','0.90'],'A','A. Independence allows multiplication: 0.3 × 0.3 × 0.3 = 0.027. Without independence, the individual success probability would not determine the probability of three successes.')
add('compound-rate','est',ids('Nada invests'),'Exponents, radicals and growth','Compound interest and rounding','Nada invests $6,000 in an account with interest compounded annually. After 8 years the balance is $8,950.95. What is the annual interest rate, rounded to the nearest whole percent?',['3%','1%','5%','7%'],'C','C. If r is the decimal rate, 6000(1 + r)⁸ = 8950.95. Thus r = (8950.95/6000)^(1/8) − 1 ≈ 0.0512711, or 5.12711%. Rounded to the nearest whole percent, this is 5%. At an exact 5% rate the balance would be about $8,864.73; the rounding condition is essential.')
add('coefficient-identity','est',ids('(2a − 14)'),'Quadratics and polynomials','Matching coefficients with a nonzero condition','For every real x, (2a − 14)x² + 5b − cx = 2x² − (4x + 5c)b, where a, b and c are constants and b ≠ 0. What is a + 8b + c?',['11','7','5','3'],'C','C. Comparing coefficients gives 2a − 14 = 2, c = 4b, and 5b = −5bc. Therefore a = 8 and b(1 + c) = 0. Since b ≠ 0, c = −1 and b = −1/4. The value is 8 + 8(−1/4) − 1 = 5. The excluded b = 0 branch would instead give 8.')
find=lambda source:[q['id'] for q in old if q['assets'].get('source_question_id')==source]
add('intersecting-chords','est2',find('T7-08'),'Circles','Angles formed by intersecting chords','Points A, B, C and D lie on a circle in that order. Chords AC and BD intersect at P inside the circle. The measure of ∠APB is 80° and the measure of minor arc AB is 60°. What is the measure of minor arc CD?',['20°','40°','80°','100°'],'D','D. An angle formed by intersecting chords is half the sum of its intercepted opposite arcs. Thus 80 = (60 + m(arc CD))/2, giving m(arc CD) = 160 − 60 = 100°. The chord endpoints and intercepted arcs are explicitly identified.',circle_diagram('chords'))
add('cyclic-quadrilateral','est2',find('T7-07'),'Circles','Opposite angles in a cyclic quadrilateral','ABCD is a quadrilateral inscribed in a circle. Its interior angle B measures (2y + 10)° and its opposite interior angle D measures (y + 20)°. What is the measure of angle B?',['50°','60°','80°','110°'],'D','D. Opposite interior angles of an inscribed quadrilateral sum to 180°. Hence (2y + 10) + (y + 20) = 180, so y = 50 and angle B = 110°. Angle D is 70°, confirming a total of 180°. This is a newly specified cyclic-quadrilateral exercise, not a reconstruction of the missing parallel-chord source.',circle_diagram('cyclic'))
add('triangle-aa','est2',find('T9-34'),'Triangles and similarity','AA similarity','In triangle ACB, D lies between C and B on segment CB, and ∠CAD = ∠ABC. Which statement correctly justifies △ACD ∼ △BCA?',['∠CAD = ∠ABC and AD is a common side','∠CAD = ∠ABC and AC is a common side','∠CAD = ∠ABC and the angle at C is common','None of these'],'C','C. Since D lies on segment CB, rays CD and CB coincide, so ∠ACD = ∠BCA. Together with the given ∠CAD = ∠ABC, there are two matching angles, proving similarity by AA with correspondence A ↔ B, C ↔ C, D ↔ A. A common side alone does not establish similarity.',similarity_diagram())
add('decreasing-cubic','est2',find('T7-28'),'Functions and transformations','Increasing and decreasing intervals','The graph shows f(x) = x³ − 6x² + 9x. On which listed interval is f strictly decreasing?',['−5 < x < 1','1 < x < 3','x > 3','x < 3'],'B','B. The graph falls from its local maximum (1,4) to its local minimum (3,0), so it decreases on 1 < x < 3. Independently, f′(x) = 3(x − 1)(x − 3), which is negative exactly between 1 and 3 and positive outside. No calculus is needed to read the plotted interval.',function_diagram('decreasing'))
add('inverse-square-root','est2',find('T7-21'),'Functions and transformations','Inverse functions and domain restrictions','The given function is f(x) = √x for x ≥ 0. Which labeled graph represents its inverse?',['Graph A: y = √x, x ≥ 0','Graph B: y = x², x ≤ 0','Graph C: y = x², x ≥ 0','Graph D: y = −√x, x ≥ 0'],'C','C. Swapping x and y in y = √x gives x = √y, so y = x² with x ≥ 0. The inverse domain is the original range [0,∞). Choice B has the wrong domain, A repeats f and D has nonpositive outputs. Composition confirms √(x²) = x for x ≥ 0.',inverse_diagram())
add('rational-domain','est2',find('T6-11'),'Functions and transformations','Domain of a rational function','Let k(x) be a polynomial defined for every real x, and let g(x) = (x + 2)(x − 1)(x − 3), whose graph is shown. The function f is defined by f(x) = k(x)/g(x), using this original quotient. What is the domain of f?',['All real numbers','All real numbers except −1 and 2','All real numbers except −1, 1 and 3','All real numbers except −2, 1 and 3','The domain cannot be determined'],'D','D. The numerator is defined for all real x. The original quotient is undefined where g(x) = 0, namely x = −2, 1 and 3. Those values remain excluded even if a common factor could later be canceled. Every other real value is allowed.',function_diagram('domain'))
add('discrete-range','est2',find('T9-19'),'Functions and transformations','Range of a discrete function','The entire graph of F consists only of the seven plotted points (0,6), (1,4), (2,2), (3,0), (4,2), (5,4) and (6,6). There are no connecting segments. Which set is the range of F?',['{y: y ≥ 0}','{y: 0 ≤ y ≤ 6}','{x: 0 ≤ x ≤ 6}','{0, 2, 4, 6}','{0, 1, 2, 3, 4, 5, 6}'],'D','D. The range is the set of output values at the plotted points: 6, 4, 2, 0, 2, 4, 6. Removing repeated values gives {0,2,4,6}. Values between the dots are not included, because the graph has no connecting segments.',function_diagram('range'))
add('included-boundaries','est2',find('T10-10'),'Linear equations and inequalities','Systems of inequalities from a graph','Both boundary lines in the graph are solid. One passes through (0,0) and (6,2); the other is x = 6. The shaded region lies above the sloping line and to the right of the vertical line, including both boundaries. Which system describes it?',['y ≥ x/3 and x ≥ 6','y ≥ 3x and x ≥ 6','y ≤ x/3 and x ≥ 6','y ≥ 3x and x ≤ 6','y ≥ x/3 and x ≤ 6'],'A','A. The sloping line has slope (2 − 0)/(6 − 0) = 1/3 and intercept 0. Above and including it means y ≥ x/3. Right of and including x = 6 means x ≥ 6. For example, (9,4) satisfies both, while (3,4) and (9,2) each fail one condition.',inequality_diagram())

mapping={oldid:q['id'] for q in definitions for oldid in q['replaces']}
mapping['3556fa31-7c75-76db-d8d7-9ee22d7c3867']='10fab705-da9f-6719-ec0d-3297d5afae40'
mapping['492aa09e-a370-8678-c92c-43dbf5eafce1']='57dcf00a-7933-8695-addb-d22c1045f6d7'
assert len(definitions)==16 and len(mapping)==26
gex={x['id']:x for x in guards['exams']}; changes=[]
for e in exams:
 newids=[mapping.get(q,q) for q in e['question_ids']]
 assert len(newids)==len(set(newids))==len(e['question_ids']),e['title']
 for q in newids:assert q not in mapping
 if e['track_id']=='est2':title=e['title'].replace('Math Level 2','Math')
 else:
  ls=sorted(set(lessons[q] for q in e['question_ids'] if lessons.get(q)))
  prefix=ls[0] if len(ls)==1 else 'Mixed skills'
  import re
  suffix=re.search(r'(?:Reviewed practice|Source-corrected practice)(.*)$',e['title'])
  title='EST I — '+prefix+' — Practice'+(suffix.group(1) if suffix else '')
 title+=' — Corrected 5 Oct 2026'
 history=gex[e['id']]['has_history']
 full=e['track_id']=='est2' and 'Full Practice Exam' in e['title']
 changes.append({'old_id':e['id'],'new_id':uid('exam:'+e['id']) if history else e['id'],'has_history':history,'title':title,'question_ids':newids,'assessment_type':'full_exam' if full else e['assessment_type'],'max_attempts':1 if full else e['max_attempts'],'is_full_length':True if full else e['is_full_length'],'historical_title':e['title']+' — Historical version (held)' if history else None})
for name,value in [('adaptations',definitions),('mapping',mapping),('exam-changes',changes)]:
 (OUT/(name+'.json')).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
print(f'Built {len(definitions)} reviewed adaptations, {len(mapping)} substitutions, {len(changes)} corrected assessments; {sum(c["has_history"] for c in changes)} retain historical versions.')

# SQL uses PostgreSQL-generated fingerprints of the actual live records.
dump=lambda o:json.dumps(o,ensure_ascii=False,separators=(',',':'))
literal=lambda s:"'"+s.replace("'","''")+"'"
extra=load('extra-interest-before')
payload={'questions':definitions,'exams':changes,'guards':guards,'extra':extra}
sql=r'''begin;
create table if not exists portal_private.exam_review_20261005_backup(
 kind text not null,id uuid not null,new_id uuid,before_row jsonb,after_hash text,
 primary key(kind,id)
);
alter table portal_private.exam_review_20261005_backup enable row level security;
revoke all on portal_private.exam_review_20261005_backup from public,anon,authenticated;
grant all on portal_private.exam_review_20261005_backup to service_role;
do $release$
declare data_ jsonb:=__PAYLOAD__;p jsonb;q public.questions%rowtype;k public.question_keys%rowtype;
 e public.exams%rowtype;n public.exams%rowtype;expected_ text;h text;extra_ jsonb;hold_ text;
begin
 if exists(select 1 from portal_private.exam_review_20261005_backup) then raise exception 'Review release already applied'; end if;
 -- Freeze membership/history briefly, including insertions, before deciding which versions can change.
 lock table public.exams,public.assignments,public.attempts in share row exclusive mode;
 for p in select value from jsonb_array_elements(data_->'guards'->'questions') loop
  select * into q from public.questions where id=(p->>'id')::uuid for update;
  select * into k from public.question_keys where question_id=q.id for update;
  h:=md5(jsonb_build_object('q',to_jsonb(q),'k',to_jsonb(k))::text);
  if h is distinct from p->>'hash' then raise exception 'Concurrent question change: %',p->>'id';end if;
 end loop;
 for p in select value from jsonb_array_elements(data_->'guards'->'exams') loop
  select * into e from public.exams where id=(p->>'id')::uuid for update;
  if md5(to_jsonb(e)::text) is distinct from p->>'hash' then raise exception 'Concurrent exam change: %',p->>'id';end if;
  if exists(select 1 from public.attempts a where a.exam_id=e.id) is distinct from (p->>'has_history')::boolean
  then raise exception 'Concurrent history change: %',e.id;end if;
  select md5(coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb)::text) into h from public.assignments a where a.exam_id=e.id;
  if h is distinct from p->>'assignment_hash' then raise exception 'Concurrent assignment change: %',e.id;end if;
 end loop;
 for p in select value from jsonb_array_elements(data_->'questions') loop
  if exists(select 1 from public.questions where id=(p->>'id')::uuid) then raise exception 'Adaptation ID already exists';end if;
  insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
  values((p->>'id')::uuid,p->>'track_id',p->>'topic',p->>'difficulty',p->>'type',p->>'stem',p->'choices',p->'assets');
  insert into public.question_keys(question_id,correct,explanation) values((p->>'id')::uuid,p->'correct',p->>'explanation');
  select md5(jsonb_build_object('q',to_jsonb(q2),'k',to_jsonb(k2))::text) into h from public.questions q2 join public.question_keys k2 on k2.question_id=q2.id where q2.id=(p->>'id')::uuid;
  insert into portal_private.exam_review_20261005_backup(kind,id,after_hash) values('adaptation',(p->>'id')::uuid,h);
 end loop;
 -- A separately discovered unused copy also asserts a false 5% balance. Preserve its key/history and hold it.
 extra_:=data_->'extra';
 select * into q from public.questions where id=(extra_->'q'->>'id')::uuid for update;
 select * into k from public.question_keys where question_id=q.id for update;
 if md5(jsonb_build_object('q',to_jsonb(q),'k',to_jsonb(k))::text) is distinct from extra_->>'hash' then raise exception 'Concurrent interest-copy change';end if;
 if exists(select 1 from public.revision_items where question_id=q.id) then raise exception 'Interest copy revision state changed';end if;
 insert into portal_private.exam_review_20261005_backup(kind,id,before_row) values('held_copy',q.id,to_jsonb(q));
 hold_:='Exact 5% gives 6000×1.05^8 = 8864.732662734377, not 8950.95. The exact implied rate is approximately 5.1271123%; the prompt does not specify rounding to a whole percent. Replaced by the explicitly rounded instructor adaptation.';
 update public.questions set assets=assets||jsonb_build_object('release_hold_reason',hold_,'hold_recheck_date','2026-10-05','hold_recheck_note',hold_,'replacement_question_id','__INTEREST_ID__') where id=q.id;
 select md5(to_jsonb(q2)::text) into h from public.questions q2 where q2.id=q.id;
 update portal_private.exam_review_20261005_backup set after_hash=h where kind='held_copy' and id=q.id;
 for p in select value from jsonb_array_elements(data_->'exams') loop
  select * into e from public.exams where id=(p->>'old_id')::uuid for update;
  if not portal_private.exam_content_ready(array(select jsonb_array_elements_text(p->'question_ids')::uuid),e.track_id)
  then raise exception 'Replacement contains ineligible content: %',e.id;end if;
  insert into portal_private.exam_review_20261005_backup(kind,id,new_id,before_row) values('exam',e.id,(p->>'new_id')::uuid,to_jsonb(e));
  if (p->>'has_history')::boolean then
   n:=e;n.id:=(p->>'new_id')::uuid;n.title:=p->>'title';n.created_at:=now();
   n.assessment_type:=p->>'assessment_type';n.max_attempts:=(p->>'max_attempts')::integer;n.is_full_length:=(p->>'is_full_length')::boolean;
   n.question_ids:=array(select jsonb_array_elements_text(p->'question_ids')::uuid);
   insert into public.exams select n.*;
   insert into public.assignments(exam_id,group_id,user_id,open_at,close_at)
   select n.id,a.group_id,a.user_id,a.open_at,a.close_at from public.assignments a where a.exam_id=e.id;
   update public.exams set title=p->>'historical_title' where id=e.id;
  else
   update public.exams set question_ids=array(select jsonb_array_elements_text(p->'question_ids')::uuid),title=p->>'title',assessment_type=p->>'assessment_type',max_attempts=(p->>'max_attempts')::integer,is_full_length=(p->>'is_full_length')::boolean where id=e.id;
  end if;
  select md5(to_jsonb(e2)::text) into h from public.exams e2 where e2.id=e.id;
  update portal_private.exam_review_20261005_backup set after_hash=h where kind='exam' and id=e.id;
  insert into public.audit_log(action,target_type,target_id,meta) values('exam.reviewed_version_20261005','exam',e.id::text,
   jsonb_build_object('new_id',p->>'new_id','historical_version_retained',p->'has_history','question_count',cardinality(e.question_ids)));
 end loop;
 if (select count(*) from portal_private.exam_review_20261005_backup where kind='exam')<>30
 or (select count(*) from portal_private.exam_review_20261005_backup where kind='adaptation')<>16 then raise exception 'Incomplete review packet';end if;
end $release$;
commit;
'''.replace('__PAYLOAD__',literal(dump(payload))+'::jsonb').replace('__INTEREST_ID__',uid('compound-rate'))
(OUT/'apply.sql').write_text(sql)
rollback=r'''begin;
do $rollback$
declare b portal_private.exam_review_20261005_backup%rowtype;e public.exams%rowtype;q public.questions%rowtype;k public.question_keys%rowtype;added_ uuid[];
begin
 lock table public.exams,public.assignments,public.attempts in share row exclusive mode;
 if (select count(*) from portal_private.exam_review_20261005_backup where kind='exam')<>30 then raise exception 'Incomplete review backup';end if;
 select array_agg(id) into added_ from portal_private.exam_review_20261005_backup where kind='adaptation';
 if exists(select 1 from public.daily_quizzes where question_ids&&added_)
 or exists(select 1 from public.practice_drills where question_ids&&added_)
 or exists(select 1 from public.practice_notebook where question_id=any(added_))
 or exists(select 1 from public.revision_items where question_id=any(added_))
 or exists(select 1 from public.revision_sessions s cross join lateral jsonb_array_elements(s.snapshot) j where j->>'id'=any(array(select a::text from unnest(added_) a)))
 then raise exception 'Adaptations are in practice history; rollback must preserve them';end if;
 for b in select * from portal_private.exam_review_20261005_backup where kind='exam' order by id loop
  select * into e from public.exams where id=b.id for update;
  if md5(to_jsonb(e)::text)<>b.after_hash then raise exception 'Exam edited after release';end if;
  if exists(select 1 from public.attempts where exam_id=b.new_id) then raise exception 'Corrected version has attempts; rollback requires preserving new history';end if;
 end loop;
 for b in select * from portal_private.exam_review_20261005_backup where kind='adaptation' order by id loop
  select * into q from public.questions where id=b.id for update;select * into k from public.question_keys where question_id=q.id for update;
  if md5(jsonb_build_object('q',to_jsonb(q),'k',to_jsonb(k))::text)<>b.after_hash then raise exception 'Adaptation edited after release';end if;
 end loop;
 for b in select * from portal_private.exam_review_20261005_backup where kind='exam' order by id loop
  if b.new_id<>b.id then delete from public.assignments where exam_id=b.new_id;delete from public.exams where id=b.new_id;end if;
  e:=jsonb_populate_record(null::public.exams,b.before_row);
  -- Old held versions cannot be republished through the modern eligibility trigger.
  -- Their unchanged publication flag is retained; only membership/title are restored.
  if b.new_id=b.id then
   -- Refuse to weaken the publish guard. A rollback to held content keeps this unused version as a draft.
   update public.exams set is_published=false where id=e.id;
   update public.exams set question_ids=e.question_ids,title=e.title,assessment_type=e.assessment_type,max_attempts=e.max_attempts,is_full_length=e.is_full_length where id=e.id;
  else update public.exams set title=e.title where id=e.id;end if;
 end loop;
 for b in select * from portal_private.exam_review_20261005_backup where kind='held_copy' loop
  select * into q from public.questions where id=b.id for update;
  if md5(to_jsonb(q)::text)<>b.after_hash then raise exception 'Held copy edited after release';end if;
  update public.questions set assets=b.before_row->'assets' where id=b.id;
 end loop;
 delete from public.question_keys where question_id in(select id from portal_private.exam_review_20261005_backup where kind='adaptation');
 delete from public.questions where id in(select id from portal_private.exam_review_20261005_backup where kind='adaptation');
 delete from portal_private.exam_review_20261005_backup;
end $rollback$;
commit;
'''
(OUT/'rollback.sql').write_text(rollback)
