"""Build explicit editorial revision labels against a current bank snapshot.

Usage: python scripts/build-final-revision.py /path/to/revision-work
Snapshot is private working input, never shipped to the web directory.
The manifest has IDs/labels only; answers remain server-side.
"""
import json,re,sys,hashlib
from pathlib import Path
from collections import Counter
ROOT=Path(__file__).resolve().parents[1]
WORK=Path(sys.argv[1]); OUT=ROOT/'content/final-revision-2026-09-27'
OUT.mkdir(exist_ok=True,parents=True)
sat=json.loads((WORK/'sat-selected.json').read_text())
est=json.loads((WORK/'est-selected.json').read_text())
labels={}
def estgroup(prefix,numbers,lesson,idea,level='medium',scope=None):
 for n in numbers.split():
  code=f'{prefix} {int(n):03}'
  assert code not in labels,code
  labels[code]=dict(lesson=lesson,idea=idea,difficulty=level,programmes=scope or ['sat','est'])

# Each group was assigned from the full prompt and worked solution, rather than
# copying the old broad topic or default medium difficulty.
groups=[
('AAF','1','Absolute value','Graph transformations','medium'),
('AAF','2 47 53 74','Quadratics','Axis of symmetry','easy'),
('AAF','3 5','Complex numbers','Conjugates and division','medium',['est']),
('AAF','6 7 15 18','Function composition and inverses','Composing functions','medium',['est']),
('AAF','16 17 20 44','Functions and graphs','Evaluating functions','easy'),
('AAF','8 9 10','Exponents and radicals','Equations with a common base','medium'),
('AAF','11','Exponents and radicals','Equations with a common base','easy'),
('AAF','12','Exponential models','Compound growth','medium'),
('AAF','13','Polynomials','Factor theorem','medium'),
('AAF','14 71','Polynomials','Factoring expressions','medium'),
('AAF','19','Absolute value','Nested absolute value equations','hard'),
('AAF','21 34','Polynomials','Roots and zero-product property','medium'),
('AAF','23 24','Nonlinear systems','Line and parabola intersections','medium'),
('AAF','25','Nonlinear systems','Intersections and quadrants','hard'),
('AAF','26 27 28','Function composition and inverses','Finding and evaluating inverses','medium',['est']),
('AAF','29','Exponents and radicals','Exponent rules and substitution','medium'),
('AAF','31','Exponents and radicals','Evaluating radicals','easy'),
('AAF','32 64','Rational expressions and equations','Comparing coefficients in rational identities','hard'),
('AAF','33 37','Polynomials','Remainder theorem with a nonmonic divisor','medium'),
('AAF','38','Polynomials','Remainder theorem','easy'),
('AAF','35','Polynomials','Coefficients in products','medium'),
('AAF','36','Polynomials','Combining like terms','easy'),
('AAF','39 40 42 54','Quadratics','Sum and product of roots','easy'),
('AAF','41','Quadratics','Solving by factoring','easy'),
('AAF','43','Quadratics','Completing the square and checking claims','hard'),
('AAF','45','Quadratics','Function values and multiple inputs','hard'),
('AAF','46','Quadratics','Connecting a parabola to geometry','hard'),
('AAF','48 50','Quadratics','Reading a parabola graph','medium'),
('AAF','49','Quadratics','Range and minimum value','medium'),
('AAF','51','Quadratics','Constructing a quadratic from points','hard'),
('AAF','52','Quadratics','Vertex form','medium'),
('AAF','55','Quadratic inequalities','Sign of a quadratic','hard',['est']),
('AAF','58 59','Exponents and radicals','Simplifying radicals','medium'),
('AAF','61','Rational expressions and equations','Range restrictions','hard',['est']),
('AAF','62','Rational expressions and equations','Solving rational equations','medium'),
('AAF','63','Rational expressions and equations','Simplifying rational expressions','medium'),
('AAF','66 73','Rational expressions and equations','Excluded values','easy'),
('AAF','69 70','Rearranging formulas','Isolating a variable in a radical formula','medium'),
('DAP','1 2 29','Statistics','Mean and missing values','medium'),
('DAP','3 12 20 26 62 63 64 65 66 67 71 72','Graphs and data interpretation','Reading and comparing data','easy'),
('DAP','4 14 27 38 45 46 47 75','Percentages','Percentages from charts and tables','medium'),
('DAP','5','Statistics','Reading a median from a box plot','easy'),
('DAP','6','Exponential models','Present value and monthly compounding','hard'),
('DAP','7','Exponential models','Annual compound interest','medium'),
('DAP','9','Counting methods','Combinations','medium',['est']),
('DAP','10','Counting methods','Systematic counting','easy',['est']),
('DAP','13','Ratios, rates and units','Multistep work and pay rates','hard'),
('DAP','16 18','Variation','Direct variation with powers','medium'),
('DAP','17','Variation','Direct proportionality','easy'),
('DAP','19','Probability','Expected frequency','easy'),
('DAP','21','Lines and linear models','Interpreting an intercept','easy'),
('DAP','22 23','Statistics','Quartiles and interquartile range','easy'),
('DAP','24','Variation','Inverse variation','medium'),
('DAP','25 30 31','Statistics','Mean from graphs and tables','easy'),
('DAP','28 69','Scatterplots and models','Predictions from a best-fit line','medium'),
('DAP','32','Statistics','Weighted mean','medium'),
('DAP','33','Statistics','Comparing mean, median and mode','hard'),
('DAP','34 74','Statistics','Median and mode','medium'),
('DAP','35 36 40','Percentages','Percent increase and decrease','easy'),
('DAP','39','Percentages','Reverse percentages','medium'),
('DAP','41 44','Percentages','Multistep percentages','hard'),
('DAP','43','Percentages','Percent of a percent','easy'),
('DAP','48 50 51','Probability','Favourable outcomes and sample spaces','easy'),
('DAP','49','Probability','Union and overlapping events','medium'),
('DAP','52 55','Probability','Sampling without replacement','hard'),
('DAP','53','Probability','Conditional probability','medium'),
('DAP','54','Probability','Two-dice sample space','medium'),
('DAP','56','Lines and linear models','Average rate of change','medium'),
('DAP','57 58','Ratios, rates and units','Rates and unit conversion','medium'),
('DAP','59 60 61','Ratios, rates and units','Part-to-part and part-to-whole ratios','easy'),
('DAP','68','Scatterplots and models','Residuals: observed versus predicted','medium'),
('DAP','70','Scatterplots and models','Slope of a best-fit line','medium'),
('FA','1 2','Absolute value','Solving absolute value equations','easy'),
('FA','3','Absolute value','Intercepts of absolute value graphs','easy'),
('FA','4','Absolute value','Maximum under an absolute value constraint','hard'),
('FA','5 6','Absolute value','Interpreting absolute value inequalities','medium',['est']),
('FA','7 29','Lines and linear models','Collinear points','medium'),
('FA','8','Lines and linear models','Comparing linear costs','medium'),
('FA','9','Rational expressions and equations','Simplifying complex fractions','medium'),
('FA','10 38 42','Linear inequalities','Compound inequalities and integer solutions','medium'),
('FA','11','Rearranging formulas','Substitution in a radical formula','medium'),
('FA','13 72','Linear inequalities','Regions and systems of inequalities','hard'),
('FA','14 15 54','Lines and linear models','Interpreting slope and intercept','easy'),
('FA','16 66 67 73 74','Linear systems','Elimination and substitution','medium'),
('FA','17 60','Expressions and number properties','Reasoning about signs and magnitudes','hard'),
('FA','18 19 21 22','Linear equations','Solving equations with fractions','easy'),
('FA','20 23','Linear equations','Translating word problems','medium'),
('FA','24 77','Linear equations','Building a linear equation','easy'),
('FA','25 41','Linear inequalities','Maximum whole-number solutions','medium'),
('FA','26','Linear equations','No-solution conditions','medium'),
('FA','27','Linear equations','Solving for a parameter','medium'),
('FA','28','Lines and linear models','Unknown inputs in linear tables','hard'),
('FA','30 31 55 57','Lines and linear models','Parallel and perpendicular lines','medium'),
('FA','32 33','Lines and linear models','Perpendicular lines with extra constraints','hard'),
('FA','34 36 63 64','Lines and linear models','Slope from equations, points and graphs','easy'),
('FA','35 50','Lines and linear models','Unknown coefficients from a point','medium'),
('FA','37','Lines and linear models','Finding an intercept','medium'),
('FA','39 40 43 44','Linear inequalities','Solving and testing inequalities','easy'),
('FA','46 48','Lines and linear models','Evaluating a linear model','easy'),
('FA','47 49','Lines and linear models','Linear models from data','medium'),
('FA','51 52 53','Linear equations','Equivalent expressions from an equation','easy'),
('FA','56','Percentages','Percent as a multiplier','easy'),
('FA','58 59','Polynomials','Expanding and comparing coefficients','medium'),
('FA','61','Quadratics','Sum and product word problems','hard'),
('FA','62','Ratios, rates and units','Speed, distance and changing travel time','hard'),
('FA','65','Linear systems','Parameter systems and uniqueness','hard'),
('FA','68 76','Linear systems','Infinitely many solutions','medium'),
('FA','69 70 75','Linear systems','Two-variable word problems','medium'),
('FA','71','Linear systems','Elimination with parameters','hard'),
('FA','78','Lines and linear models','Vertical lines and undefined slope','easy'),
('GT','1 16','Right triangles and trigonometry','Special right triangles','easy'),
('GT','2','Circles','Points inside, on and outside a circle','medium'),
('GT','3 5','Circles','Radius from coordinates','medium'),
('GT','4','Circles','Inscribed angles and arcs','hard'),
('GT','6','Area and volume','Area from coordinates','hard'),
('GT','8','Angles, triangles and similarity','Multistep angle reasoning','hard'),
('GT','9 10 18 20 21','Angles, triangles and similarity','Interior and exterior angles','medium'),
('GT','11 19','Right triangles and trigonometry','Similarity and trigonometry together','hard'),
('GT','12','Right triangles and trigonometry','Sine and cosine ratios','medium'),
('GT','13','Angles, triangles and similarity','Segment addition','easy'),
('GT','14','Angles, triangles and similarity','Similar triangles and parallel lines','medium'),
('GT','15','Area and volume','Cross-section area','hard'),
('GT','17','Area and volume','Square area from a diagonal','easy'),
('GT','23','Area and volume','Volume with side-length ratios','medium'),
('GTC','2','Circles','Sector area and circle equations','hard'),
('GTC','14','Right triangles and trigonometry','Sine ratio','easy'),
('GTC','15','Right triangles and trigonometry','Complementary-angle identities','medium'),
('HOA','1','Linear equations','Solving linear equations','easy'),
('HOA','2 36','Lines and linear models','Building a linear cost or score model','medium'),
('HOA','6 43','Lines and linear models','Slope with unknown coordinates','hard'),
('HOA','35','Linear inequalities','Testing an ordered pair','easy'),
('HOA','44','Linear inequalities','Optimising under two constraints','hard'),
('PAM','2','Exponents and radicals','Products of radicals','easy'),
('PAM','3','Function composition and inverses','Composing functions','medium',['est']),
('PAM','5','Quadratics','Axis of symmetry from roots','easy'),
('PAM','12','Functions and graphs','Transforming known function values','hard'),
('PAM','18','Polynomials','Factoring a perfect square','hard'),
('PAM','23','Quadratics','Vertex from factored form','medium'),
('PSD','1','Variation','Inverse-square variation','medium'),
('PSD','2','Scatterplots and models','Correlation versus causation','medium'),
('PSD','6 9 11','Ratios, rates and units','Part-to-whole ratios and unit rates','easy'),
('PSD','10','Ratios, rates and units','Ratios after adding members','hard'),
('PSD','15','Ratios, rates and units','Work rate and time conversion','medium'),
('PSD','18','Percentages','Successive percentage changes','medium'),
]
for g in groups:estgroup(*g)
excluded={'AAF 060':'Real-domain assumption is incomplete at x=0; omit.',
 'DAP 008':'Selection versus assignment of cards is not explicit; omit.',
 'DAP 073':'A box plot does not uniquely determine distribution shape; omit.',
 'GT 007':'Worked explanation incorrectly calls the given parallelogram a rectangle; omit.'}

# SAT indices refer to the deterministic UUID-sorted snapshot selected by topic.
satlabels={}
def satgroup(indices,lesson,idea,level):
 for i in map(int,indices.split()):
  assert i not in satlabels,i
  satlabels[i]=dict(lesson=lesson,idea=idea,difficulty=level,programmes=['sat','est'])
for g in [
('0 57','Statistics','Comparing standard deviation','medium'),
('1','Rational expressions and equations','Comparing coefficients in rational identities','hard'),
('2','Exponential models','Reading intercepts from equivalent forms','hard'),
('3','Ratios, rates and units','Converting area units','medium'),
('4 11 96','Circles','Radians and degrees','easy'),
('5','Angles, triangles and similarity','Congruent triangles and corresponding sides','medium'),
('6 46','Statistical inference','Finding a margin of error','easy'),
('7 34 64 95 100 119','Area and volume','Area of basic plane figures','easy'),
('8','Statistical inference','Interpreting an estimate interval','medium'),
('9 35 54','Angles, triangles and similarity','Similarity with multiple constraints','hard'),
('10 19','Exponential models','Interpreting growth factor and initial value','easy'),
('12','Polynomials','Factoring with unknown coefficients','hard'),
('13','Circles','Radius and diameter','easy'),
('14 61 78','Circles','Center and radius from an equation','easy'),
('15','Angles, triangles and similarity','Proving lines parallel','medium'),
('16 120','Linear systems','Two-variable word problems','medium'),
('17','Statistics','Effect of removing an extreme value','medium'),
('18 109','Angles, triangles and similarity','Angle-angle similarity','medium'),
('20','Ratios, rates and units','Length and speed unit conversion','easy'),
('21','Right triangles and trigonometry','Triangle area using sine','medium'),
('22','Statistical inference','Sample size and margin of error','hard'),
('23','Circles','Semicircle arcs and circumference','easy'),
('24 65','Circles','Circle equations with parameters','hard'),
('25 27 55 69 77','Lines and linear models','Interpreting and evaluating linear models','easy'),
('26 102','Linear inequalities','Modelling constraints','medium'),
('28','Absolute value','No-solution conditions','easy'),
('29 67 90 114','Area and volume','Volume formulas','easy'),
('30','Nonlinear systems','Line and circle intersections','hard'),
('31 73 82 117','Area and volume','Length, area and volume scale factors','medium'),
('32','Lines and linear models','Perpendicular slope','easy'),
('33 115','Probability','Conditional probability','hard'),
('36','Circles','Arc length','medium'),
('37 75 122','Right triangles and trigonometry','Similarity and Pythagorean constraints','hard'),
('38','Polynomials','Coefficient sums through substitution','hard'),
('39 72','Scatterplots and models','Equation of a best-fit line','medium'),
('40 88','Linear systems','No-solution conditions','medium'),
('41','Graphs and data interpretation','Selecting data and finding a mean','medium'),
('42 71','Linear equations','Equivalent expressions from an equation','easy'),
('43','Functions and graphs','Vertical translations','easy'),
('44','Exponential models','Range and number of intercepts','hard'),
('45','Exponential models','Unknown constants from two points','medium'),
('47','Quadratics','Vertex form and unknown coefficients','hard'),
('48 106','Exponential models','Time intervals in growth and decay','medium'),
('49 111','Lines and linear models','Constructing models with parameters','medium'),
('50','Linear equations','Unique-solution conditions','medium'),
('51','Right triangles and trigonometry','Complementary angles in radians','hard'),
('52','Polynomials','Combining like terms','easy'),
('53','Area and volume','Pyramid surface area and height','hard'),
('56 79 123','Percentages','Multistep percentages','hard'),
('58 103','Right triangles and trigonometry','Pythagorean theorem','easy'),
('59 98','Percentages','Percent increase versus growth factor','medium'),
('60','Right triangles and trigonometry','Special right triangles','medium'),
('62','Quadratics','Solving a height model','medium'),
('63','Quadratics','Discriminant with integer parameters','hard'),
('66','Quadratics','Quadratic formula','medium'),
('68','Linear systems','Infinitely many solutions with parameters','hard'),
('70 112','Polynomials','Roots and zero-product property','medium'),
('74','Linear systems','Substitution','easy'),
('76 80 108','Circles','Distance and completing the square','medium'),
('81','Exponents and radicals','Comparing fractional exponents','hard'),
('83 113','Polynomials','Expanding and comparing coefficients','medium'),
('84','Linear equations','Mixture models','medium'),
('85','Graphs and data interpretation','Reading a frequency graph','easy'),
('86','Percentages','Percentage enlargement and scale','hard'),
('87','Circles','Extreme coordinates on a circle','medium'),
('89','Angles, triangles and similarity','Parallelogram angles','medium'),
('91','Rearranging formulas','Isolating a variable with multiple powers','hard'),
('92','Circles','Circumference and whole-number constraints','medium'),
('93','Ratios, rates and units','Rates with variables and unit conversion','medium'),
('94','Area and volume','Area from coordinates','hard'),
('97','Statistical inference','Effect of increasing sample size','medium'),
('99','Lines and linear models','Change in distance from a graph','medium'),
('101','Scatterplots and models','Predictions from a best-fit line','medium'),
('104','Statistics','Combining mean, median and range','hard'),
('105','Statistical inference','Random assignment and causal inference','medium'),
('107 110','Angles, triangles and similarity','Angle relationships','easy'),
('116','Linear inequalities','Feasible regions and quadrants','hard'),
('118','Exponents and radicals','Equations with a common base','medium'),
('121','Linear equations','Solving linear equations','easy'),
]:satgroup(*g)
assert len(satlabels)==len(sat)==124
for i in [6,8,22,46,97,105]:satlabels[i]['programmes']=['sat']
# Full sine-area formula is EST extension; common SAT right-triangle skills
# remain in both programmes.
satlabels[21]['programmes']=['est']
rows=[]
for q in est:
 code=q['assets']['source_code']
 if code in excluded:continue
 assert code in labels,code
 rows.append(dict(id=q['id'],source='est',source_code=code,**labels[code]))
for i,q in enumerate(sat):rows.append(dict(id=q['id'],source='sat',source_code=q['assets'].get('code',str(i)),**satlabels[i]))
# Collapse exact content copies across banks, preserving the first reviewed ID.
pool={q['id']:q for q in est+sat};seen={};unique=[];duplicates=[]
for r in rows:
 q=pool[r['id']]
 signature=re.sub(r'\s+',' ',q['stem']).strip().lower()+json.dumps(q['choices'],sort_keys=True)
 if signature in seen:duplicates.append({'id':r['id'],'same_as':seen[signature]});continue
 seen[signature]=r['id'];unique.append(r)
rows=unique
fingerprints={r['id']:r['fingerprint'] for r in json.loads((WORK/'fingerprints.json').read_text())}
for r in rows:r['fingerprint']=fingerprints[r['id']]
assert all(q['explanation'].strip() for q in pool.values())
(OUT/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
(OUT/'exclusions.json').write_text(json.dumps({'additional_exclusions':excluded,'exact_duplicates':duplicates},indent=2)+'\n')
audit={'questions':len(rows),'sources':dict(Counter(r['source'] for r in rows)),'difficulty':dict(Counter(r['difficulty'] for r in rows)),
 'lessons':len({r['lesson'] for r in rows}),'ideas':len({(r['lesson'],r['idea']) for r in rows}),
 'coverage':[{'lesson':l,'questions':sum(r['lesson']==l for r in rows),'ideas':sorted({r['idea'] for r in rows if r['lesson']==l})} for l in sorted({r['lesson'] for r in rows})]}
(OUT/'audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in audit.items() if k!='coverage'}))
