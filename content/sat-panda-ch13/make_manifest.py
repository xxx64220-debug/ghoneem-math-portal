"""Checked College Panda Chapter 13 exercise transcription and crop map."""
import json
from pathlib import Path

# page, source crop at 1.6x, searchable stem, choices, answer, explanation, optional accepted answers
rows={1:[
(152,[100,140,487,425],"Solve y = −5x + 65 and y = 25. Which ordered pair (x,y) is the solution?",["(−8,25)","(8,25)","(25,−8)","(25,8)"],"B","25 = −5x + 65 gives x = 8, so the pair is (8,25)."),
(152,[100,429,487,714],"For 3x − 5y = −11 and x = 1 − 3y, find y.",["−1","0","1","2"],"C","Substitute x = 1 − 3y: 3 − 14y = −11, hence y = 1."),
(152,[100,717,487,1060],"Solve y + 2x = 20 and 6x − 5y = 12. Which is (x,y)?",["(−7,6)","(−6,7)","(6,7)","(7,6)"],"D","Use y = 20 − 2x; 6x − 5(20 − 2x) = 12 gives x = 7 and y = 6."),
(152,[507,140,899,418],"For y = x² + 10x + 23 and x − 9 = −15, find y.",[],"-1","x = −6 and y = 36 − 60 + 23 = −1."),
(152,[507,422,899,917],"What is the intersection (x,y) of the two lines shown in the source graph?",["(−4,−6)","(−3,−2)","(−2,−3)","(−1,2)"],"C","Read the graph at the crossing of the lines: (−2,−3)."),
(152,[507,920,899,1175],"For 2x + 5y = 24 and x + 4y = 15, find x + y.",["7","8","9","10"],"C","Subtract the second equation from the first: x + y = 9."),
(153,[75,90,470,375],"How many solutions does 2x − 4y = 8 and x + 2y = 4 have?",["Zero","One","Two","More than two"],"B","The equations have different slopes. Adding after dividing the first by 2 gives x = 4, y = 0; one solution."),
(153,[75,380,470,865],"A vendor sells 200 small and large cups at $5 and $7. Revenue from small cups is $160 more than from large cups. If x and y are their counts, which system models this?",["x − y = 160; 5x + 7y = 200","x − y = 160; 7x + 5y = 200","x + y = 200; 5x = 7y + 160","x + y = 200; 7y = 5x + 160"],"C","The counts total 200, and small-cup revenue exceeds large-cup revenue: 5x − 7y = 160."),
(153,[75,868,470,1128],"If a/b = 4.5 and a/(kb) = 12.5, find k.",[],"9/25","Dividing a/b by a/(kb) gives k = 4.5/12.5 = 9/25 = 0.36.",["9/25","0.36"]),
(153,[485,90,883,424],"One equation is 6x − 3y = 9. Which second equation makes the system have no solution?",["3x − y = 2","2x − y = 3","x/3 − y/6 = 2","x/3 − y/6 = 1/2"],"C","The first line is x/3 − y/6 = 1/2; choice C is parallel with a different constant."),
(153,[485,428,883,710],"If x² − y² = 48 and x − y = 6, find x + y.",["8","12","16","24"],"A","Factor (x − y)(x + y) = 48; since x − y = 6, x + y = 8."),
(153,[485,713,883,1045],"For 2x − 5y = a and bx + 10y = −8, find a if the lines have infinitely many common solutions.",["−4","1/4","4","16"],"C","Multiply the first equation by −2; the constant becomes −2a = −8, so a = 4."),
(154,[95,90,480,424],"The lines y = ax + b and y = −bx meet at (2,8). Find a.",["2","4","6","8"],"C","From 8 = −2b, b = −4. Then 8 = 2a − 4, so a = 6."),
(154,[95,428,480,875],"The source graph shows y = x² + 1 and y = x − 1. How many real intersection points?",["Zero","Exactly one","Exactly two","Exactly three"],"A","Equating them gives x² − x + 2 = 0 with discriminant −7, so no real intersection."),
(154,[95,880,480,1180],"If 3x − 5/16 = 4 and y = 2(3x − 5/16)², find y.",["8","16","32","64"],"C","The parenthesized value equals 4, so y = 2·4² = 32."),
(154,[495,90,890,417],"For ax + 2y = 5 and 3x − 6y = 20, the system has exactly one solution. Which value of a is impossible?",["−1","3/4","1","3"],"A","At a = −1, multiplying the first equation by −3 gives the same x,y coefficients as the second but a different constant; the lines are parallel."),
(154,[495,420,890,779],"For 3x = 16 and 80 = 4y² + 3x, which choice could be y?",["−16/3","−4","4/3","8"],"B","Substitute 3x = 16: 4y² = 64, so y = ±4; −4 is listed."),
(154,[495,785,890,1095],"For −5x = 8 − ky and 18y + 5x = −10x + 21, find k if the lines never meet.",[],"-6","Rewrite as ky − 5x = 8 and 18y + 15x = 21. Matching x coefficients after multiplying the first by −3 gives −3k = 18, so k = −6."),
(155,[80,90,475,700],"The source graph shows a line through (−3,5) and (0,3). Which second line makes a system with no solution?",["y = −3x/2 − 1","y = 3x/2 + 3","y = −2x/3 − 1","y = −2x/3 + 3"],"C","The shown slope is (3 − 5)/(0 − (−3)) = −2/3. Choice C has the same slope and a different intercept."),
(155,[80,706,475,990],"The graphs y = x² − 7x + 7 and y = 2x − 1 intersect at (1,1) and (p,q). Find p.",[],"8","Solve x² − 7x + 7 = 2x − 1: (x − 1)(x − 8) = 0, so p = 8."),
(155,[490,90,887,485],"Shannon drives 340 miles in 9 hours at 50 mph then 30 mph. How many miles were driven at 50 mph?",[],"175","With times t and 9 − t, 50t + 30(9 − t) = 340 gives t = 3.5 hours, or 175 miles."),
(155,[490,491,887,872],"For 4/3 + (5/4)x = 28y + (5/8)x and my = (5x − 8)/2, find m if the equations are parallel and distinct.",[],"112","The first equation simplifies to 15x − 672y = −32. The second is 5x − 2my = 8. Match slopes using three times the second: 6m = 672, so m = 112."),
],2:[
(156,[100,140,487,419],"Which pair solves 4x − y/3 = −8 and y = 4x + 16?",["(−2,8)","(−1,12)","(1,20)","(3,28)"],"B","Multiply first equation by 3: 12x − y = −24. Substitute y = 4x + 16 to get x = −1, y = 12."),
(156,[100,423,487,715],"For 9x = −7y + 22 and 5x = 7y − 76, find 7x.",[],"-27","Add the equations: 14x = −54, hence 7x = −27."),
(156,[100,719,487,1050],"For y = 0.5x + 14 and x − y = −18, find y.",[],"10","Set x = y − 18: y = 0.5(y − 18) + 14, giving y = 10."),
(156,[505,140,890,593],"How many common intersection points do the three lines in the source graph have?",["Zero","Exactly one","Exactly two","Exactly three"],"A","The three lines do not all pass through a single point, so their system has zero solutions."),
(156,[505,598,890,1015],"Which system has no solution?",["y = 8; x = 8","y = 8; y = 8x + 8","y = 8x; y = 8x + 8","y = −8x + 8; y = 8x + 8"],"C","The lines in C have equal slope 8 and different intercepts, hence no intersection."),
(157,[80,90,469,373],"For y = 2x − 14 and y = (x + 5)(x − 7), which listed x is a possible intersection?",["−7","−3","4","9"],"B","2(x − 7) = (x + 5)(x − 7), giving x = 7 or x = −3; only −3 is listed."),
(157,[80,377,469,660],"How many intersection points have 3x − 6y = 15 and −2x + 4y = −10?",["Zero","One","Two","More than two"],"D","Both equations reduce to x − 2y = 5, so all their points coincide."),
(157,[80,664,469,947],"For y = −10x and x² + y = 96, find y in a solution with y < 0.",[],"-160","x² − 10x − 96 = (x + 6)(x − 16) = 0. At x = 16, y = −160."),
(157,[485,90,889,320],"If (x + y)/x = 9 and ay/(3x) = 32, find a.",[],"12","The first ratio gives y = 8x. Then 8a/3 = 32, so a = 12."),
(157,[485,326,889,624],"For 9(2x + 1) + 27(y − 4) = 810 and (2x + 1) + (y − 4) = −393, find 8(y − 4).",[],"1932","Divide the first by 9, subtract the second: 2(y − 4) = 483. Multiply by 4 to get 1,932."),
(157,[485,629,889,990],"A restaurant has 30 tables seating 144 people: each rectangular table seats 4 and each round table seats 8. How many rectangular tables?",["12","16","20","24"],"D","With r + c = 30 and 4r + 8c = 144, subtract from 8(r + c) = 240: 4r = 96, r = 24."),
(158,[90,90,480,475],"For mx − 6y = 10 and 2x − ny = 5, find m/n if the equations have infinitely many solutions.",["1/12","1/3","4/3","3"],"C","Double the second equation: 4x − 2ny = 10. Thus m = 4, n = 3, and m/n = 4/3."),
(158,[90,480,480,738],"With x − 2y = 5, which second equation gives exactly one common solution?",["−x + 2y = 0","x − 2y = 0","−x + 2y = −5","x + 2y = −5"],"D","Only x + 2y = −5 has a different slope, so it crosses the first line once."),
(158,[90,744,480,1118],"For x² − y² = 1/12 and x − 2y = 0, which listed value of y is possible?",["−1/6","−1/√12","1/4","1/2"],"A","x = 2y gives 3y² = 1/12, so y = ±1/6; −1/6 is listed."),
(158,[495,90,893,438],"For (3/10)y + (b/3)x = 3/4 − (1/5)y and (3/8)x + 3/5 = −(1/4)y + 8/5, find b if the lines are parallel and distinct.",[],"9/4","Simplify to y/2 + (b/3)x = 3/4 and y/4 + (3/8)x = 1. Double the latter and match x coefficients: b/3 = 3/4, so b = 9/4.",["9/4","2.25"]),
(158,[495,444,893,1120],"Which listed pair of equations matches the two source lines meeting at (5600,6900)?",["−x/0.01 + y/0.04 = 90; −40x + 30y = 220","−x/0.01 + y/0.04 = 220; −40x + 30y = 90","−0.01x + 0.04y = 90; −x/40 + y/30 = 220","−0.01x + 0.04y = 220; −x/40 + y/30 = 90"],"D","At (5600,6900), −0.01(5600)+0.04(6900)=220 and −5600/40+6900/30=90; only D fits both."),
(159,[80,90,470,357],"If f(x) = ax³ + bx passes through (−1,−10) and (2,38), find ab.",["9","21","24","39"],"B","−a − b = −10 and 8a + 2b = 38 give a = 3, b = 7, and ab = 21."),
(159,[80,363,470,650],"For x² + 2x = y − 1 and −4x = y + 8, find x.",[],"-3","y = −4x − 8. Then x² + 2x = −4x − 9, or (x + 3)² = 0."),
(159,[80,655,470,1110],"Kenji mows 57.75 square yards/minute with a push mower and 80.25 with a self-propelled mower. In 120 total minutes he mows 9,000 square yards. How long on the push mower?",[],"28","If p is push-mower minutes, 57.75p + 80.25(120 − p) = 9000, giving p = 28."),
(159,[490,90,890,396],"For y = √x + 3 and √(4x) − y = 3, find y.",[],"9","Since √(4x) = 2√x, substitution gives √x − 3 = 3, so √x = 6 and y = 9."),
(159,[490,400,890,717],"For −15x + 3y = 12 and y + 132 = x² − 4x, find one possible x.",[],"-8","First y = 5x + 4. Substitution gives x² − 9x − 136 = (x + 8)(x − 17) = 0; either −8 or 17 works.",["-8","17"]),
(159,[490,723,890,1115],"For 5x − 3y = 8 and −20x + 12y = −32, which pair satisfies both for every real n?",["(n,5n/3 − 8)","(3n/5 + 8/5,n)","(n − 1,5n/3 − 1)","(3n/5 + 1,n − 1)"],"D","The equations are equivalent. For x = 3n/5 + 1 and y = n − 1, 5x − 3y = 3n + 5 − 3n + 3 = 8."),
]}

out=[]
for ex,group in rows.items():
 for n,row in enumerate(group,1):
  page,rect,stem,choices,correct,explanation,*accepted=row
  item=dict(exercise=ex,n=n,page=page,rect=rect,stem=stem,choices=choices,correct=correct,explanation=explanation)
  if accepted:item['accepted']=accepted[0]
  out.append(item)
assert len(rows[1])==22 and len(rows[2])==22 and len(out)==44
Path(__file__).with_name('questions.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
