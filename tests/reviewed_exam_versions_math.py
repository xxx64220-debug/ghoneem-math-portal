"""Independent mathematical checks of each released adaptation and diagram geometry."""
import json, math, unittest, xml.etree.ElementTree as ET
from pathlib import Path
from fractions import Fraction as F
ROOT=Path(__file__).resolve().parents[1]
ROWS=json.loads((ROOT/'content-releases/20261005_reviewed_exam_versions/adaptations.json').read_text())
Q={q['code']:q for q in ROWS}
def selected(code):
 q=Q[code];return next(c['text'] for c in q['choices'] if c['key']==q['correct'])
def angle(a,b,c):
 u=(a[0]-b[0],a[1]-b[1]);v=(c[0]-b[0],c[1]-b[1])
 return math.degrees(math.acos(sum(x*y for x,y in zip(u,v))/(math.hypot(*u)*math.hypot(*v))))
def points(code):
 doc=ET.fromstring(Q[code]['assets']['svg'])
 return [(float(e.attrib['cx']),float(e.attrib['cy'])) for e in doc.iter() if e.tag.endswith('circle') and e.attrib.get('fill')=='#1264a3']
class Mathematics(unittest.TestCase):
 def test_proportion(self):self.assertEqual(int(selected('pool-dose')),F(9)*26/F('1.2'))
 def test_unique_polynomial(self):
  polys=[lambda x:x**3-x*x-6*x,lambda x:x**3+x*x-6*x,lambda x:x**3-5*x*x+6*x,lambda x:x**3-7*x-6]
  passing=[chr(65+i) for i,p in enumerate(polys) if all(p(x)==0 for x in [3,-2,0])]
  self.assertEqual(passing,[Q['factor-condition']['correct']])
 def test_spinner_enumeration(self):
  good=sum(a*b%2==0 for a in [1,2,3,4] for b in [1,2,3]);self.assertEqual(F(selected('fair-spinners')),F(good,12))
 def test_weighted_removal(self):
  mean=(30*F('15.8')+20*F('16.2')+10*F('17.2')-60)/57
  self.assertEqual(float(selected('weighted-mean')),round(float(mean),1));self.assertNotEqual(round(float(mean),1),15.9)
 def test_height(self):self.assertEqual(int(selected('replacement-height').split()[0]),3*175-160-180)
 def test_independence(self):self.assertEqual(F(selected('independent-penalties')),F(3,10)**3)
 def test_interest_rounding(self):
  implied=100*((8950.95/6000)**(1/8)-1)
  self.assertEqual(int(selected('compound-rate').strip('%')),round(implied));self.assertAlmostEqual(6000*1.05**8,8864.732662734377)
  self.assertIn('nearest whole percent',Q['compound-rate']['stem'])
 def test_coefficient_branches(self):
  solutions=[(8,F(0),F(0)),(8,F(-1,4),F(-1))]
  for a,b,c in solutions:
   for x in [-3,F(1,2),0,4]:self.assertEqual((2*a-14)*x*x+5*b-c*x,2*x*x-(4*x+5*c)*b)
  permitted=[a+8*b+c for a,b,c in solutions if b!=0]
  self.assertEqual(permitted,[F(selected('coefficient-identity'))])
 def test_chord_geometry(self):
  A,B,C,D,P=points('intersecting-chords');self.assertAlmostEqual(angle(A,P,B),80,places=2)
  self.assertEqual(int(selected('intersecting-chords').strip('°')),2*80-60)
  # The drawn chord endpoints AC and BD really intersect at P.
  for u,v in [(A,C),(B,D)]:self.assertAlmostEqual((v[0]-u[0])*(P[1]-u[1])-(v[1]-u[1])*(P[0]-u[0]),0,delta=2)
 def test_cyclic_geometry(self):
  # Stored SVG coordinates are rounded to 0.01 pixel.
  A,B,C,D=points('cyclic-quadrilateral');self.assertAlmostEqual(angle(A,B,C),110,delta=.02);self.assertAlmostEqual(angle(C,D,A),70,delta=.02)
  y=F(180-10-20,3);self.assertEqual(int(selected('cyclic-quadrilateral').strip('°')),2*y+10)
 def test_triangle_geometry(self):
  A,C,B,D=points('triangle-aa');self.assertAlmostEqual(angle(C,A,D),angle(A,B,C),places=5)
  self.assertEqual(Q['triangle-aa']['correct'],'C');self.assertIn('angle at C',selected('triangle-aa'))
 def test_decreasing(self):
  f=lambda x:x**3-6*x*x+9*x
  samples=[1+i/20 for i in range(41)];self.assertTrue(all(f(x)>f(y) for x,y in zip(samples,samples[1:])))
  self.assertTrue(f(0)<f(1) and f(3)<f(4));self.assertEqual(selected('decreasing-cubic'),'1 < x < 3')
 def test_inverse(self):
  for x in [0,.25,1,2,4,9]:self.assertAlmostEqual(math.sqrt(x*x),x);self.assertAlmostEqual(math.sqrt(x)**2,x)
  self.assertIn('y = x², x ≥ 0',selected('inverse-square-root'));self.assertIn('x ≥ 0',Q['inverse-square-root']['stem'])
 def test_rational_domain(self):
  g=lambda x:(x+2)*(x-1)*(x-3)
  self.assertEqual([x for x in range(-8,9) if g(x)==0],[-2,1,3]);self.assertIn('except −2, 1 and 3',selected('rational-domain'))
  self.assertIn('polynomial defined for every real x',Q['rational-domain']['stem'])
 def test_discrete_range(self):
  ys={6,4,2,0,2,4,6};self.assertEqual(selected('discrete-range'),'{'+', '.join(map(str,sorted(ys)))+'}')
  self.assertEqual(len(points('discrete-range')),7);self.assertIn('no connecting segments',Q['discrete-range']['stem'])
 def test_inequality_boundaries(self):
  inside=lambda x,y:x>=6 and y>=F(x,3)
  self.assertTrue(inside(6,2) and inside(9,4));self.assertFalse(inside(3,4) or inside(9,2))
  self.assertEqual(selected('included-boundaries'),'y ≥ x/3 and x ≥ 6');self.assertIn('solid',Q['included-boundaries']['stem'])
 def test_provenance_and_complete_assets(self):
  self.assertEqual(len(Q),16);self.assertEqual(sum('svg'in q['assets'] for q in ROWS),8)
  for q in ROWS:
   self.assertEqual(q['assets']['content_origin'],'instructor_adaptation');self.assertTrue(q['replaces']);self.assertTrue(q['explanation'])
   self.assertEqual(len({c['key'] for c in q['choices']}),len(q['choices']))
   if 'svg'in q['assets']:
    doc=ET.fromstring(q['assets']['svg']);self.assertIn('aria-label',doc.attrib)
    self.assertFalse(any(e.tag.endswith(('script','image','foreignObject')) for e in doc.iter()))
if __name__=='__main__':unittest.main()
