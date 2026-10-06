"""Independent numerical, domain and graph checks for the 50-question release."""
from pathlib import Path
import base64, hashlib, json, math, re, struct
from fractions import Fraction as F
from itertools import combinations

root = Path(__file__).resolve().parents[1]
packet = json.loads((root / 'content-releases/20261006_original_est_practice/review.json').read_text())
qs = packet['questions']
checked = set()

def question(n):
    checked.add(n)
    return qs[n-1]

def numeric(s):
    s = s.replace('$', '').replace(',', '').replace('−', '-').strip()
    s = s.removeprefix(r'\(').removesuffix(r'\)')
    if re.fullmatch(r'-?\d+(\.\d+)?', s): return float(s)
    m = re.fullmatch(r'\s*\\frac\{(-?\d+)\}\{(\d+)\}\s*', s)
    if m: return float(F(int(m[1]), int(m[2])))
    m = re.fullmatch(r'(\d*)\\sqrt\{?(\d+)\}?', s)
    if m: return int(m[1] or 1)*math.sqrt(int(m[2]))
    if s == r'\frac12': return .5
    if s == r'\frac56': return 5/6
    if s == r'\frac23': return 2/3
    raise AssertionError(f'Unsupported numerical choice: {s!r}')

def number(n, result):
    q = question(n)
    matches = [c['key'] for c in q['choices'] if math.isclose(numeric(c['text']), float(result), abs_tol=1e-8)]
    assert matches == [q['correct']], (n, result, matches)

def semantic(n, predicates):
    q = question(n)
    assert len(predicates) == 4
    assert ['ABCD'[i] for i, v in enumerate(predicates) if v] == [q['correct']], n

number(1, F(7200)*F(85,100)*F(112,100))
number(2, F(324)/(F(125,100)*F(80,100)*F(108,100)))
number(3, F(102)*F(3,17))  # a:b:c = 3:4:10
number(4, F(25,10)*F(18,10)*8**2)
number(5, 5*76-4*72)
number(6, round((12*70+18*80-94-96)/28,1))
number(7, -2-F(-4,3)*6)
# Both lines imply x=5. Check all four proposed iff conditions at boundaries.
samples=[F(-2),F(-6,5),F(-1),F(0),F(6,5),F(2)]
options=[lambda m:m>F(-6,5),lambda m:m<F(-6,5),lambda m:m>F(6,5),lambda m:m<F(6,5)]
semantic(8,[all((5*m+6>0)==f(m) for m in samples) for f in options])
number(9, 13**2-12**2)
number(10, math.sqrt((13-3)**2-(11+3**2+4**2)))
# q=a(x+3)(x-1); q(-1)=-4 fixes a=1.
number(11, F(-4,(-1+3)*(-1-1))*(5+3)*(5-1))
number(12, 3+6**2/4)  # discriminant of x²-6x+k-3 is zero
number(13, 5-3)  # exponent of 2 is x+3
number(14, math.sqrt(10-1))  # (x-1)²+2x=x²+1
number(15, F(3,10)*F(6,10))
balls='RRRRBBB';pairs=list(combinations(range(7),2))
given=[p for p in pairs if any(balls[i]=='R' for i in p)]
number(16,F(sum(all(balls[i]=='R' for i in p) for p in given),len(given)))
number(17,max(x for x in range(-30,31) if abs(2*x-3)<=5))
roots=[x/2 for x in range(-30,31) if abs(x/2-2)+abs(x/2+1)==7]
assert roots == [-3,4]
number(18,sum(roots))
number(19,2*(3-2)**2-1)
def domain(n, actual, options, samples):
    semantic(n,[all(actual(x)==f(x) for x in samples) for f in options])
domain(20,lambda x:x>=-1 and x!=8,
 [lambda x:x>=-1,lambda x:x>-1 and x!=3,lambda x:x>=-1 and x!=8,lambda x:x>=0 and x!=8],[-2,-1,-.5,0,3,8,9])
number(21,F(-2**3-2,2))
# P(1)=4 => a+b=-3; P(-2)=0 => 4a-2b=2.
a=F(-2,3);b=-3-a
assert 1+a+b+6==4 and -8+4*a-2*b+6==0
number(22,27+9*a+3*b+6)
number(23,F(5,10)*26)
number(24,81*F(4,3)**3)
semantic(25,[1.5>0 and -3<0,1.5<0 and -3>0,1.5>0 and -3>0,1.5<0 and -3<0])
number(26,abs(1-4)-abs((1+2*.5)-(4-.5)))
semantic(27,[F(2,5)==F(30,12),F(3,2)==F(30,12),F(5,2)==F(30,12),F(5,4)==F(30,12)])
semantic(28,[False,(120-10*1)-(120-10*0)==-10,False,False])
semantic(29,[(x,y)==(2-1,-5) for x,y in [(1,-5),(3,-5),(2,-4),(2,-6)]])
models=[lambda x:3+x,lambda x:2*3**x,lambda x:3*2**x,lambda x:3*.5**x]
semantic(30,[all(f(x)==y for x,y in [(0,3),(1,6),(2,12)]) for f in models])
areas=[25*math.pi/4-25/2,25*math.pi/2-25/2,25*math.pi/4-25,25*math.pi-25/2]
semantic(31,[math.isclose(v,math.pi*5**2/4-5*5/2) for v in areas])
number(32,F(246)/F(82,100))
number(33,F(392)/F(112,100))
number(34,240*(F(75,10)/150)**2*10000)
number(35,40*F(3,2)**2)
number(36,(25*F(162,100)-10*F(150,100))/15)
number(37,F(20*181-2*190-6*184-7*178,5))
for n,balls,same in [(38,'BBBBBRRR',True),(39,'RRRYYK',False)]:
    pairs=list(combinations(range(len(balls)),2))
    number(n,F(sum((balls[a]==balls[b])==same for a,b in pairs),len(pairs)))
models=[lambda x:2*abs(x-1)-3,lambda x:abs(x-1)-3,lambda x:2*abs(x+1)-3,lambda x:-2*abs(x-1)-3]
semantic(40,[all(f(x)==y for x,y in [(1,-3),(3,1),(0,-1)]) for f in models])
domain(41,lambda x:x!=-1 and 3/(x+1)!=2,
 [lambda x:x!=-1,lambda x:x!=-1 and x!=.5,lambda x:x!=-1 and x!=2,lambda x:x!=.5],[-2,-1,0,.5,1,2])
domain(42,lambda x:10-x>=0 and math.sqrt(10-x)>=1,
 [lambda x:x<=10,lambda x:x<=9,lambda x:1<=x<=10,lambda x:x>=9],[-1,0,1,8,9,9.5,10,11])
domain(43,lambda x:x+7>=0 and math.sqrt(x+7)!=4,
 [lambda x:x>=-7,lambda x:x>-7 and x!=4,lambda x:x>=-7 and x!=9,lambda x:x>=0 and x!=9],[-8,-7,-6,0,4,8,9,10])
number(44,2*(-2)**3-3*(-2)**2+4*(-2)-5)
zeros=[x for x in range(-10,11) if x**3-4*x*x-7*x+10==0]
assert zeros==[-2,1,5]
number(45,max(zeros))
number(46,max(x+y for x in range(61) for y in range(41) if x+y<=80))
semantic(47,[x>=0 and y>=x and x+y<=6 for x,y in [(2,3),(4,4),(1,6),(3,1)]])
intersections=[(x,2*x-1) for x in range(-8,9) if x*x-4==2*x-1]
assert intersections==[(-1,-3),(3,5)]
number(48,math.dist(*intersections))
number(49,math.sqrt(math.dist((-2,1),(3,1))**2-9))
semantic(50,[50>50,50==50 and 65-35>58-42,50==50 and 58-42>65-35,65-35==58-42])

assert checked==set(range(1,51)) and len(qs)==50
assert len({q['id'] for q in qs})==50
assert len({q['stem'] for q in qs})==50
assert len({q['assets']['source_code'] for q in qs})==50
for n,q in enumerate(qs,1):
    assert q['track_id']=='est' and q['topic']!='Sequences'
    assert [c['key'] for c in q['choices']]==list('ABCD')
    assert len({c['text'] for c in q['choices']})==4
    assert q['explanation'].strip() and q['stem'].strip()
    assert q['assets']['content_origin']=='instructor_authored'
    assert not any(k in q['assets'] for k in ['correct','answer','explanation','figure_review'])
    for s in [q['stem'],q['explanation']]+[c['text'] for c in q['choices']]:
        assert s.count(r'\(')==s.count(r'\)'),(n,s)
    if n>24: assert q['assets']['idea_reference']['url'].startswith('https://')
    if 'figure' in q['assets']:
        data=base64.b64decode(q['assets']['figure'].split(',',1)[1],validate=True)
        assert data[:8]==b'\x89PNG\r\n\x1a\n'
        assert struct.unpack('>II',data[16:24])==(936,624)
        assert hashlib.sha256(data).hexdigest()==q['assets']['figure_sha256']
        assert q['assets']['figure_required'] and q['review_figure_spec']['caption']
assert sum('figure' in q['assets'] for q in qs)==13
# Check the drawn tangent point is on the circle and its radius is perpendicular.
spec=qs[48]['review_figure_spec'];o=spec['center'];p=spec['tangent_point'];t=spec['external_point']
assert math.isclose(math.dist(o,p),3) and math.isclose(math.dist(t,p),4)
assert math.isclose(sum((p[i]-o[i])*(t[i]-p[i]) for i in range(2)),0,abs_tol=1e-9)
print('PASS: all 50 independently solved, unique choices, domains, conditional enumeration, graph models, PNG hashes and private answer separation')
