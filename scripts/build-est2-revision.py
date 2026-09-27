"""Curate revision metadata from the independently reviewed EST II paper snapshot.
Usage: python scripts/build-est2-revision.py /path/to/est2-pool.json
Never publishes to the database; original question images and keys stay intact.
"""
import json,re,sys,hashlib,base64,io
from pathlib import Path
from collections import Counter
from PIL import Image
root=Path(__file__).resolve().parents[1];out=root/'content/est2-revision-2026-09-28';out.mkdir(exist_ok=True)
pool=json.loads(Path(sys.argv[1]).read_text());assert len(pool)==418
excluded={117:'Pure-imaginary classification depends on whether zero is excluded; request an explicit nonzero condition.',269:'The parabola axis is not specified; the solution assumes a vertical axis.'}
# Editorial lesson groups. First match is intentional, e.g. trig graphs before general functions.
groups=[
 ('Complex numbers',r'Complex|Powers of i|Pure imaginary'),('Matrices',r'Matrix|Determinant'),('Vectors',r'Vector|Parallelogram vectors'),
 ('Sequences and series',r'sequence|series|Recurrence|Recursive'),('Logarithms',r'Logarithm|Logarithmic'),('Limits and continuity',r'Tangent line|Limit|limit|continuity|Difference quotient'),
 ('Conic sections',r'Ellipse|Hyperbola|Change of coordinate origin'),('Counting methods',r'Combinations|combinations|Counting|counting|selection|Question selection|Factorial|Arrangements|License'),
 ('Number properties',r'Integer points|Signs and integer powers'),('Probability',r'Sampling without replacement|probability|Probability|Independent|Inclusion-exclusion'),('Statistics',r'Mean|mean|Median|median|Quartile|quartile|deviation|statistics|Normal distribution|Measurement scale|transformation of data'),
 ('Absolute value',r'Absolute'),('Exponents and radicals',r'Exponent laws|Exponent rules|Exponent simplification|Exponent relationship|Negative exponent|Radical|radical|Fourth-root|Irrational|Expressing variable using roots'),
 ('Exponential models',r'Exponential|exponential|Continuous compound'),('Rational functions and equations',r'Rational|rational|Asymptote|asymptote|Zeros and excluded'),
 ('Trigonometric functions and identities',r'Trigonometric|trigonometric|Cofunction|Coterminal|Cosine|Sine|Tangent interval|Tangent graph|Amplitude|Arcsine|Inverse trig|Double-angle|Pythagorean identity|Squared trigonometric|Periodic|Parity and period'),
 ('Linear equations and systems',r'Infinite solutions|Linear equation|Linear system|Algebraic system|Age equation|Inventory|Sales system|Prices system|Price-change|Profit equation|Three-variable|Linear combination'),
 ('Inequalities',r'Inequalit|inequalit'),('Ratios, percentages and rates',r'Percent|percent|Weighted percentage|Ratio allocation|Reciprocal ratio|Average speed|Speed-time|Fourth proportional|variation'),
 ('Coordinate geometry and lines',r'Perpendicular|Parallel line through|Parallel lines$|Parallel-line parameter|Equidistant parallel|Angle between|Line intercept|Line y-intercept|Collinear|Coordinate signs|Distance parameter|Internal division|Parallelogram coordinates|Rotation about origin|Distance in oblique|Parametric line'),
 ('Three-dimensional geometry',r'Spatial|Three-dimensional|Sphere|Cube|Cylinder|Cone|Prism|prism|Volume scaling|Open-box'),
 ('Circles',r'Circle|circle|Annulus|Semicircle|Intersecting chords|Inscribed-circle|Inscribed square|Diameter and right|Line cutting circle|Distance to tangent'),
 ('Triangles and trigonometry',r'Pythagorean theorem|Triangle|triangle|Altitude|hypotenuse|Shadows|Roof|Law of cosines|Reflection geometry|Equilateral'),
 ('Plane geometry and angles',r'Parallel-line broken transversal|Parallelogram|Rectangle|rectangle|Trapezoid|Polygon|polygon|octagon|heptagon|Quadrilateral|quadrilateral|angles|Angles|Vertical angles|Complementary angles|Square angle|Fraction of shaded|Adding squares'),
 ('Quadratics and polynomials',r'Sign of a downward parabola|Nonlinear system|Quadratic|quadratic|Polynomial|polynomial|Cubic|cubic|Parabola|Product of roots|Constant term|Consecutive|Completing|Remainder theorem|Factoring|Maximum product|Midpoint of roots|Axis from roots|Shifted vertex|Vertex coordinates|Four distinct intersections|Algebraic identity|End behavior'),
 ('Functions and transformations',r'Graph sign and monotonicity|Composite domain|Inverse value|Function|function|Composition|composition|Invertibility|Mapping|Defined operation|Increasing|Odd function|Translation|transformation|Linear transformation|Number of intersections|Maximum piecewise|Initial height'),
 ('Graphs and models',r'graph|Regression|extrapolation|Zeros from table')]
# Canonical idea labels combine genuine method variants, not repeated mock reuse.
canon=[
 (r'^Perpendicular','Perpendicular lines'),(r'^(Parallel lines|Parallel-line parameter|Equidistant parallel lines|Parallel line through center)$','Parallel lines'),
 (r'^Parallel.*angle|^Angles at intersection|^Vertical angles|^Linear-pair angles','Angles with parallel and intersecting lines'),
 (r'^(Quadratic vertex|Vertex coordinates|Parabola vertex|Quadratic minimum|Completing the square)$','Vertex and completing the square'),
 (r'^(Axis from roots|Midpoint of roots|Quadratic symmetry)$','Quadratic symmetry'),
 (r'^(Exponential equation|Exponent relationship)$','Solving exponential equations'),(r'^Exponent (laws|rules|simplification)$','Exponent laws'),
 (r'^Logarithm.*(equation|identities|bases)|^Logarithmic equation$','Solving logarithmic equations'),
 (r'^Logarithm laws$','Logarithm laws'),(r'^Complex (equality|equation)|^Complex-number equation$','Equating real and imaginary parts'),
 (r'^Complex (square|cube)$|^Powers of i$','Complex arithmetic and powers'),
 (r'^Function composition$|^Composition from tables$|^Piecewise composition$|^Repeated composition$','Function composition'),
 (r'^Inverse (function value|value|linear functions)$|^Inverse-function point$','Inverse functions'),
 (r'^(Three-dimensional distance|Spatial distance|Spatial distance parameter)$','Distance in three dimensions'),
 (r'^(Arithmetic sequence|Arithmetic sequence count|Arithmetic series)$','Arithmetic sequences and sums'),
 (r'^(Recursive sequence|Recurrence|Recursive region count)$','Recursive sequences'),
 (r'^Rational asymptotes$|^Slant asymptote$|^Asymptotes and hole$|^Center of rational graph$','Rational asymptotes and holes'),
 (r'^Probability without replacement$|^Sampling without replacement$|^Probability of same colors$','Sampling without replacement'),
 (r'^Conditional probability','Conditional probability'),(r'^Total probability$|^Binomial probability$|^Independent','Combined-event probability'),
 (r'^Mean and median from','Mean and median from data'),(r'^Summary statistics$|^Median and mode$|^Range and median$','Summary statistics'),
 (r'^Interquartile range$|^Quartiles$','Quartiles and interquartile range'),(r'^Population standard deviation$|^Standard deviation$','Standard deviation'),
 (r'^Circle center$|^Circle radius$|^Circle circumference$','Circle equations, center and radius'),
 (r'^Cube surface area$|^Prism lateral area$|^Composite prism surface area$','Surface area'),
 (r'^Cone and cylinder volume$|^Cylinder radius$|^Cube and pyramid volume$|^Volume scaling$','Volume and scale factors'),
 (r'^Absolute-value equation$','Absolute value equations'),(r'^Absolute-value (inequality|bound)$','Absolute value inequalities'),
 (r'^Triangle inequality$|^Obtuse triangle test$','Classifying triangles and feasible sides'),
 (r'^Trigonometric identity$|^Trigonometric factorization$|^Pythagorean identity$|^Cofunction identity$|^Double-angle identity$|^Squared trigonometric sum$','Trigonometric identities'),
 (r'^Sine range$|^Cosine range$|^Cosine period$|^Trigonometric periods$|^Amplitude and phase shift$|^Sine graph$|^Tangent graph scale$','Trigonometric graphs and parameters'),
 (r'^Linear system$|^Algebraic system$|^Sales system$|^Prices system$|^Price-change system$|^Three-variable system$','Linear systems and word models'),
 (r'^Triangle angle|^Triangle and straight|^Angle sum in intersecting|^Complementary angles$|^Quadrilateral angles$','Angle sums and angle chasing')]
easy=set(map(int,'0 1 2 6 7 8 12 14 15 16 24 29 30 32 33 36 44 46 50 51 54 56 57 60 61 64 65 68 70 71 75 76 77 78 79 80 85 86 93 96 98 100 106 108 110 112 114 115 118 120 121 122 124 126 127 129 130 131 132 133 134 135 136 142 145 147 148 150 152 153 155 156 157 159 162 164 166 167 171 172 175 176 179 182 184 187 189 190 192 196 197 198 199 200 201 202 203 204 207 209 212 214 215 217 218 220 221 222 223 225 228 229 230 234 235 236 237 240 241 242 243 248 250 251 252 253 255 258 259 260 264 268 271 272 274 275 276 277 279 280 283 284 288 290 291 294 298 299 300 304 307 308 309 310 311 313 314 318 320 323 326 327 328 329 330 331 334 335 337 339 340 341 344 345 346 347 349 354 355 356 357 358 359 360 362 364 366 367 368 369 370 371 372 373 375 376 377 378 380 381 385 387 388 390 391 392 393 394 395 396 397 399 400 401 402 403 404 405 407 408 409 410 412 413 416 417'.split()))
hard=set(map(int,'3 10 18 19 22 25 26 31 34 35 40 41 42 45 49 59 73 81 83 87 89 91 94 95 101 102 107 109 111 116 123 137 138 139 140 143 151 158 160 169 170 180 181 185 188 191 193 195 206 208 210 213 224 226 227 232 238 239 244 245 247 249 254 257 261 263 266 270 281 282 286 295 297 301 302 303 305 306 312 315 317 319 321 324 325 333 338 342 348 350 351 352 353 361 363 365 374 379 382 383 384 386 389 398 406 411 414 415'.split()))
unique=set(map(int,'0 10 16 19 22 25 35 40 41 59 72 87 94 95 107 109 111 137 139 143 151 160 169 180 191 193 195 208 213 214 226 237 242 245 249 257 260 270 282 285 289 301 302 312 321 342 345 351 353 361 372 374 382 383 386 393 411'.split()))
rows=[];seen={};excluded_rows=[]
for i,q in enumerate(pool):
 a=q['assets'];assert a.get('visual_verified') is True and a.get('solution_method')=='independently_worked'
 assert q['correct'] in [c['key'] for c in q['choices']] and len(q['explanation'])>0
 image=base64.b64decode(a['figure'].split(',',1)[1]);assert hashlib.sha256(image).hexdigest()==a['image_sha256']
 Image.open(io.BytesIO(image)).verify()
 if i in excluded:excluded_rows.append({'id':q['id'],'source_code':a['source_code'],'reason':excluded[i]});continue
 digest=hashlib.sha256(re.sub(r'\s+',' ',a['original_text']).encode()).hexdigest()
 if digest in seen:excluded_rows.append({'id':q['id'],'source_code':a['source_code'],'reason':'Exact source-text duplicate of '+seen[digest]});continue
 seen[digest]=a['source_code']
 idea=q['stem'].split(' — ')[0]
 lesson=next((name for name,pattern in groups if re.search(pattern,idea)),None)
 if not lesson:raise ValueError(('unclassified idea',i,idea))
 original=idea;idea=next((label for pattern,label in canon if re.search(pattern,idea)),idea)
 level='hard' if i in hard else 'easy' if i in easy else 'medium'
 rows.append({'id':q['id'],'source':'est2','source_code':a['source_code'],'source_document':a['source_document'],'source_idea':original,'lesson':lesson,'idea':idea,'difficulty':level,'programmes':['est2'],'fingerprint':q['fingerprint'],'unique':i in unique,'focus':{'collections':[],'bank_occurrences':0,'takeaway':'Key skill: '+idea+'.','math_format':'plain'}})
counts=Counter((q['lesson'],q['idea']) for q in rows)
core={'Linear systems and word models','Perpendicular lines','Parallel lines','Vertex and completing the square','Quadratic symmetry','Exponent laws','Solving exponential equations','Solving logarithmic equations','Logarithm laws','Equating real and imaginary parts','Complex arithmetic and powers','Function composition','Inverse functions','Distance in three dimensions','Arithmetic sequences and sums','Recursive sequences','Rational asymptotes and holes','Sampling without replacement','Conditional probability','Combined-event probability','Mean and median from data','Summary statistics','Quartiles and interquartile range','Standard deviation','Circle equations, center and radius','Surface area','Volume and scale factors','Absolute value equations','Absolute value inequalities','Classifying triangles and feasible sides','Trigonometric identities','Trigonometric graphs and parameters','Angle sums and angle chasing','Angles with parallel and intersecting lines','Remainder theorem','Factoring by grouping','Matrix multiplication','Matrix dimensions','Matrix addition','Matrix determinant','Radical domain','Rational domain','Radical equation','Ellipse foci','Hyperbola asymptotes','Law of cosines','Simple probability','Percent increase','Arithmetic series','Geometric sequence','Linear equation','Rational equation','Normal distribution','Pythagorean theorem','Triangle inequality','Logarithm domains','Logarithmic inequality'}
for q in rows:
 tags=[]
 if q['idea'] in core:tags.append('must_know')
 if counts[q['lesson'],q['idea']]>=4:tags.append('repeated')
 if q['unique']:tags.append('unique')
 q['focus'].update(collections=tags,bank_occurrences=counts[q['lesson'],q['idea']])
for name,value in [('manifest.json',rows),('exclusions.json',excluded_rows)]: (out/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
audit={'questions':len(rows),'ideas':len(counts),'sources':dict(Counter(q['source_document'] for q in rows)),'levels':dict(Counter(q['difficulty'] for q in rows)),'collections':{c:sum(c in q['focus']['collections'] for q in rows) for c in ['must_know','repeated','unique']},'lessons':{l:{'questions':sum(q['lesson']==l for q in rows),'ideas':len({q['idea'] for q in rows if q['lesson']==l})} for l in sorted({q['lesson'] for q in rows})},'source_images_verified':len(pool),'excluded':len(excluded_rows)}
(out/'audit.json').write_text(json.dumps(audit,indent=2)+'\n')
sql="begin;\ncreate temp table est2_revision_release on commit drop as select * from jsonb_to_recordset('"+json.dumps(rows,ensure_ascii=False).replace("'","''")+"'::jsonb) as r(id uuid,lesson text,idea text,difficulty text,programmes text[],fingerprint text,focus jsonb);\n"
sql+='''do $$ begin
if exists(select 1 from est2_revision_release r left join public.questions q on q.id=r.id left join public.question_keys k on k.question_id=q.id where q.id is null or q.track_id<>'est2' or nullif(q.assets->>'release_hold_reason','') is not null or r.fingerprint is distinct from md5(jsonb_build_array(q.stem,q.choices,q.assets,k.correct,k.explanation)::text)) then raise exception 'est2_revision_source_changed';end if;
end $$;
insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,focus)
select id,lesson,idea,difficulty,programmes,fingerprint,focus from est2_revision_release
on conflict(question_id) do update set lesson=excluded.lesson,idea=excluded.idea,difficulty=excluded.difficulty,programmes=excluded.programmes,fingerprint=excluded.fingerprint,focus=excluded.focus;
commit;
'''
(out/'release.sql').write_text(sql);print(json.dumps(audit,indent=2))
