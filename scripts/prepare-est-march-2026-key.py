"""Teacher-authorized worked key. Private source; never copy to dist or web."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'content/est-march-2026'
manifest=json.loads((folder/'manifest.json').read_text())
void={'void':True}
solutions=[
 ('B','The total ratio is 1 + 2 + 4 = 7. Yasmine receives 2/7 of $14,000 = $4,000.'),
 ('C','In order: 1, 5, 6, 6, 7, 7, 7, 9, 9, 10. The median is the mean of the fifth and sixth entries: (7 + 7)/2 = 7.'),
 ('D','The Hyundai revenue covers 14 cars for 12 months. Monthly rent per car = 134,400/(14 × 12) = $800.'),
 (void,'Excluded from scoring: the Honda revenue is printed as 117,00. Reading it as 11,700 gives total revenue 470,940 and 11% tax of 51,803.4, which is not offered. Assuming a missing zero gives 117,000, total 576,240 and tax 63,386.4 (D), but that changes the source. No student is penalized for this defective item.'),
 ('B','Original monthly Jeep rent = 239,400/(19 × 12) = $1,050. After a 20% discount: 1,050 × 0.80 = $840.'),
 ('A','Assuming independent shots, the probability of scoring all three is 0.3 × 0.3 × 0.3 = 0.027.'),
 ('B','OFFICE has six letters with F repeated twice. Distinct arrangements = 6!/2! = 360.'),
 ('C','Slope = (4 − 3)/(1 − (−9)) = 1/10. Using (1,4), the intercept is 4 − 0.1 = 3.9. Therefore y = 0.1x + 3.9.'),
 ('A','f(1) = −3(1 + 4) − 4(1)² = −19. g(1) = 2 − 1 + 1 = 2. The quotient is −19/2 = −9.5.'),
 ('C','There are 101 + 60 = 161 boys out of 101 + 60 + 125 + 34 = 320 students. Probability = 161/320 = 0.503125, approximately 0.503.'),
 ('C','Given that the student is local, use only the locals column: 101 boys out of 101 + 125 = 226 locals. Probability = 101/226 ≈ 0.447.'),
 ('A','A 40% increase multiplies the original price by 1.40. Original price = 308/1.40 = $220.'),
 ('B','By the factor theorem, P(5) = 0, P(−4) = 0, and P(−2/3) = 0, so choices A, C, and D are factors. P(2) = −576, so x − 2 is not a factor.'),
 ('B','Simple interest = principal × annual rate × years = 4,500 × 0.02 × 2 = $180.'),
 ('B','The sum is 7k + (k + 10) + (3k + 2) + (4k − 4) = 15k + 8. An average of 5 for four numbers means a sum of 20, so 15k = 12 and k = 0.8.'),
 ('D','The sector has radius 6 cm and angle 40°. Its perimeter is two radii plus arc length: 12 + (40/360)(2π × 6) ≈ 16.19 cm.'),
 ('D','Each book contains 400 − 4 = 396 non-defective pages. There are 230 × 5 = 1,150 copies. Total = 396 × 1,150 = 455,400 pages.'),
 ('B','For real values, the denominator requires y > 0. The expression simplifies to 5|a|/(y√y). Rationalizing gives 5|a|√y/y², which is B.'),
 ('C','|3x − 5| + 1 = 2 gives |3x − 5| = 1, so x = 2 or x = 4/3. The listed solution is x = 2.'),
 ('D','For ax² + bx + c, the symmetry axis is x = −b/(2a). Here x = 20/8 = 2.5.'),
 ('D','3x − 1 ≥ −10 gives x ≥ −3, while x + 4 < −6 gives x < −10. No number satisfies both, so the solution set is empty.'),
 ('A','The midpoint y-coordinate is the mean of the endpoint y-values: (−5 + 11)/2 = 3.'),
 (['B','D'],'Both B and D are accepted. B gives |3x + 7| < 4, or −11/3 < x < −1, an interval containing infinitely many real numbers. D gives |−4x + 1| > −5, true for every real number because an absolute value is nonnegative. The printed question therefore has two valid answers.'),
 ('B','Combining cubic terms gives (3a + 1)x³ + 4bx² + x. The cubic coefficient must be zero: 3a + 1 = 0, so a = −1/3. For the result actually to be quadratic, b must also be nonzero.'),
 ('C','When a = 1, the cubic coefficient is 3a + 1 = 4. The quadratic coefficient is 4b. Equating them gives 4b = 4, hence b = 1.'),
 ('D','The slope from (2,5) to (7,15) is 10/5 = 2, so y = 2x + 1. At x = 5, a = 11. Therefore 2a = 22.'),
 ('A','Use proportionality: 9 gallons for 1.2 m³ means 9/1.2 = 7.5 gallons per m³. For 26 m³: 7.5 × 26 = 195 gallons.'),
 ('C','Sphere volume = (4/3)πr³ = (4/3)π(12³) = 2,304π, so k = 2,304.'),
 ('C','The polynomial factors as (x + 4)(x − 2)(x − 3). Its negative root is −4, whose absolute value is 4.'),
 ('A','3x − 4 ≤ 1 gives x ≤ 5/3. The greatest positive integer satisfying this is 1.'),
 ('D','Percent increase = (34 − 20)/20 × 100 = 70%. Therefore m = 70.'),
 ('A','(f + g)(x) = (2x + 1) + (−3x + 1) = −x + 2. At x = 1, the value is 1.'),
 ('D','3x − 7 = 20 gives x = 9. Therefore 2x = 18.'),
 ('C','Substitute y = 6 into x + 5y = 33 to get x = 3. Then ax + 3y = 24 becomes 3a + 18 = 24, so a = 2.'),
 (void,'Excluded from scoring: the printed points are A(−3,44) and B(1,−2). Their slope is (−2 − 44)/(1 − (−3)) = −46/4 = −11.5. None of the four choices equals −11.5. The original points and choices remain unchanged.'),
 ('C','Convert to grams: 0.05674 × 1,000 = 56.74 g. Rounding to the nearest gram gives 57 g.'),
 ('B','The discriminant is b² − 4ac = (−3)² − 4(3)(1) = 9 − 12 = −3.'),
 ('C','Use 25 = 5² and 125 = 5³. Equate the exponents: 2(3x − 1) = 3x. Thus 6x − 2 = 3x, giving x = 2/3.'),
 ('A','The graphed line rises from left to right, so a perpendicular line must have a negative slope. Among the two negative-slope choices, only y = −2x + 2 passes through (1,0): −2(1) + 2 = 0.'),
 ('C','The vertex x-coordinate is −(−4)/(2 × −2) = −1. Then f(−1) = −2 + 4 + 1 = 3. Since the parabola opens downward, the highest point is (−1,3).'),
 ('B','Substitute x = −1 and y = −2: |2(−1) − 3(−2)| + 4(−2) = |4| − 8 = −4.'),
 ('C','From the graph, f(−6) = 1 and g(−1) = 3. Their sum is 4.'),
 ('D','The graph of g is above y = 3 between x = −3 and x = −1. The strict inequality excludes both endpoints, giving (−3,−1).'),
 ('A','Expand: (2i + 5)(i − 1) = 2i² − 2i + 5i − 5. Since i² = −1, this becomes −7 + 3i.'),
 ('A','From 2x + 3yx + 1 = 4x², isolate 3xy = 4x² − 2x − 1. Divide by 3x to get y = (4x² − 2x − 1)/(3x). The original equation has no solution at x = 0.'),
 ('A','x² = (√3 − 1)² = 4 − 2√3. Thus 3x² − x + 6√3 = 12 − 6√3 − √3 + 1 + 6√3 = 13 − √3.'),
 ('C','In right triangle ADC, DC = √(15² − 9²) = 12 cm. In right triangle BDC, BD = √(20² − 12²) = 16 cm. Hence AB = 9 + 16 = 25 cm and the area is (1/2)(25)(12) = 150 cm².'),
 ('C','The distance is √[(3 − 1)² + (−2 − (−1))²] = √(4 + 1) = √5, so k = 5.'),
 ('A','Divisibility by x + 1 requires P(−1) = 0. Thus −3 + 2 + m = 0, so m = 1.'),
 ('B','3x + 1 < 10 gives x < 3. The positive integers satisfying this are 1 and 2, whose product is 2.'),
]
assert len(solutions)==50
rows=[{'number':q['number'],'question_id':q['id'],'correct':ans,'explanation':exp.replace('$','USD ')}
      for q,(ans,exp) in zip(manifest['questions'],solutions)]
key={'exam_id':'67a68471-59b3-5bf1-8a80-21ce851bef5f','provenance':'Independently worked from the uploaded paper; teacher-authorized, not an official EST key.',
     'question_count':50,'scored_question_count':48,'excluded_questions':[4,35],
     'source_sha256':manifest['source_sha256'],'questions':rows}
(folder/'worked-answer-key.json').write_text(json.dumps(key,ensure_ascii=False,indent=2)+'\n')
print('Prepared 50 explained entries: 47 single answers, 1 multiple-answer key, 2 excluded items.')
