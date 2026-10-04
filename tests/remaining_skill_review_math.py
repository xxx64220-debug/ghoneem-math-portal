import json,re,unittest
from fractions import Fraction as F
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];DIR=ROOT/'content-releases/20261005_remaining_skill_review'
P=json.loads((DIR/'packet.json').read_text());Q={q['id']:q for q in json.loads((DIR/'defect-fixtures.json').read_text())}
class Review(unittest.TestCase):
 def test_bad_coordinate_and_clean_replacement(self):
  self.assertEqual(F(-2-44,1-(-3)),F('-11.5'));self.assertEqual(F(-2-4,1-(-3)),F('-1.5'))
  bad=Q['02ac14b4-f84e-6e9f-1ab3-1427f41cdef7'];self.assertTrue(all(F(c['text'].replace('—','-').replace('−','-'))!=F('-11.5') for c in bad['choices']))
 def test_explicit_expression(self):
  q=Q['53c77113-7a68-6837-4af9-b5d4594962cb'];self.assertIn('(2x − 3)(2x + 3)',q['stem']);self.assertEqual(q['correct'],'A')
  for x in [-3,0,1,4,F(1,2)]:self.assertEqual((2*x-3)*(2*x+3)-(2*x*x+x-3),2*x*x-x-6)
  self.assertNotIn('=',Q['92118004-2f60-6326-dab8-e6ad8b7911e7']['stem'])
 def test_weighted_mean_rejects_bad_key(self):
  mean=(30*F('15.8')+20*F('16.2')+10*F('17.2')-60)/57
  self.assertEqual(mean,F(910,57));self.assertEqual(round(float(mean),1),16.0)
  self.assertTrue(all(F(c['text'])!=mean for c in Q['331de3d6-88c5-6cf4-3195-fd9efc2019d6']['choices']))
 def test_new_squared_value_adaptation(self):
  q=P['adaptation'];ans=next(c['text'] for c in q['choices'] if c['key']==q['correct']);self.assertEqual(float(ans),round(float((F(4)*5/3)**2),2));self.assertIn('rounded to two decimal places',q['stem']);self.assertEqual(q['assets']['content_origin'],'instructor_adaptation')
 def test_complete_canonical_labels_without_certification(self):
  self.assertEqual(len(P['decisions']),146);self.assertEqual(len({q['id'] for q in P['decisions']}),146);self.assertEqual(sum(q['topic']!=q['before_topic'] for q in P['decisions']),19)
  canonical=json.loads(re.search(r'const MATH_LESSONS = (.*?);', (ROOT/'web/lesson-taxonomy.js').read_text(),re.S).group(1))['est']
  for q in P['decisions']:self.assertIn(q['topic'],canonical);self.assertTrue(q['skill']);self.assertNotEqual(q['skill'],'Needs classification');self.assertNotIn('answer_review_status',q)
  self.assertEqual(len(P['holds']),4);self.assertEqual(len(P['changes']),5);self.assertEqual(len({e['title'] for e in P['changes']}),5)
if __name__=='__main__':unittest.main()
