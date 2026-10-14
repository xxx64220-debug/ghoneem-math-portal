import json,pathlib,unittest
from fractions import Fraction as F
root=pathlib.Path(__file__).resolve().parents[1]
packet=json.loads((root/'content-releases/20261005_est_source_evidence/patches.json').read_text())
class SourceEvidenceMath(unittest.TestCase):
 def test_recovered_polynomial(self):
  # Three distinct inputs uniquely identify a quadratic, including each distractor.
  expression=lambda x:(2*x-3)*(2*x+3)-(2*x*x+x-3)
  options=[lambda x:2*x*x-x-6,lambda x:2*x*x-x+6,lambda x:2*x*x+x-6,lambda x:4*x*x-x-6]
  self.assertEqual([i for i,v in enumerate(options) if all(expression(x)==v(x) for x in [-2,0,3])],[0])
 def test_source_slope_not_clean_copy(self):
  self.assertEqual(F(-2-44,1+3),F(-23,2));self.assertNotIn(F(-23,2),[F('-1.5'),F('0.5'),F('1'),F('1.5')])
 def test_two_source_means_remain_invalid(self):
  mean=(30*F('15.8')+20*F('16.2')+10*F('17.2')-60)/57
  self.assertEqual(mean,F(910,57));self.assertEqual(round(float(mean),1),16.0)
  self.assertNotIn(mean,list(map(F,['50.7','15.9','15.1','48.2'])))
 def test_recovered_power_has_approximate_option(self):
  value=(F(4)*5/3)**2;self.assertEqual(value,F(400,9));self.assertEqual(round(float(value),2),44.44)
  self.assertNotIn(value,list(map(F,['44.44','6.667','25','9'])))
 def test_compound_interest_no_exact_choice(self):
  self.assertAlmostEqual(100*((8950.95/6000)**(1/8)-1),5.1271123,places=6)
  self.assertAlmostEqual(6000*1.05**8,8864.732662734377)
  self.assertTrue(all(abs(6000*(1+r/100)**8-8950.95)>0.01 for r in [3,1,5,7]))
 def test_duplicates_count_and_ratio(self):
  self.assertEqual(4550*F(2,7)-105,1195)
  self.assertEqual(sum(n%2==1 and n//100%2==0 for n in range(100,1000)),200)
 def test_independence_cannot_be_inferred(self):
  self.assertNotEqual(F('0.3')**3,F('0.3'));self.assertEqual(1-F(2,4)*F(2,3),F(2,3))
 def test_complete_manifest_and_holds(self):
  self.assertEqual(len(packet),12);self.assertEqual(len({p['id'] for p in packet}),12)
  for p in packet:
   ev=p['asset_patch']['source_recovery_evidence'];self.assertEqual(len(ev['file_sha256']),64)
   self.assertGreater(ev['physical_page'],0);self.assertIn('note',ev)
  self.assertEqual(sum('choices' in p for p in packet),3)
if __name__=='__main__':unittest.main()
