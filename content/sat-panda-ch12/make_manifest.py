"""Checked Chapter 12 exercise transcription and source crop locations."""
import json
from pathlib import Path

# Each entry: source page, crop at 1.6x, stem, choices, correct, explanation, optional accepted responses.
rows={
1:[
(140,[100,142,488,405],"Solve x² − 5x − 24 = 0; give one solution.",[],"8","(x − 8)(x + 3) = 0; the solutions are 8 and −3.",["8","-3"]),
(140,[100,407,488,662],"Find the positive solution of x² − 3x − 12 = x − 7.",[],"5","Rearranging gives x² − 4x − 5 = (x − 5)(x + 1) = 0."),
(140,[100,665,488,920],"What is the sum of the solutions to x² + 7x + 19 = 28 − 5x?",["−12","−9","−7","12"],"A","The equation becomes x² + 12x − 9 = 0. The sum of its roots is −12."),
(140,[100,922,488,1130],"Which choice solves x² − 10x + 7 = 0?",["5 + 6√2","5 − 3√2","10 + 8√3","10 − 6√3"],"B","The quadratic formula gives (10 ± √72)/2 = 5 ± 3√2."),
(140,[505,142,902,385],"Solve −x(x + 3) = x + 4.",[],"-2","Rearrange to x² + 4x + 4 = (x + 2)² = 0."),
(140,[505,389,902,618],"Which choice gives both solutions of x² + 4x + 2 = 0?",["−2 ± √2","2 ± 2√2","−2 ± 2√2","−4 ± 2√2"],"A","The quadratic formula gives x = (−4 ± √8)/2 = −2 ± √2."),
(140,[505,622,902,885],"Find the positive solution of 84/x = x − 8.",[],"14","Since x ≠ 0, x² − 8x − 84 = (x − 14)(x + 6) = 0."),
(140,[505,889,902,1130],"Which expression is a factor of 2x² + x − 15?",["x − 3","x + 5","2x − 5","2x + 3"],"C","2x² + x − 15 = (x + 3)(2x − 5)."),
(141,[80,90,468,344],"What is the sum of solutions of (2x − 3)² = 4x + 5?",[],"4","Expand to 4x² − 16x + 4 = 0; the root sum is 16/4 = 4."),
(141,[80,348,468,598],"For 3x³ + 69x² + 336x, a factor is x + k where k > 0. Find the largest possible k.",[],"16","Factor as 3x(x + 7)(x + 16); largest k is 16."),
(141,[80,603,468,846],"A solution of x² − 12x + 6 = 0 is 6 + √n. Find n.",[],"30","Roots are (12 ± √120)/2 = 6 ± √30."),
(141,[80,850,468,1130],"What is the product of solutions of (x + 3)(x − 3) = 7x − 3?",["−12","−9","−6","7"],"C","Rearrange to x² − 7x − 6 = 0, whose root product is −6."),
(141,[488,90,884,310],"In 5x³ − 50x² + 120x, a factor is x − m with m > 0. Give one possible m.",[],"4","Factor 5x(x − 4)(x − 6); m may be 4 or 6.",["4","6"]),
(141,[488,314,884,658],"For 4x² − (2k + 1)x + k + 1 = 0, the root product is w(k + 1). Find w.",["4","2","1/2","1/4"],"D","By Vieta, product c/a = (k + 1)/4, so w = 1/4."),
(141,[488,664,884,900],"Find the smallest solution of √((x + 6)²) = √(6 − 5x).",[],"-15","Squaring gives x² + 17x + 30 = (x + 2)(x + 15) = 0. Both satisfy the original equation; smallest is −15."),
(141,[488,906,884,1110],"Find the positive solution of (8x)² − 5(8x) = 6.",[],"3/4","Let u = 8x; u² − 5u − 6 = (u − 6)(u + 1) = 0. Positive x = 6/8 = 3/4.",["3/4","0.75"]),
],
2:[
(142,[95,142,477,460],"Which choice gives both solutions of 4x² − 9x − 1 = 0?",["(−9 ± √97)/8","(−9 ± √65)/8","(9 ± √97)/8","(9 ± √65)/8"],"C","The discriminant is 81 + 16 = 97, so x = (9 ± √97)/8."),
(142,[95,465,477,745],"Find the positive solution of −x²/2 + x = −24.",[],"8","Multiply by −2: x² − 2x − 48 = (x − 8)(x + 6) = 0."),
(142,[95,748,477,1020],"A root of x² + x − 5 = 0 is (√k − 1)/2. Find k.",[],"21","The quadratic formula gives (−1 ± √21)/2."),
(142,[495,142,890,402],"What is the sum of solutions of 2x(−x + 17) = 54 − x(5 − 3x)?",[],"39/5","Rearrange to 5x² − 39x + 54 = 0. The sum is 39/5.",["39/5","7.8"]),
(142,[495,408,890,730],"Which choice is one solution of −3x² + 6x − 1 = 0?",["−1 + √2/3","−1 + √6/3","1 − √2/3","1 − √6/3"],"D","The roots are 1 ± √6/3."),
(142,[495,735,890,1010],"For x(x − a)(x + 4) = 0, a > 0 and the sum of solutions is 6. Find a.",[],"10","The roots are 0, a, and −4; a − 4 = 6 gives a = 10."),
(143,[80,90,470,365],"A solution of x² − 8x = −9 is a − √b. Find a + b.",["8","11","18","36"],"B","x² − 8x + 9 = 0 has roots 4 ± √7, so a + b = 4 + 7 = 11."),
(143,[80,370,470,635],"For x² − 8kx − (k − 4) = 0, what is the product of the roots?",["4 − k","k − 4","−8k","8k"],"A","Product c/a = −(k − 4) = 4 − k."),
(143,[80,638,470,884],"The line y = ax + 12, with a > 0, passes through (−a, a). Find a.",[],"3","a = −a² + 12 gives (a + 4)(a − 3) = 0. Since a > 0, a = 3."),
(143,[80,886,470,1110],"Find the smaller root of 2x² − 7x + 3 = 0.",[],"1/2","(2x − 1)(x − 3) = 0; the smaller root is 1/2.",["1/2","0.5"]),
(143,[490,90,885,370],"Which proposed factors of 2x² + 11x + 12 are valid: I. x + 2; II. 2x + 1?",["Neither I nor II","I only","II only","I and II"],"A","2x² + 11x + 12 = (x + 4)(2x + 3); neither proposed factor works."),
(143,[490,373,885,730],"For 3x² + (108k − 51)x + 93k + 21 = 0, the root sum is ak + b. Find a + b.",[],"-19","The sum is −(108k − 51)/3 = −36k + 17, so a + b = −19."),
(143,[490,735,885,1015],"For 72x² − (18p + 9q)x + 64p = −32q, the root product is n(2p + q). Find n.",[],"4/9","Rearrange; product is (64p + 32q)/72 = (4/9)(2p + q)."),
(144,[90,90,480,280],"If 4x + k is a factor of 8x³ − 26x² − 24x, k > 0, find k.",[],"3","8x³ − 26x² − 24x = 2x(x − 4)(4x + 3), so k = 3."),
(144,[90,284,480,567],"Find the largest solution of 2√(4x − 19) = x − 3.",[],"17","Squaring yields x² − 22x + 85 = (x − 5)(x − 17) = 0; both roots satisfy the original; largest is 17."),
(144,[90,570,480,805],"Find the positive solution of (x + 11)² − 21(x + 11) + 54 = 0.",[],"7","Set u = x + 11; (u − 3)(u − 18) = 0. Thus x = −8 or 7."),
(144,[90,810,480,1125],"For 3x² + 10x = 8, the roots are a > b. Find b².",["4/9","2/3","4","16"],"D","3x² + 10x − 8 = (3x − 2)(x + 4); b = −4 and b² = 16."),
(144,[500,90,890,442],"For x² + px + 18 = 0, p > 0 and both roots are integers. Which values are possible: I. 9; II. 17; III. 19?",["I only","II only","I and III only","I, II, and III"],"C","Positive factor pairs of 18 have sums 19, 11, and 9. Thus I and III are possible."),
]}

out=[]
for ex, items in rows.items():
 for n,entry in enumerate(items,1):
  page,rect,stem,choices,correct,explanation,*accepted=entry
  item=dict(exercise=ex,n=n,page=page,rect=rect,stem=stem,choices=choices,correct=correct,explanation=explanation)
  if accepted:item['accepted']=accepted[0]
  out.append(item)
assert len(out)==34 and len(rows[1])==16 and len(rows[2])==18
Path(__file__).with_name('questions.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
