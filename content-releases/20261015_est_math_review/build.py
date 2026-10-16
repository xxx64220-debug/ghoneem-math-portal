"""Build a bounded, no-key-change EST content review release."""
import json, hashlib, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
D=Path(__file__).parent
before=json.loads((D/'before.json').read_text())
archive=ROOT.parent/'sources/archive'
explanations={
'MA-18':"Bring all terms to one side: 10x² − x − 3 = (5x − 3)(2x + 1) = 0. Thus x = 3/5 or x = −1/2. Of the listed values −1/5, 3/5, −3/2 and 1/2, only 3/5 is a root, so G is correct.",
'CP-c24-02':"There are 165 gray shirts out of 450 shirts. Thus P(gray) = 165/450 = 11/30 = 0.3666.... The recorded rounded decimal 0.367 and the exact fraction 11/30 are accepted; a percent is not requested.",
'CP-c25-02':"Range is the largest data value minus the smallest, regardless of frequency: 28 − 17 = 11.",
'CP-c23-03':"The original bars show 254, 447, 315, 388 and 122 cookies. Neighborhoods 2 and 4 sold 447 + 388 = 835; neighborhoods 1, 3 and 5 sold 254 + 315 + 122 = 691. The difference is 835 − 691 = 144.",
'CP-c07-19':"Only the longer base changes. A(x + 5) − A(x) = (7/2)[(9 + x + 5) − (9 + x)] = 35/2 = 17.5 square inches.",
'CP-c19-14':"Complete both squares: (x + 1)² + (y − 4)² = 64 + 1 + 16 = 81. Therefore the radius is √81 = 9.",
'CP-c19-11':"Radii PQ and PR are equal, so triangle PQR is isosceles. Its central angle QPR equals the 144° minor arc QR. Each base angle is (180° − 144°)/2 = 18°.",
'CP-c19-30':"Complete the squares: (x + 7/2)² + (y + 1/2)² = −7/2 + 49/4 + 1/4 = 9. The radius is 3.",
'CP-c19-12':"Set y = 0 at an x-axis intersection: (x + 4)² = k − 36. Exactly one real x occurs only when k − 36 = 0, so k = 36 (the tangent point is (−4, 0)).",
'CP-c19-17':"The source diagram puts P and Q on the same side of chord AB. Both inscribed angles APB and AQB intercept the same arc AB, so they are equal. Hence angle AQB = 40°.",
'CP-c19-25':"A diameter through the midpoint E of chord CD is perpendicular to that chord. Thus CE = 14 and OC = 16. By Pythagoras, OE² = 16² − 14² = 60, so OE = 2√15. Therefore k = 15.",
'CP-c19-22':"Circle A has radius 4 and diameter 8. Circle B has diameter 8 + 48 = 56 and radius 28. Its radius squared is n = 28² = 784.",
'CP-c19-26':"Expand (x − 9)² + (y + 12)² = 1 to obtain x² + y² − 18x + 24y + 224 = 0. Thus a + b + c = −18 + 24 + 224 = 230.",
'MG-13':"The visible first three figures contain 2, 5 and 8 dots, and the archive records 11 for Figure 4. Each step adds 3, so the stated continuing pattern has 2 + 3(n − 1) = 3n − 1 dots. Among the four choices, only D matches even the first two figures.",
'T8-08':"Substitute n = 400: p(400) = 52(400) − 0.05(400²) = 20,800 − 8,000 = 12,800 dollars. Only G gives this value.",
'T7-19':"Rational numbers, irrational numbers and integers are all real. The statement that every real number is an integer is false; for example, 1/2 is real and is not an integer. Therefore C is the only false statement.",
'T7-17':"Equating real parts gives 3x = 12, so x = 4. Equating imaginary parts gives y + 4 = x + 2 = 6, so y = 2. Therefore x + y = 6, choice D.",
'MA-06':"The parent is y = 4ˣ. It is positive and increasing, passes through (0, 1), and approaches y = 0 to the left. The archive image shows precisely these properties in graph F. Graph G is shifted down; H decreases; J decreases and is shifted down.",
'E-21':"Both inequalities must hold. From 2x − 8 ≤ x − 4, obtain x ≤ 4. From x − 4 < 3(x + 6), obtain −22 < 2x, so x > −11. Their intersection is −11 < x ≤ 4: the source image's graph A has an open endpoint at −11 and a closed endpoint at 4.",
'E-11':"Revenue is 6x + 3y dollars. The requirement is 6x + 3y ≥ 1500, or y ≥ 500 − 2x, with nonnegative ticket counts. The boundary passes through (0, 500) and (250, 0); shading above it, including the boundary, is choice D.",
'T7-01':"The monic polynomial with roots 2 and 6 is (x − 2)(x − 6) = x² − 8x + 12. Hence b = −8, choice C.",
'MA-29':"Replacing x by x + 14 moves the graph 14 units left. Subtracting 12 moves it 12 units down. Therefore B describes h.",
'E-19':"Rearrange 2x − 4y > 8. Dividing −4y > 8 − 2x by −4 reverses the inequality: y < x/2 − 2. The boundary is dashed because the inequality is strict, and the region is below it. The original image labels this graph B.",
'H-15':"Since x > 0 and y < 0 are odd integers, x − y = x + |y| is positive and even. For example x = 3 and y = −1 satisfies the conditions but makes A = −1, B = 1/3 and D = 1/3, so none of those must be a positive even integer. The unique answer is C.",
'MG-47':"Parallel nonvertical lines have equal slopes. AB and CD both have slope 2/5. AD has slope −5/2, which differs from BC's −2/5. Therefore only B correctly describes the parallel pairs.",
'AI-41':"Let J mean getting a job, N mean getting new jeans and G mean giving away the old jeans. The promises are J ⇒ N and N ⇒ G. Since G is false, contraposition gives N false, then J false. Thus D follows.",
}
out=[]
for b in before:
 code=b['assets'].get('source_code') or b['assets'].get('source_question_id')
 if code=='MA-30':continue
 assert code in explanations,code
 source=archive/'_bank_backup'/b['assets']['source_file']
 source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
 assert source_hash==b['assets']['source_sha256'],code
 text=source.read_text()
 assert re.search(r'^## '+re.escape(code)+r'\b',text,re.M),code
 evidence={'archive_library_id':'libfile_bf57f23ca344819199a3207a9fbcf774','source_file':source.name,'source_sha256':source_hash,'source_question_id':code,'scope':'Independent solution of complete stored prompt, choices and accepted answers; checked against the exact user-uploaded archive. Original publisher PDF fidelity is not asserted.'}
 if b['assets'].get('image'):
  n=b['assets']['image'].split('/')[-1]; data=(archive/'figures'/n).read_bytes()
  h=hashlib.sha256(data).hexdigest()
  assert h==b['assets']['image_sha256']
  assert data==(ROOT/'assets/question-bank'/n).read_bytes()
  evidence.update(image_file=n,image_sha256=h,visual_review='Original archive crop visually inspected and compared with the mathematical solution.')
 choices=b['choices']
 if code=='E-21':
  choices=[{'key':'A','text':'Open circle at −11, closed circle at 4, segment between them'},{'key':'B','text':'Closed circle at 4, shaded to the left with arrow'},{'key':'C','text':'Open circle at −11, closed circle at 12, segment between them'},{'key':'D','text':'Closed circle at 12, shaded to the left with arrow'}]
  evidence['repair']='Restore both open-endpoint descriptions from the authentic number-line crop; markdown transcription is incorrect.'
 if code=='E-19':
  choices=[{'key':'A','text':'Dashed line (slope 1/2, y-intercept −2), shaded above'},{'key':'B','text':'Dashed line (slope 1/2, y-intercept −2), shaded below'},{'key':'C','text':'Solid line (slope 1/2, y-intercept −2), shaded above'},{'key':'D','text':'Solid line (slope 1/2, y-intercept −2), shaded below'}]
  evidence['repair']='Restore boundary style and missing line parameters from the authentic half-plane crop; A was incorrectly described as solid.'
 if code=='MG-13':evidence['visual_limit']='The supplied crop clips part of Figure 4. The fully visible first three figures suffice to select D uniquely; the archive text records 11 for Figure 4. No missing pixels were reconstructed.'
 out.append({'id':b['id'],'track_id':b['track_id'],'source_code':code,'before_hash':b['hash'],'choices':choices,'correct':b['correct'],'explanation':explanations[code],'evidence':evidence})
assert len(out)==28
(D/'packet.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
(D/'apply.sql').write_text((D/'apply.template.sql').read_text().replace('__PACKET__',"'"+json.dumps(out,ensure_ascii=False).replace("'","''")+"'"))
print('Built 28 independently reviewed records: 14 EST I and 14 EST II; two source-proven choice repairs; no changed accepted answers.')
