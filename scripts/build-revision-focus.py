"""Curate focus collections from the reviewed revision manifest.
Run: python scripts/build-revision-focus.py /path/to/revision-work
"""
from pathlib import Path
from collections import Counter,defaultdict
import json,re,sys
root=Path(__file__).resolve().parents[1]
out=root/'content/final-revision-2026-09-27'
rows=json.loads((out/'manifest.json').read_text())
byid={r['id']:r for r in rows}
counts=Counter((r['lesson'],r['idea']) for r in rows)
selected=defaultdict(list)
reasons={}
# Foundations are editorial priorities. These patterns select named skills,
# not all questions in a large lesson or a claim about official frequency.
essential={
 'Linear equations': ['Solving.*equations','Building a linear equation','Translating word problems','No-solution conditions','Unique-solution conditions','Equivalent expressions from an equation'],
 'Lines and linear models':['Slope from equations','Interpreting slope and intercept','Parallel and perpendicular lines','Linear models from data','Vertical lines'],
 'Linear systems':['Elimination and substitution','No-solution conditions','Infinitely many solutions$','Two-variable word problems'],
 'Linear inequalities':['Solving and testing inequalities','Compound inequalities','Modelling constraints'],
 'Absolute value':['Solving absolute value equations','No-solution conditions'],
 'Quadratics':['Solving by factoring','Quadratic formula','Vertex form$','Sum and product of roots','Axis of symmetry$','Range and minimum value','Discriminant with integer parameters'],
 'Polynomials':['Combining like terms','Factoring expressions','Expanding and comparing coefficients','Roots and zero-product property','Factor theorem','Remainder theorem$'],
 'Exponents and radicals':['Equations with a common base','Simplifying radicals','Comparing fractional exponents'],
 'Rational expressions and equations':['Excluded values','Solving rational equations','Simplifying rational expressions'],
 'Rearranging formulas':['Isolating a variable in a radical formula'],
 'Functions and graphs':['Evaluating functions','Vertical translations'],
 'Exponential models':['Interpreting growth factor and initial value','Time intervals in growth and decay'],
 'Ratios, rates and units':['Part-to-part and part-to-whole ratios','Part-to-whole ratios and unit rates','Rates and unit conversion','Converting area units'],
 'Variation':['Direct proportionality','Inverse variation$'],
 'Percentages':['Percent as a multiplier','Percent increase and decrease','Reverse percentages','Successive percentage changes'],
 'Statistics':['Mean and missing values','Median and mode','Quartiles and interquartile range','Comparing standard deviation'],
 'Graphs and data interpretation':['Reading and comparing data'],
 'Scatterplots and models':['Predictions from a best-fit line','Correlation versus causation','Residuals: observed versus predicted'],
 'Probability':['Favourable outcomes and sample spaces','Conditional probability','Sampling without replacement'],
 'Area and volume':['Area of basic plane figures','Volume formulas','Length, area and volume scale factors'],
 'Circles':['Center and radius from an equation','Distance and completing the square','Arc length','Sector area and circle equations'],
 'Angles, triangles and similarity':['Interior and exterior angles','Angle-angle similarity'],
 'Right triangles and trigonometry':['Pythagorean theorem','Sine and cosine ratios','Special right triangles','Complementary-angle identities'],
 'Statistical inference':['Finding a margin of error','Effect of increasing sample size','Random assignment and causal inference'],
 'Complex numbers':['Conjugates and division'],
 'Function composition and inverses':['Composing functions','Finding and evaluating inverses'],
 'Counting methods':['Combinations'],
 'Quadratic inequalities':['Sign of a quadratic'],
 'Nonlinear systems':['Line and parabola intersections'],
 'Expressions and number properties':['Reasoning about signs and magnitudes'],
}
for lesson,patterns in essential.items():
 for pattern in patterns:
  candidates=[r for r in rows if r['lesson']==lesson and re.search(pattern,r['idea'])]
  assert candidates,(lesson,pattern)
  r=min(candidates,key=lambda r:({'easy':0,'medium':1,'hard':2}[r['difficulty']],r['id']))
  if 'must_know' not in selected[r['id']]:selected[r['id']].append('must_know')
  reasons[r['id']]='Core skill: '+r['idea']+'.'
# >=4 distinct reviewed question records sharing an exact lesson/idea label.
# Published mock reuse does NOT count as another occurrence.
for r in rows:
 if counts[(r['lesson'],r['idea'])]>=4:selected[r['id']].append('repeated')

unique_est={
 'FA 004':'Optimise an expression after converting an absolute value constraint to an interval.',
 'FA 028':'Extend linear patterns using input differences, even when the starting input is unknown.',
 'FA 032':'Use the product of perpendicular slopes to relate unknown coefficients.',
 'FA 053':'Recognise a multiple of the given expression instead of solving for each variable.',
 'FA 062':'Translate changed travel times into linked rate equations.',
 'FA 065':'Test a simple candidate and justify that a parameter system has a unique solution.',
 'AAF 019':'Resolve nested absolute values in stages and count every real solution.',
 'AAF 032':'Clear denominators and match coefficients in a rational identity.',
 'AAF 045':'A quadratic output may correspond to more than one input.',
 'AAF 046':'Combine geometric dimensions and symmetry with a parabola equation.',
 'AAF 058':'Simplify each radical before doing unnecessary fraction algebra.',
 'AAF 061':'Find an excluded output by rearranging the function relation.',
 'DAP 041':'Track percentages of the remaining group rather than the original whole.',
 'DAP 052':'Count unordered colour selections without double-counting their possible orders.',
 'GT 019':'Recognise similar right triangles formed by two altitudes.',
 'HOA 044':'Find the highest feasible point under two linear constraints.',
 'PAM 012':'Transform known function values without inventing unknown inputs.',
 'PSD 010':'When members join, both the part and the whole can change.',
}
unique_sat={
 9:'Combine a symmetry axis, a 30-degree triangle, and similarity.',
 12:'Treat factor coefficients as unknowns and retain both possible coefficient pairs.',
 24:'Relate concentric-circle radii before solving for an equation parameter.',
 38:'Use substitution to find a coefficient sum without a full expansion.',
 44:'Use exponential monotonicity and range to count intercepts.',
 51:'Translate a cofunction identity into a relation between acute angles in radians.',
 53:'Separate base and lateral areas before using Pythagoras to recover vertical height.',
 63:'Use the discriminant inequality and then enforce the integer restriction.',
 68:'Infinitely many solutions require the same line, including its intercept.',
 81:'Convert radicals into fractional exponents before comparing proposed forms.',
 86:'An enlarged drawing decreases the real distance represented by one printed unit.',
 91:'Clear denominators carefully, then choose the positive root required by the conditions.',
 104:'Use the median position, total sum, and range as three connected constraints.',
 105:'Distinguish random sampling from random assignment when assessing a causal conclusion.',
}
sat=json.loads((Path(sys.argv[1])/'sat-selected.json').read_text())
for code,note in unique_est.items():
 r=next(r for r in rows if r['source']=='est' and r['source_code']==code)
 selected[r['id']].append('unique');reasons[r['id']]=note
for idx,note in unique_sat.items():
 r=byid[sat[idx]['id']];selected[r['id']].append('unique');reasons[r['id']]=note
focus=[{'id':r['id'],'collections':selected[r['id']],'bank_occurrences':counts[(r['lesson'],r['idea'])],
        'takeaway':reasons.get(r['id'],''),'fingerprint':r['fingerprint']} for r in rows]
(out/'focus.json').write_text(json.dumps(focus,ensure_ascii=False,indent=2)+'\n')
audit={c:{'questions':sum(c in r['collections'] for r in focus),
 'ideas':len({(byid[r['id']]['lesson'],byid[r['id']]['idea']) for r in focus if c in r['collections']}),
 'difficulty':dict(Counter(byid[r['id']]['difficulty'] for r in focus if c in r['collections']))} for c in ['must_know','repeated','unique']}
audit['priority_questions']=sum(bool(r['collections']) for r in focus)
audit['priority_ideas']=len({(byid[r['id']]['lesson'],byid[r['id']]['idea']) for r in focus if r['collections']})
audit['frequency_basis']='Distinct reviewed questions in the 378-item revision release, grouped by exact lesson and idea; no official exam-frequency claim.'
audit['frequent_ideas']=[{'lesson':l,'idea':i,'questions':n} for (l,i),n in counts.most_common() if n>=4]
(out/'focus-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
blob=json.dumps(focus,ensure_ascii=False).replace("'","''")
sql="begin;\ncreate temporary table focus_release on commit drop as select * from jsonb_to_recordset('"+blob+"'::jsonb) as r(id uuid,collections text[],bank_occurrences int,takeaway text,fingerprint text);\n"
sql+="""do $$ begin
 if exists(select 1 from focus_release r left join public.revision_items i on i.question_id=r.id where i.question_id is null or i.fingerprint<>r.fingerprint) then raise exception 'revision_manifest_changed'; end if;
end $$;
update public.revision_items i set focus=jsonb_build_object('collections',r.collections,'bank_occurrences',r.bank_occurrences,'takeaway',r.takeaway) from focus_release r where i.question_id=r.id;
commit;
"""
(out/'focus-release.sql').write_text(sql)
print(json.dumps({k:v for k,v in audit.items() if k!='frequent_ideas'}))
