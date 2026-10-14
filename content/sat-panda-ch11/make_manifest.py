"""One-time checked transcription of the two Chapter 11 exercise sets."""
import json
from pathlib import Path

# page, rectangle at 1.6x, stem, choices, answer, worked explanation.
rows = {
  1: [
    (130,[70,142,455,485],"An object starts at 18°C and warms by 2.4°C per minute. In y = bx + c, where x is minutes and y is temperature, find c.",[],"18","At x = 0, y = 18; hence the intercept c is 18."),
    (130,[70,490,455,730],"Subtracting 3 from 3x gives 21. What is 8 plus half of x?",["1","5","8","12"],"D","3x − 3 = 21 gives x = 8; 8 + x/2 = 12."),
    (130,[70,734,455,1060],"A vendor starts with 175 lb of mozzarella and sells it for $8.75 per pound. Which function gives the pounds M remaining after selling d dollars' worth?",["M(d) = 175 − d/8.75","M(d) = 175 − 8.75d","M(d) = 175 − 8.75/d","M(d) = 175(8.75) − d"],"A","The sale of d dollars is d/8.75 pounds, leaving 175 − d/8.75."),
    (130,[480,142,885,470],"John charges $0.30 per square foot plus $500. David charges $0.45 per square foot plus $25 per bedroom. They charge the same amount for a five-bedroom house. Find its square footage.",[],"2500","Set 0.30x + 500 = 0.45x + 125, so 375 = 0.15x and x = 2,500."),
    (130,[480,476,885,820],"Marcia baked 240 cookies and distributed one third of them equally among c classmates; each received 4. Which equation models this?",["3c/240 = 4","240c/3 = 4","240/(3c) = 4","240(3)/c = 4"],"C","One third of 240 is 80; 80/c = 4, equivalent to 240/(3c) = 4."),
    (130,[480,823,885,1020],"B lies on segment AC; AB is 7 more than twice BC, and AC = 55. Find AB.",[],"39","If BC = x, then 7 + 2x + x = 55, so x = 16 and AB = 39."),
    (131,[75,95,465,345],"A garden has 3/5 as many shrubs as flowers and 180 more flowers than shrubs. How many flowers?",[],"450","If flowers = f, then f − 3f/5 = 180; 2f/5 = 180, giving f = 450."),
    (131,[75,354,465,800],"Carl drives 20 miles at a miles/hour in the morning and 24 miles at b miles/hour in the evening. The trips take equal time. Which equation is true?",["20a + 24b = 44","a/24 = b/20","20/a = 24/b","a/20 + b/24 = 1"],"C","Time equals distance divided by speed; 20/a = 24/b."),
    (131,[75,805,465,1100],"A league has 38 groups. There are 3 times as many four-player groups as five-player groups g, plus 2 six-player groups. Which equation finds g?",["3g + 2 = 38","4g + 5(3g) + 2(6) = 38","4g + 2 = 38","4(3g) + 5g + 2(6) = 38"],"C","Count groups, not players: g + 3g + 2 = 38."),
    (131,[490,95,880,340],"A tie costs k dollars less than three times a $40 shirt. The tie costs $30. Find k.",[],"90","30 = 3(40) − k, so k = 90."),
    (131,[490,346,880,632],"A taxi charges $4.75 for its first mile and $3.50 for each additional mile. A trip of x miles costs $24. Which equation models the charge?",["3.50x − 4.75 = 24","8.25x − 3.50 = 24","3.50x + 1.25 = 24","3.50x + 4.75 = 24"],"C","4.75 + 3.50(x − 1) = 3.50x + 1.25 = 24."),
    (131,[490,633,880,1000],"Joey brought x pounds of popcorn and Matt brought 4 fewer. After 60% was eaten, they split the remaining popcorn equally. How much did each take?",["0.2x − 0.8","0.4x − 0.8","0.6x − 1.2","0.8x − 1.6"],"B","The two brought 2x − 4 pounds; half of the 40% leftover is 0.2(2x − 4) = 0.4x − 0.8."),
    (132,[90,96,480,530],"Mitch clears one acre in 14 hours and earns $875 per acre. Which equation gives the extra hours h needed to earn $200 more?",["(14/875)h = 200","(14/875)h = 2,825","(875/14)h = 200","(875/14)h = 2,825"],"C","He earns 875/14 dollars per hour, so (875/14)h = 200."),
    (132,[90,536,480,925],"Joseph harvests a field in 12 days; Patrick works twice as fast. Together they finish in t days. Which equation is true?",["12/t + 6/t = 2","t/12 + t/6 = 1","12/t + 24/t = 2","t/12 + t/24 = 1"],"B","Patrick takes 6 days alone. Their completed fractions in t days are t/12 and t/6, summing to 1."),
    (132,[490,96,890,375],"Mark owns 1/4 of a shelf's books and Kevin owns 1/3. Kevin owns 9 more than Mark; Lori owns the rest. How many books does Lori own?",[],"45","(1/3 − 1/4)T = 9 gives T = 108. Lori has (1 − 1/4 − 1/3)T = 45."),
    (132,[490,380,890,687],"Pipe A fills a tank in 4 hours and pipe B in 6 hours. How many minutes do they need together?",[],"144","Combined rate is 1/4 + 1/6 = 5/12 tank/hour; time = 12/5 hours = 144 minutes."),
    (132,[490,692,890,915],"A flask has 24 mL of 30% acid solution. How many mL of 8% solution makes it 16% acid?",[],"42","0.30(24) + 0.08x = 0.16(24 + x) gives x = 42."),
  ],
  2: [
    (133,[75,142,465,405],"Which expression is the square of the sum of x and y, decreased by their product?",["x² + y² − xy","x²y² − xy","(x + y)² − (x + y)","(x + y)² − xy"],"D","Square the sum first, then subtract the product xy: (x + y)² − xy."),
    (133,[75,410,465,735],"An internet provider charges each customer a $100 setup fee plus $50 per month. If c customers each stay m months, what is their combined bill?",["100c + 50m","100c + 50cm","150cm","100m + 50cm"],"B","Setup contributes 100c; monthly charges are 50cm, totaling 100c + 50cm."),
    (133,[75,738,465,1040],"A plane descends from 24,500 feet to 17,900 feet in 12 minutes at a constant rate. Which gives altitude A after t minutes?",["A = 17,900 − 550t","A = 17,900 + 550t","A = 24,500 − 550t","A = 24,500 + 550t"],"C","The descent rate is (24,500 − 17,900)/12 = 550 feet/minute, from 24,500 initially."),
    (133,[485,142,880,440],"A customer buys four times as many $2.86 bags of rice as $3.41 bags of pasta and spends $103.95. How many bags of rice?",[],"28","Let pasta bags be p. Then (4·2.86 + 3.41)p = 103.95, so p = 7 and rice bags = 28."),
    (133,[485,445,880,725],"A team won 4 of its first 15 games, then won all N remaining games. If it won half its games overall, find N.",[],"7","(4 + N)/(15 + N) = 1/2, so 8 + 2N = 15 + N and N = 7."),
    (133,[485,730,880,1020],"A school pays $1,720 for its first 80 books, then a lower rate per extra book; 200 books cost $3,700. Which cost function applies for x ≥ 80?",["f(x) = 18.50x + 240","f(x) = 18.50x + 1,720","f(x) = 16.50x + 400","f(x) = 16.50x + 1,720"],"C","Each extra copy costs (3700 − 1720)/(200 − 80) = 16.50; f(x) = 1720 + 16.50(x − 80) = 16.50x + 400."),
    (134,[90,90,480,370],"A group of n volunteers plants 180 trees in 5 hours, spending 15 minutes per tree. Which equation models the total work?",["(180/15)n = (5)(60)","(60/15)n = (180)(5)","(5)(60)n = (180)(15)","(5)(15)n = (180)(60)"],"C","The total volunteer minutes 5·60·n equal the tree minutes 180·15."),
    (134,[90,372,480,825],"A hose fills 1/3 of a tub per minute and an open drain empties 2/11 per minute. Which equation gives the fill time t with both running?",["t/3 − 2/11 = 1","1/3 − 2/11 = 1/t","t/3 + 2/11 = 1","1/3 + 2/11 = 1/t"],"B","Net fill rate equals 1/3 − 2/11 tubs/minute, or 1/t."),
    (134,[90,830,480,1160],"On a line segment A–B–C–D, AC = x, BD = y, BC = 10 and AD = 50. Which equation relates the lengths?",["x + y + 10 = 50","x + y − 5 = 50","x + y − 10 = 50","x + y − 20 = 50"],"C","AC + BD counts the shared BC twice, so AD = x + y − BC = x + y − 10."),
    (134,[495,90,890,435],"An accounting company has three times as many junior as senior accountants. It hires 140 seniors so juniors become twice the number of seniors. How many juniors were there originally?",[],"840","With s original seniors, 3s = 2(s + 140), so s = 280 and juniors = 840."),
    (134,[495,438,890,904],"Alice packs 10 boxes every 3 hours and Trinity packs 15 every x hours. Together they pack 115 boxes in 12 hours. Which equation is true?",["115(3/10 + x/15) = 12","12(3/10 + x/15) = 115","12(10/3 + 15/x) = 1","12(10/3 + 15/x) = 115"],"D","Their combined rate is 10/3 + 15/x boxes/hour, so 12 times this rate equals 115 boxes."),
    (134,[495,904,890,1130],"A bakery distributed $1, $3, and $5 coupons totaling $360. There were twice as many $1 as $3 coupons, and three times as many $3 as $5. How many $3 coupons?",["40","45","48","54"],"D","Let $5 coupons be n. Then $3 coupons = 3n and $1 coupons = 6n. Their value is (5 + 9 + 6)n = 360; n = 18, giving 54 $3 coupons."),
    (135,[85,95,470,384],"Yoona runs 1 yard per second, and Jessica runs four times as fast. Yoona has a 30-yard head start. How far must Jessica run to catch her?",[],"40","In t seconds, 4t = 30 + t, so t = 10 seconds and Jessica runs 40 yards."),
    (135,[85,388,470,660],"A jar has 200 jellybeans, 70% green. How many green beans must be removed so 60% of those left are green?",[],"50","Start with 140 green. Solve (140 − x)/(200 − x) = 0.6 to get x = 50."),
    (135,[85,665,470,1100],"A club of m members splits rent r equally. If k members fail to pay, which expression gives the extra amount each remaining member owes?",["r/(m − k)","kr/(m − k)","kr(m − k)/m","kr/[m(m − k)]"],"D","The new share minus the original is r/(m − k) − r/m = kr/[m(m − k)]."),
    (135,[495,95,890,690],"Terry paved 1/3 of a lot before Andy joined. The equation 9(1/x + 1/(x + 4)) = 2/3 models their work. What does 9 represent?",["Days to pave the whole lot together","Days to pave the remaining lot together","Days for Andy to pave the remainder alone","Days for Terry to pave the remainder alone"],"B","Combined daily rate times 9 days equals the remaining 2/3 of the lot, so 9 is their shared work time."),
    (135,[495,694,890,910],"How many mL of 25% alcohol solution should be mixed with 50% solution to make 800 mL of 40% solution?",[],"320","Set 0.25x + 0.50(800 − x) = 0.40(800). Solving gives x = 320 mL."),
  ],
}

out=[]
for exercise, entries in rows.items():
    for n,(page,rect,stem,choices,correct,explanation) in enumerate(entries,1):
        out.append(dict(exercise=exercise,n=n,page=page,rect=rect,stem=stem,
                        choices=choices,correct=correct,explanation=explanation))
assert len(out)==34
Path(__file__).with_name('questions.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
