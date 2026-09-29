// Formula lessons for the Final Revision tab. Source wording is retained where
// correct; formulas below use explicit conditions and corrected notation.
// This file contains only authored curriculum content, never student data.
const REVISION_FORMULA_TRACKS = {
  sat: {
    title: 'Digital SAT Math',
    intro: 'Use these as revision lessons alongside the SAT question bank. Every SAT question is in one of four domains; the approximate shares below are College Board guidance, not a promise about an individual test.',
    facts: [
      'The SAT Math section has two 35-minute modules and 44 questions total, including pretest questions. The section includes multiple-choice and student-produced-response questions.',
      'Approximate domain shares: Algebra 35%, Advanced Math 35%, Problem-Solving and Data Analysis 15%, Geometry and Trigonometry 15%. These are approximate distributions.',
      'Bluebook provides an embedded calculator and a reference sheet during Math. Desmos is available in the testing app; practise choosing when graphing helps and when algebra is quicker.',
      'Desmos angle mode matters: choose degrees for degree questions; use radians for radian questions. Graphing can check solutions, intersections, vertices, regression and inequalities.'
    ],
    lessons: ['Desmos calculator guidance','Linear functions and slope','Systems of equations','Inequalities and absolute value','Quadratics and polynomials','Functions and transformations','Exponents, radicals and growth','Ratios, percentages and unit conversion','Statistics and data analysis','Probability and conditional probability','Geometry and triangles','Trigonometry','Circles','Area and perimeter','Volume and surface area']
  },
  est: {
    title: 'EST Math I',
    intro: 'EST Math I is a unified math section. The official EST FAQ says calculators are allowed throughout the Math section. Follow the instructions for the specific sitting for its current format and timing.',
    facts: [
      'The EST FAQ describes EST I Math as a unified section with calculator use allowed throughout. The supplied revision bank uses a 50-question, 75-minute practice format; that is the portal practice format, not a claim about every official sitting.',
      'The lessons below organize the supplied EST mind maps and revision notes by topic. Topic coverage in a revision guide does not by itself establish official question weighting.',
      'For multi-step unit problems, keep units visible on every line. Convert first, then calculate; a correct number with the wrong unit is not a complete answer.'
    ],
    lessons: ['Triangles and similarity','Trigonometry','Angles and polygons','Area and perimeter','Volume and surface area','Circles','Linear functions and slope','Systems of equations','Inequalities and absolute value','Quadratics and polynomials','Functions and transformations','Polynomial division and remainder','Complex numbers','Exponents and special products','Percentages and interest','Ratio, proportion and rates','Sequences','Statistics and data analysis','Probability and conditional probability','Unit conversions']
  },
  est2: {
    title: 'EST Math II',
    intro: 'EST II is a subject-based test. These lessons collect the advanced material present in the supplied EST II questions and revision notes. Check the official EST guidance for the current sitting before relying on a test-length or timing assumption.',
    facts: [
      'The official EST FAQ identifies EST II as a subject-based test and lists Math Level 1 and Math Level 2 among its subject tests.',
      'This track includes advanced extensions such as polynomial behavior, complex arithmetic, inverse functions, logarithm rules, counting restrictions and non-right-triangle trigonometry.',
      'Some conventions (for example, quartiles for a short data set) can differ by course or calculator. Use the convention stated in the question or by your instructor.'
    ],
    lessons: ['Triangles and similarity','Trigonometry and trig graphs','Angles and polygons','Area and perimeter','Volume and surface area','Circles and power of a point','Linear functions and slope','Systems of equations','Inequalities and absolute value','Quadratics and polynomials','Functions, inverses and asymptotes','Polynomial division and remainder','Complex numbers','Exponents and special products','Logarithms and exponentials','Percentages and interest','Ratio, proportion and rates','Sequences','Statistics and data analysis','Probability, permutations and combinations','Unit conversions']
  }
};

const REVISION_FORMULA_LESSONS = {
  'Linear functions and slope': {
    formulas: ['Slope: m = (y₂ − y₁) / (x₂ − x₁), when x₂ ≠ x₁; on one line it is the same for every pair of distinct points. In a table, set slopes between pairs equal to solve for a missing value.', 'Slope-intercept: y = mx + b. Point-slope: y − y₁ = m(x − x₁). Constant rate of change or steady increase/decrease is the slope.', 'Standard form Ax + By = C: if B ≠ 0, m = −A/B. In ay + bx = c, m = −b/a; in ay = bx + c, m = b/a (when a ≠ 0).', 'Parallel nonvertical lines have equal slopes. Perpendicular nonvertical lines have slopes whose product is −1. Distance: d = √((x₂ − x₁)² + (y₂ − y₁)²). Midpoint: ((x₁ + x₂)/2, (y₁ + y₂)/2).'],
    example: 'From (0, 1) and (5, 2), m = 1/5, so the line is y = x/5 + 1. In a context, slope is the change in output per one unit of input; b is the output at x = 0.',
    notes: ['A vertical line x = c has undefined slope; a horizontal line y = c has slope 0. A line perpendicular to a vertical line is horizontal.', 'In Ax + By = C, if B = 0 the line is vertical, so do not use −A/B. Label rise and run before calculating.', 'The y-intercept is (0, b); find the x-intercept by setting y = 0. A word-problem constant rate is the change in output for each one-unit increase in input.'], visual: 'line'
  },
  'Systems of equations': {
    formulas: ['A solution is an ordered pair that satisfies every equation; graphically, it is an intersection.', 'For y = m₁x + b₁ and y = m₂x + b₂: different slopes → one intersection; same slope with different intercepts → no solution; same slope and intercept → infinitely many.', 'For a₁x + b₁y = c₁ and a₂x + b₂y = c₂, proportional x- and y-coefficients but a different constant ratio mean parallel lines and no solution; all three ratios equal mean the same line and infinitely many solutions.', 'For a line and a curve, substitute one equation into the other. The resulting real roots give the intersection x-values.'],
    example: 'y = 2x + 3 and y = 2x − 1 have the same slope but different intercepts, so they are parallel and have no solution.',
    notes: 'Coefficient-ratio shortcuts assume equations are written consistently and denominators in the ratios are nonzero. Substitution or elimination handles zero coefficients safely. Use a graph as a check; closely spaced intersections may be hard to read exactly.', visual: 'system'
  },
  'Inequalities and absolute value': {
    formulas: ['Adding or subtracting the same value preserves an inequality. Multiplying or dividing by a negative reverses the inequality sign.', '|u| = k (k ≥ 0): u = k or u = −k. |u| < k (k > 0): −k < u < k. |u| > k (k ≥ 0): u < −k or u > k. The graph y = |x − h| + k is a V with vertex (h, k).', 'y > mx + b: dashed boundary, shade above. y ≥ mx + b: solid boundary, shade above. Reverse above/below for < and ≤.'],
    example: '−2x > 6 gives x < −3 after dividing by −2 and reversing the sign. |x − 3| ≤ 2 gives 1 ≤ x ≤ 5.',
    notes: 'If k < 0, |u| = k has no solution; |u| < k has no solution; |u| > k is always true. For a compound inequality, AND means intersection and OR means union. A test point such as (0, 0) can identify a shaded half-plane.', visual: 'inequality'
  },
  'Quadratics and polynomials': {
    formulas: ['Standard form y = ax² + bx + c has y-intercept c; factored form y = a(x − r₁)(x − r₂) shows x-intercepts r₁, r₂; vertex form y = a(x − h)² + k shows vertex (h, k). Axis: x = −b/(2a).', 'Quadratic formula: x = (−b ± √(b² − 4ac)) / (2a). Discriminant Δ = b² − 4ac: Δ > 0 two distinct real roots; Δ = 0 one repeated real root; Δ < 0 no real roots.', 'For ax² + bx + c = 0: sum of roots = −b/a; product = c/a. If a > 0 the graph opens up and has a minimum; if a < 0 it opens down and has a maximum. Larger |a| makes it narrower; 0 < |a| < 1 makes it wider.', 'Remainder theorem: dividing P(x) by (x − r) leaves remainder P(r). Factor theorem: (x − r) is a factor exactly when P(r) = 0.'],
    example: 'For y = x² − 4x + 1, the axis is x = 2, and f(2) = −3, so the vertex is (2, −3). Since a > 0, it is a minimum.',
    notes: 'Identify a, b and c including signs before using the quadratic formula. “Tangent” to the x-axis means Δ = 0 only when solving the quadratic for its x-intercepts. A repeated factor touches the axis; odd multiplicity crosses it.', visual: 'parabola'
  },
  'Functions and transformations': {
    formulas: ['f(a) = b means the graph includes (a, b). (f ± g)(a) = f(a) ± g(a); (fg)(a) = f(a)g(a); (f/g)(a) = f(a)/g(a), where g(a) ≠ 0. Composition (f ∘ g)(x) = f(g(x)); evaluate inside first.', 'Domain restrictions: denominator ≠ 0; an even root requires its radicand ≥ 0; an even root in a denominator requires its radicand > 0.', 'f(x) + k shifts up k; f(x) − k shifts down k; f(x − h) shifts right h; f(x + h) shifts left h. −f(x) reflects across the x-axis; f(−x) reflects across the y-axis.', 'For a quadratic with vertex y-value v: if a > 0, range is [v, ∞); if a < 0, range is (−∞, v]. For a rational function, cancel common factors before identifying vertical asymptotes; a cancelled zero is a hole.'],
    example: 'For f(x) = 3x + 5, f(2) = 11. For g(x) = √(x + 1), the real domain is x ≥ −1.',
    notes: ['For a simplified rational function with numerator degree n and denominator degree d: n < d gives horizontal asymptote y = 0; n = d gives the ratio of leading coefficients; n = d + 1 gives a slant asymptote from division. If n > d + 1, polynomial division gives a higher-degree polynomial asymptote, not a horizontal one.', 'A vertical line test determines whether a graph is a function: every vertical line must meet it at most once. Read f(a) as the y-value at x = a. For f(g(x)), evaluate the inner function first.', 'For x/(x + 5), exclude x = −5; for √(x + 1), require x ≥ −1; for 1/√(x + 5), require x > −5.'], visual: 'transform'
  },
  'Exponents, radicals and growth': {
    formulas: ['Same nonzero base: aᵐ · aⁿ = aᵐ⁺ⁿ; aᵐ/aⁿ = aᵐ⁻ⁿ (a ≠ 0); (aᵐ)ⁿ = aᵐⁿ; a⁰ = 1 (a ≠ 0); a⁻ⁿ = 1/aⁿ.', 'For a > 0, aᵐ⁄ⁿ = ⁿ√(aᵐ). For even n over the reals, require a ≥ 0. √(x²) = |x|, not always x.', 'Growth: A(t) = A₀(1 + r)ᵗ. Decay: A(t) = A₀(1 − r)ᵗ, for a rate r written as a decimal.'],
    example: '500 growing by 3% each year is A(t) = 500(1.03)ᵗ. A 20% decrease uses the factor 0.80.',
    notes: 'A negative exponent means reciprocal, not a negative value. When taking even roots or squaring both sides, check candidate answers in the original equation. Growth/decay rates must use decimal form: 3% = 0.03.', visual: 'growth'
  },
  'Ratios, percentages and unit conversion': {
    formulas: ['Percent = (part / whole) × 100%. Percent change = ((new − original) / original) × 100%.', 'New value after p% increase/decrease = original × (1 ± p/100). Successive changes multiply their factors.', 'Direct variation: y = kx. Inverse variation: y = k/x (equivalently xy = k, x ≠ 0). Rate = quantity / time; speed = distance / time.', 'Convert by multiplying by a ratio equal to 1, oriented so the starting unit cancels.'],
    example: '60 miles/hour × (1 hour / 60 minutes) = 1 mile/minute. A 20% increase followed by a 20% decrease multiplies by 1.20 × 0.80 = 0.96, a net 4% decrease.',
    notes: 'Use the original value in the denominator for percent change. Do not add successive percentage changes directly. Common exact factors: 1 km = 1000 m; 1 m = 100 cm; 1 kg = 1000 g; 1 L = 1000 mL; 1 hour = 60 minutes = 3600 seconds; 1 day = 24 hours; 1 inch = 2.54 cm; 1 foot = 12 inches; 1 yard = 3 feet; 1 mile = 5280 feet. For temperature, °F = (9/5)°C + 32. Keep approximate customary conversions marked approximate.', visual: 'units'
  },
  'Statistics and data analysis': {
    formulas: [
      'Centre: mean = sum / count; median = middle value after sorting (or the mean of the two middle values); mode = most frequent value.',
      'Spread: range = maximum − minimum; IQR = Q₃ − Q₁, where Q₁ and Q₃ are the medians of the lower and upper halves under the stated quartile convention.',
      'Standard deviation (SD): small SD means values lie close to the mean; large SD means values are more spread out. SD is measured in the same units as the data.',
      'Scatter plots: a line of best fit gives predicted values; plotted points are actual values. Residual = actual − predicted = the vertical difference from the point to the line.',
      'Adding c to every value shifts the mean and median by c but leaves range, IQR and SD unchanged. Multiplying every value by c scales range, IQR and SD by |c|.',
      'Margin of error: a larger sample or lower variability generally reduces it; a smaller sample or higher variability generally increases it.'
    ],
    examples: [
      'For 2, 4, 4, 7, 9: mean = 26/5 = 5.2, median = 4, mode = 4 and range = 7.',
      'Daily lows 17, 22, 21, 18, 22, 28, 17, 21, 26, 38, 31, 26, 19, 26: stem 2 has leaves 1, 1, 2, 2, 6, 6, 6, 8.'
    ],
    notes: [
      'Sort before finding the median, quartiles or a stem-and-leaf display. For an even count, Q₁ and Q₃ are the medians of the lower and upper halves. For an odd count, follow the convention named in the question.',
      'An outlier can move the mean and range substantially; the median is more resistant. Adding a constant shifts the mean and median but does not change SD or IQR. Multiplying all values by c scales spread measures by |c|.',
      'A box plot shows the five-number summary: minimum, Q₁, median, Q₃ and maximum. The box width represents IQR. Skew direction follows the long tail: a left tail often has mean < median; a right tail often has mean > median.',
      'Scatter direction describes association, not causation: an upward pattern is positive, a downward pattern is negative, and a diffuse cloud has little linear association. Positive residuals lie above the fitted line; negative residuals lie below it.',
      'A stem-and-leaf display keeps every value visible. Sort the leaves within each stem and include a key: 2 | 1 = 21°F.',
      'Sampling terms: systematic selects at regular intervals; stratified samples from each subgroup; simple random selects at random from the full population.',
      'Margin of error generally falls with a larger sample or lower variability, and rises with a smaller sample or greater variability.'
    ],
    visual: 'boxplot', visuals: ['boxplot', 'stddev', 'scatter', 'stemleaf']
  },
  'Probability and conditional probability': {
    formulas: ['P(A) = favourable outcomes / all equally likely outcomes, with 0 ≤ P(A) ≤ 1. Complement: P(not A) = 1 − P(A).', 'Addition rule: P(A or B) = P(A) + P(B) − P(A and B). For mutually exclusive events, the overlap is 0.', 'Multiplication rule: P(A and B) = P(A)P(B | A). For independent events, this becomes P(A)P(B).', 'Conditional probability: P(A | B) = P(A and B) / P(B), provided P(B) > 0. At least one = 1 − P(none).', 'Counting principle: multiply choices across independent stages. nPr = n!/(n − r)! when order matters; nCr = n!/[r!(n − r)!] when order does not matter.', 'Distinct arrangements: n!. With repeated objects: n!/(k₁!k₂!…). Fix required starting/ending letters first; for letters together, treat the group as one block and multiply by its internal arrangements.'],
    examples: ['If 30 of 70 males passed, then P(pass | male) = 30/70: the denominator is the male total because “male” is the given group.', 'A fair coin has P(heads) = 1/2. A fair die has P(even) = 3/6 = 1/2. Two dice have 6 × 6 = 36 ordered outcomes. A standard deck has 52 cards: 26 red, 26 black, 13 in each suit, and 4 of each rank.', 'From a bag with 3 red, 5 blue and 2 green (10 total): P(two reds without replacement) = 3/10 × 2/9; P(red then blue) = 3/10 × 5/9. On one draw, P(red or blue) = 3/10 + 5/10 = 8/10.', 'Five shirts, three pants and two pairs of shoes make 5 × 3 × 2 = 30 outfits. A committee of 2 from 8 is 8C2 = 28; choosing president and vice-president from 8 is 8P2 = 56. A 2-person committee with at least one doctor from 3 doctors and 5 engineers has 3C1·5C1 + 3C2·5C0 = 18 choices.', 'CHEESE has 6!/3! distinct arrangements. For “at least one,” use 1 − P(none) when that is shorter.'],
    notes: ['Without replacement, update the total and category counts after each draw. “AND” is not automatically multiplication of independent probabilities; use the conditional multiplication rule. “OR” requires subtracting an overlap unless the events cannot happen together.', 'For two-way tables, a conditional probability denominator is the total in the stated group. A probability must stay between 0 and 1.', 'Word arrangements: “starts with” means fix the letter; “together” means make a block; “not together” can be total minus together. Divide by factorials for repeated letters.'], visual: 'tree'
  },
  'Geometry and triangles': {
    formulas: ['Triangle interior angles sum to 180°. The sum of the two shorter sides must be greater than the longest side; for a third side x, |a − b| < x < a + b.', 'A straight angle = 180°; a full turn = 360°; vertical angles are equal. An exterior angle of a triangle equals the sum of the two remote interior angles.', 'Triangle area = ½bh. For a right triangle a² + b² = c², with c the hypotenuse.', 'Isosceles: equal sides face equal angles. Equilateral: all sides equal and every angle is 60°. Special right triangles: 45°–45°–90° sides x, x, x√2; 30°–60°–90° sides x, x√3, 2x (short, long, hypotenuse).', 'Similar triangles have equal corresponding angles and proportional corresponding sides. Side scale factor k gives perimeter ratio k, area ratio k², and volume ratio k³ for similar solids.', 'Altitude to the hypotenuse: if it divides hypotenuse c into p and q, then h² = pq; each leg squared equals c times its adjacent hypotenuse segment.'],
    examples: ['Sides 5 and 13 give a third side 8 < x < 18; if x is a whole number, the smallest possible value is 9.', 'For sides 6, 8, 10: 6² + 8² = 10², so the triangle is right. Compare the two shorter sides’ squares with the longest side’s square to classify any triangle.', 'A 3:5 side ratio gives area ratio 9:25; for similar 3D solids it gives volume ratio 27:125. If the area ratio is 9:64, the side ratio is 3:8.', 'A 30°–60°–90° triangle with hypotenuse 12 has short leg 6 and long leg 6√3.'],
    notes: ['For a possible triangle, check that the sum of the two smallest sides is greater than the largest. For a third side x, use the strict bounds |a − b| < x < a + b.', 'For acute/right/obtuse classification, let c be the longest side and compare a² + b² with c²: greater → acute, equal → right, less → obtuse.', 'Congruence tests: SSS, SAS, ASA and AAS. AAA proves similarity, not congruence; SSA is not a general congruence test. A median joins a vertex to the opposite side’s midpoint; an altitude meets the opposite side at 90° (and can fall outside an obtuse triangle); an angle bisector splits an angle in half.', 'Match corresponding vertices before writing side ratios. Keep the same small-to-large order in every proportion. Isosceles equal sides face equal angles.'], visual: 'triangle', visuals: ['triangle', 'specialtriangles']
  },
  'Trigonometry': {
    formulas: ['Right triangle only: sin θ = opposite/hypotenuse; cos θ = adjacent/hypotenuse; tan θ = opposite/adjacent = sin θ/cos θ.', 'Reciprocals: csc θ = 1/sin θ; sec θ = 1/cos θ; cot θ = 1/tan θ.', 'sin²θ + cos²θ = 1; 1 + tan²θ = sec²θ; 1 + cot²θ = csc²θ.', 'Degrees to radians: degrees × π/180. Radians to degrees: radians × 180/π. In a sine graph y = A sin(Bx + C) + D: amplitude = |A|, period = 2π/|B|, phase shift = −C/B, midline y = D.'],
    example: 'In a 3–4–5 right triangle, for the angle opposite the side of length 3: sin θ = 3/5, cos θ = 4/5, tan θ = 3/4.',
    notes: 'For a non-right triangle, label each side opposite its matching capital angle. Sine law: a/sin A = b/sin B = c/sin C. Cosine law: a² = b² + c² − 2bc cos A. These identities use matched opposite pairs; do not write sin(a)/A. On calculator questions, check degree/radian mode.', visual: 'trig'
  },
  'Circles': {
    formulas: ['Circumference C = 2πr = πd; area A = πr². A tangent is perpendicular to the radius at the point of tangency. The diameter is the longest chord; among chords of one circle, the chord nearer the centre is longer.', 'Central angle = intercepted arc. An inscribed angle = half its intercepted arc (and half the matching central angle). A semicircle is 180°; a minor arc is less than 180° and a major arc is greater than 180°.', 'Degree measure: arc length = (θ/360°)·2πr; sector area = (θ/360°)·πr². Radian measure: arc = rθ; sector area = ½r²θ.', 'Circle equation: (x − h)² + (y − k)² = r²; centre (h, k), radius r. For x² + y² + Dx + Ey = F, centre = (−D/2, −E/2), radius = √((D/2)² + (E/2)² + F).'],
    examples: ['For centre (3, −2) and radius 5: (x − 3)² + (y + 2)² = 25. The signs inside the brackets reverse when reading the centre.', 'For x² + y² − 6x + 4y = 12, complete squares: (x − 3)² + (y + 2)² = 25, so centre (3, −2) and radius 5.', 'With θ = 90° and r = 6, arc length = 3π and sector area = 9π.'],
    notes: ['Angles formed by chords crossing inside a circle equal half the SUM of the intercepted arcs. Angles formed by secants meeting outside equal half the far-minus-near arc DIFFERENCE. A vertex on the circle gives an inscribed angle: half its intercepted arc.', 'Power of a point: intersecting chords inside: (part)(part) = (part)(part); two secants from outside: (outside)(whole) = (outside)(whole); tangent-secant: tangent² = (outside)(whole).', 'Complete the square separately for x and y when converting general form. Arc and sector formulas require the angle unit shown: degrees in the fraction formulas, radians in rθ and ½r²θ.'], visual: 'circle'
  },
  'Area and perimeter': {
    formulas: ['Rectangle A = LW; P = 2(L + W). Square A = s²; P = 4s.', 'Triangle A = ½bh. Parallelogram A = bh. Trapezoid A = ½(b₁ + b₂)h.', 'Rhombus or kite A = ½d₁d₂. Equilateral triangle A = (√3/4)s².', 'Regular polygon A = ½(apothem)(perimeter). Perimeter is the sum of all side lengths.'],
    example: 'A trapezoid with parallel sides 6 and 10 and height 4 has area ½(6 + 10)·4 = 32 square units.',
    notes: 'Height is perpendicular to the chosen base. Do not use a slanted side as height unless it is perpendicular. Doubling all lengths multiplies perimeter by 2 and area by 4.', visual: 'area'
  },
  'Volume and surface area': {
    formulas: ['Prism or cylinder: V = Bh. Rectangular prism: V = LWh; cylinder: V = πr²h.', 'Pyramid or cone: V = ⅓Bh. Cone: V = ⅓πr²h.', 'Sphere: V = (4/3)πr³; surface area = 4πr². Hemisphere: V = (2/3)πr³; curved area = 2πr²; total area = 3πr².', 'Right cone slant height ℓ = √(r² + h²). Cone lateral area = πrℓ; total area = πr² + πrℓ. Cylinder total area = 2πr² + 2πrh.'],
    example: 'A cylinder with radius 3 and height 5 has volume π·3²·5 = 45π cubic units.',
    notes: 'B is the area of the base. Lateral area excludes the base(s); total surface area includes the exposed base(s). Area uses square units; volume uses cubic units. Similar solids with linear scale factor k have volume scale k³.', visual: 'solid'
  },
  'Angles and polygons': {
    formulas: ['Interior-angle sum of an n-sided polygon = 180°(n − 2). For a regular n-gon, each interior angle = 180°(n − 2)/n.', 'Sum of one exterior angle at each vertex = 360°. For a regular n-gon, each exterior angle = 360°/n.', 'Number of diagonals = n(n − 3)/2; diagonals from one vertex = n − 3.', 'With parallel lines cut by a transversal: corresponding and alternate interior angles are equal; same-side interior angles sum to 180°.'],
    example: 'A regular hexagon has interior sum 720°, each interior angle 120°, each exterior angle 60°, and 9 diagonals.',
    notes: '“Regular” means all sides and all interior angles are equal. Exterior-angle sum remains 360° for any convex polygon when one exterior angle is taken at each vertex.', visual: 'polygon'
  },
  'Triangles and similarity': {
    formulas: ['Triangle interior angles sum to 180°; area = ½bh. An exterior angle equals the sum of the two remote interior angles. For a right triangle, a² + b² = c² with c the hypotenuse.', 'Triangle inequality: for third side x and other sides a, b, |a − b| < x < a + b. Isosceles triangle: equal sides face equal angles. Equilateral: three equal sides and three 60° angles.', 'Special right triangles: 45°–45°–90° sides x, x, x√2. 30°–60°–90° sides x, x√3, 2x (short leg, long leg, hypotenuse).', 'Similar triangles have equal corresponding angles and proportional corresponding side lengths. Similarity tests are AA, proportional SSS, or proportional SAS with equal included angles.', 'For right-triangle altitude to hypotenuse: with hypotenuse c split into segments p and q, h² = pq; each leg squared = c times its adjacent hypotenuse segment.'],
    examples: ['For sides 6, 8 and 10, 6² + 8² = 10², so the triangle is right. Compare the squares of the two shorter sides with the longest side’s square to classify a triangle.', 'A 30°–60°–90° triangle with hypotenuse 12 has short leg 6 and long leg 6√3.'],
    notes: ['For a possible triangle, check that the sum of the two smallest sides is greater than the largest. For a third side x, use the strict bounds |a − b| < x < a + b. Classify by comparing the two shorter sides’ squares to the longest side’s square: greater → acute, equal → right, less → obtuse.', 'Match corresponding vertices before writing a proportion. Keep the same small-to-large order in every ratio. Congruence tests are SSS, SAS, ASA and AAS; AAA is similarity only, and SSA is not a general congruence test.', 'If side scale factor is small:large = a:b, perimeters scale a:b, areas scale a²:b² and volumes of similar solids scale a³:b³. A line parallel to one side of a triangle creates a smaller triangle similar to the whole triangle.', 'A median joins a vertex to the opposite side’s midpoint; an altitude meets the opposite side at 90° and can fall outside an obtuse triangle; an angle bisector splits an angle in half.'], visual: 'triangle', visuals: ['triangle', 'specialtriangles']
  },
  'Polynomial division and remainder': {
    formulas: ['Polynomial division: dividend = divisor × quotient + remainder; the remainder degree is less than the divisor degree.', 'Remainder on division by (x − a) is P(a). (x − a) is a factor exactly when P(a) = 0.', 'For a rational function whose numerator degree is exactly one more than its denominator degree, polynomial division gives a slant asymptote; discard only the proper fractional remainder when writing that asymptote.'],
    example: 'For P(x) = x³ + 5x + 10 divided by x − 5, the remainder is P(5) = 160; no long division is needed to find it.',
    notes: 'Synthetic division uses a for divisor x − a and −a for divisor x + a. Include zero coefficients for missing powers. A repeated zero may touch the x-axis; inspect multiplicity.', visual: 'polynomial'
  },
  'Complex numbers': {
    formulas: ['i² = −1. A complex number is a + bi, with real part a and imaginary coefficient b.', 'Conjugate: a + bi ↔ a − bi. Product of conjugates = a² + b².', '|a + bi| = √(a² + b²).', '(a + bi)/(c + di) = ((ac + bd)/(c² + d²)) + ((bc − ad)/(c² + d²))i, when c² + d² ≠ 0.'],
    example: '(5 + 10i)/(2 + 3i): multiply by (2 − 3i)/(2 − 3i) to get 40/13 + (5/13)i.',
    notes: ['When complex numbers are equal, match real parts and imaginary coefficients separately. Powers of i repeat every four: i, −1, −i, 1; divide the exponent by 4 and use the remainder to select the value.', 'On a calculator that supports complex arithmetic, select CMPLX/complex mode before evaluating. Multiplying by the conjugate makes a complex denominator real: (a + bi)(a − bi) = a² + b².'], visual: 'complex'
  },
  'Exponents and special products': {
    formulas: ['(x + y)² = x² + 2xy + y²; (x − y)² = x² − 2xy + y².', 'x² − y² = (x − y)(x + y).', 'x² + y² = (x + y)² − 2xy.', 'For aᵐ = aⁿ ⇒ m = n only when the base conditions make the exponential function one-to-one (for real exponents, a > 0 and a ≠ 1).'],
    example: 'If x + y = 6 and xy = 5, then x² + y² = 6² − 2·5 = 26.',
    notes: 'Do not confuse (x + y)² with x² + y²; the middle term 2xy is essential. The equation 1ˣ = 1 does not determine x.', visual: 'products'
  },
  'Percentages and interest': {
    formulas: ['Percent = (part / whole) × 100%. New = original(1 ± r), with r as a decimal. Percent change = (new − original)/original × 100%.', 'Compound once per year: A = P(1 + r)ᵗ. Compounded n times per year: A = P(1 + r/n)ⁿᵗ. Compounded once every n years: A = P(1 + rn)ᵗ⁄ⁿ.', 'Simple interest: I = Prt; total A = P(1 + rt). Successive percent changes are applied by multiplying their factors.'],
    example: 'A 1000 deposit at 10% annual interest compounded twice in one year is 1000(1 + 0.10/2)² = 1102.50.',
    notes: ['Convert percent to decimal before substituting (10% = 0.10). In percent change, divide by the original amount. “Simple” interest adds the same interest each period; “compound” interest earns interest on accumulated interest.', 'If interest is compounded n times per year, use rate r/n and total n·t periods. Semiannual n = 2, quarterly n = 4, monthly n = 12.', 'When a question asks for revenue, revenue = price × quantity. Profit = revenue − total cost; “profit gained” in a simple-interest context is the interest earned. Apply discounts and tax as successive multipliers.'], visual: 'growth'
  },
  'Ratio, proportion and rates': {
    formulas: ['Sharing total T in ratio a:b:c: one part = T/(a + b + c); each share is its ratio number times one part.', 'Direct variation: y = kx. Inverse variation: y = k/x, so xy = k.', 'Work rate: if independent workers complete a job in times t₁ and t₂, combined rate = 1/t₁ + 1/t₂ jobs per unit time.', 'Average speed = total distance / total time, not generally the arithmetic mean of speeds.'],
    example: 'Share 2000 in the ratio 3:5:7: one part is 2000/15; shares are 400, 2000/3 and 2800/3.',
    notes: 'For linked ratios, scale both ratios until their shared quantity matches. For inverse proportion, identify the constant product from a known pair. Keep units attached to rates.', visual: 'ratio'
  },
  'Sequences': {
    formulas: ['Arithmetic sequence: aₙ = a₁ + (n − 1)d. Sum: Sₙ = n(a₁ + aₙ)/2.', 'Geometric sequence: aₙ = a₁rⁿ⁻¹. Finite sum for r ≠ 1: Sₙ = a₁(1 − rⁿ)/(1 − r).', 'Arithmetic: subtract consecutive terms. Geometric: divide consecutive nonzero terms.'],
    example: 'For 1, 3, 5, …, a₁₀ = 1 + 9·2 = 19 and S₁₀ = 10(1 + 19)/2 = 100.',
    notes: 'The exponent or difference multiplier is n − 1 because the first term is already a₁. Check whether the problem asks for the nth term or the sum of the first n terms.', visual: 'sequence'
  },
  'Probability, permutations and combinations': {
    formulas: ['Counting principle: multiply the number of choices at each independent stage.', 'Permutations (order matters): nPr = n!/(n − r)!. Combinations (order does not matter): nCr = n!/(r!(n − r)!).', 'Arrangements with repeated objects: n!/(k₁!k₂!…), where kᵢ are repeat counts.', 'For independent events, multiply probabilities. For mutually exclusive alternatives, add probabilities.'],
    example: 'A committee of 2 chosen from 8 people is 8C2 = 28. A president and vice-president from 8 people is 8P2 = 56.',
    notes: 'Use “at least one” = 1 − P(none) when the complement is simpler. Without replacement, the total shrinks after each draw. A two-way-table conditional probability denominator is the total in the stated group.', visual: 'tree'
  },
  'Unit conversions': {
    formulas: ['Conversion rule: multiply by a fraction equal to 1, written so the starting unit cancels. For a rate, convert numerator and denominator units separately; keep units attached through each step.', 'Metric: 1 km = 1000 m; 1 m = 100 cm = 1000 mm; 1 kg = 1000 g; 1 g = 1000 mg; 1 L = 1000 mL. Metric prefixes: kilo = 1000, centi = 1/100, milli = 1/1000.', 'Length: 1 inch = 2.54 cm exactly; 1 ft = 12 in; 1 yd = 3 ft; 1 mile = 5280 ft. Approximate: 1 mile ≈ 1.609 km; 1 ft = 0.3048 m.', 'US customary: 16 oz = 1 lb; 2000 lb = 1 US short ton; 1 US gallon = 4 US quarts = 8 US pints = 16 US cups = 128 US fluid ounces. 1 US gallon ≈ 3.785 L. Do not treat US and Imperial gallons as interchangeable.', 'Time: 1 min = 60 s; 1 h = 60 min = 3600 s; 1 day = 24 h; 1 week = 7 days. Angle: 180° = π radians.', 'Temperature is an offset conversion, not a simple multiply-only unit factor: °F = (9/5)°C + 32; °C = (5/9)(°F − 32).'],
    examples: ['Convert 2.5 days to seconds: 2.5 days × (24 h/1 day) × (60 min/1 h) × (60 s/1 min) = 216,000 s; the intermediate units cancel.', 'Convert 3.5 ft to inches: 3.5 ft × (12 in/1 ft) = 42 in. Convert 2.4 km to metres: 2.4 km × (1000 m/1 km) = 2400 m.', 'Area conversion squares the length factor: 1 m² = (100 cm)² = 10,000 cm². Volume conversion cubes it: 1 m³ = (100 cm)³ = 1,000,000 cm³.', 'For 60 miles per hour in miles per minute: (60 mi/1 h) × (1 h/60 min) = 1 mi/min.'],
    notes: ['Choose the conversion fraction direction by checking which unit should cancel. If the unwanted unit does not cancel, flip the fraction.', 'For area, square the conversion factor; for volume, cube it. Do not use 100 cm per metre as the area or volume factor by itself.', 'Some customary conversions are exact (12 inches = 1 foot); mile-to-kilometre and kilogram-to-pound values are approximate. Use the precision or conversion table given in the question.', 'Keep units on the answer, and check that the result is sensible: converting to a smaller unit usually gives a larger number. For temperature, apply the +32 offset; multiplying Celsius by 9/5 alone is incomplete.'], visual: 'units'
  },
  'Logarithms and exponentials': {
    formulas: ['Definition: log_b(x) = y exactly when bʸ = x, with b > 0, b ≠ 1 and x > 0.', 'Product: log_b(xy) = log_b x + log_b y. Quotient: log_b(x/y) = log_b x − log_b y.', 'Power: log_b(xᵏ) = k log_b x for x > 0. Change of base: log_b x = ln x / ln b.', 'Inverse facts: log_b(bˣ) = x; b^(log_b x) = x. ln is log base e.'],
    example: 'ln(e^(−5x)) = −5x. The exponent is brought down by the inverse relationship.',
    notes: 'Logarithm arguments must be positive. A sum of logarithms can combine into a product only when the base is the same. This is an EST II extension lesson; do not assume every test sitting includes it.', visual: 'growth'
  }
};

REVISION_FORMULA_LESSONS['Trigonometry and trig graphs'] = {
  ...REVISION_FORMULA_LESSONS.Trigonometry,
  notes: 'For y = A sin(Bx + C) + D or y = A cos(Bx + C) + D, amplitude = |A|, period = 2π/|B|, phase shift = −C/B and range = [D − |A|, D + |A|]. Tangent has period π/|B| and vertical asymptotes. Set calculator mode to match the angle units.'
};
REVISION_FORMULA_LESSONS['Functions, inverses and asymptotes'] = {
  formulas: ['To find f⁻¹, write y = f(x), swap x and y, then solve for y. Check by composing: f(f⁻¹(x)) = x on the appropriate domain.', 'A function has an inverse function on a domain only if it is one-to-one there. Restrict a many-to-one function to a one-to-one interval when needed.', 'For a reduced rational function, denominator zeros give vertical asymptotes. Compare numerator and denominator degrees for horizontal behavior; use polynomial division for slant or higher-degree asymptotes.', 'For an even-degree quadratic, the vertex gives the minimum when a > 0 and the maximum when a < 0. Its range begins or ends at the vertex y-value.'],
  example: 'If f(x) = 3x − 7, set y = 3x − 7, swap to x = 3y − 7, and solve: f⁻¹(x) = (x + 7)/3.',
  notes: 'A denominator zero that cancels with the numerator is a hole, not a vertical asymptote. A quadratic inverse usually requires restricting its domain because the full parabola is not one-to-one.', visual: 'transform'
};
REVISION_FORMULA_LESSONS['Circles and power of a point'] = {
  ...REVISION_FORMULA_LESSONS.Circles,
  formulas: [...REVISION_FORMULA_LESSONS.Circles.formulas, 'Power relationships: intersecting chords: AP·PB = CP·PD; two secants from an exterior point: (outside)(whole) = (outside)(whole); tangent-secant: tangent² = (outside)(whole).'],
  notes: 'For central and inscribed angles, use the intercepted arc: central angle equals its arc; an inscribed angle equals half its arc. In circle equations, the signs inside parentheses reverse when reading the centre.',
};

// Desmos guidance audited 2026-09-29. Matches the corrected SAT rules PDF.
// Official references: https://help.desmos.com/hc/en-us/articles/4407885334285-Inequalities-and-Restrictions
// https://help.desmos.com/hc/en-us/articles/30913914831757-Assessment-Resources-FAQ
REVISION_FORMULA_LESSONS['Desmos calculator guidance'] = {
  "formulas": [
    "Restrictions: append curly brackets, for example y=2x{0<x<10}. This limits the graph to 0<x<10.",
    "Use ≤ instead of < to include an endpoint. A restriction changes which points are graphed; zooming changes only the viewing window. Use Graph Settings to adjust axis bounds.",
    "Equations: enter y=left side and y=right side separately. Read the intersection x-values. A direct equation such as 2x+3=7 also graphs the vertical line x=2; select its x-intercept.",
    "Systems: graph both equations and select intersections to read (x,y). Adjust the window to find off-screen intersections and use algebra to confirm the total number of solutions.",
    "Tables: choose + then Table. For outputs, define f(x) and use f(x₁) as the second header. Enter chosen inputs in x₁. A blank y₁ column does not calculate outputs by itself.",
    "Sliders: enter y=ax+b and add sliders for a and b. Use them to explore possible values, then verify with algebra. In y=2x+k, k changes the intercept, not the slope.",
    "Inequalities: y>2x+1 shades above a dashed boundary. Use ≥ for a solid boundary that is included. For AND, use the overlap of shaded regions. For OR, use their union.",
    "Vertices and zeros: select the curve, then an available vertex or x-intercept. A zero can cross OR touch the x-axis. Displayed coordinates may be rounded; confirm exact values algebraically.",
    "Regression: enter paired x₁,y₁ data, then use y₁~mx₁+b or y₁~ax₁²+bx₁+c. Enter subscripts with _1. Keep parameter letters free of previous slider definitions.",
    "Predictions: after fitting a model, define f(x)=mx+b (or ax²+bx+c), then evaluate f(5) for the prediction at x=5. A best-fit line is an exact line through the points only when they are collinear.",
    "Composition: define f(x) and g(x) in separate rows, then enter f(g(x)) in a third row. After defining f(x), use y=a·f(x−h)+k with sliders to explore transformations.",
    "Powers: x^2, x^3. Fractions: (2x+1)/(x−3). Square roots: sqrt(x+5). For a cube root, type nthroot, enter 3 in the index, then x under the radical.",
    "Valid inputs include abs(x), sin(x), cos(x), tan(x), log(x) (base 10), ln(x), e^x and pi. The graph y=abs(x−3)+2 has vertex (3,2).",
    "Trigonometry: check Degrees or Radians in Graph Settings. In Radians, use sin(30*pi/180) for sin 30°. In Degrees, use sin(30); do not convert again.",
    "Circles: (x−3)²+(y+2)²=25 graphs a circle. Read centre (3,−2) and radius 5 from the equation. Plot (3,−2) to mark the centre; verify exact coordinates by substitution.",
    "Asymptotes: derive their equations algebraically, then graph those equations. Do not treat them as automatically labelled points of interest. Retain every original domain exclusion."
  ],
  "examples": [
    "Restrictions: y=2x{0<x<10} shows only the part with 0<x<10. The endpoints are excluded. Changing the axis bounds alone leaves the full line unchanged.",
    "One real root: for x²+kx+4=0, set k²−16=0. Both k=4 and k=−4 work. Sliders visualize these cases; the discriminant proves them.",
    "Parallel lines: against y=2x+3, the line y=2x+k has no solution when k≠3 and infinitely many when k=3. Changing k cannot change its slope.",
    "Exponential model: define f(x)=500(1.03)^x. Then f(10) is about 672. The intersection with y=1000 has x≈23.45, the time in years.",
    "Point and answer checks: to test (a,b) on y=f(x), compare f(a) with b. For an equation candidate, evaluate its left and right sides separately and compare."
  ],
  "notes": [
    "Choose graphing or algebra according to the question; neither method is always faster. A graph is a numerical check, not a symbolic proof.",
    "Graphs can hide close or off-screen intersections. Use the original equations and domain to confirm all solutions; rounded matches are not proof of exact equality.",
    "A graph of (x−3)(x+2) confirms zeros 3 and −2. Matching zeros alone does not prove that two polynomials are identical.",
    "Use the Graphing Calculator for these instructions. Practise with the College Board version linked by the SAT Desmos button; exam configurations may differ from standard Desmos.",
    "Checked 29 September 2026 against the Desmos Help Center articles Inequalities and Restrictions, Tables, Graph Settings, Regressions, Functions, Supported Functions, Sliders and Movable Points, Getting Started, and Assessment Resources & FAQ."
  ],
  "visual": "desmosRestrictions"
};

const REVISION_FORMULA_SVG = {
 desmosRestrictions: "<svg viewBox=\"0 0 420 250\" role=\"img\" aria-label=\"Line segment y equals 2x restricted to x strictly between zero and ten; open endpoints at zero zero and ten twenty\"><path d=\"M50 205H385M70 220V25\" stroke=\"#526277\" stroke-width=\"2\"/><path d=\"M70 205L330 45\" stroke=\"#087c91\" stroke-width=\"4\"/><g fill=\"white\" stroke=\"#087c91\" stroke-width=\"3\"><circle cx=\"70\" cy=\"205\" r=\"5\"/><circle cx=\"330\" cy=\"45\" r=\"5\"/></g><path d=\"M330 45V205M70 45H330\" stroke=\"#aab4c1\" stroke-dasharray=\"5 5\"/><g fill=\"#14243e\" font-size=\"14\"><text x=\"54\" y=\"225\">0</text><text x=\"321\" y=\"225\">10</text><text x=\"44\" y=\"50\">20</text><text x=\"390\" y=\"209\">x</text><text x=\"64\" y=\"20\">y</text><text x=\"155\" y=\"100\">y = 2x</text><text x=\"125\" y=\"244\">Open endpoints: 0 &lt; x &lt; 10</text></g></svg>",
 line: '<svg viewBox="0 0 360 180" role="img" aria-label="Coordinate axes with a rising straight line showing slope as rise over run"><path d="M45 145H330M75 165V18" stroke="#526277" stroke-width="2"/><path d="M82 135L300 42" stroke="#087c91" stroke-width="4"/><path d="M130 115V94H180" fill="none" stroke="#ba920d" stroke-width="3"/><text x="143" y="88">rise</text><text x="145" y="132">run</text><text x="305" y="40">m</text></svg>',
 system: '<svg viewBox="0 0 360 180" role="img" aria-label="Two lines intersect at a point, representing the solution to a system"><path d="M40 145H330M75 165V15" stroke="#526277" stroke-width="2"/><path d="M82 138L290 30M85 35L292 142" stroke="#087c91" stroke-width="3"/><circle cx="184" cy="85" r="5" fill="#b28a08"/><text x="195" y="78">solution</text></svg>',
 inequality: '<svg viewBox="0 0 360 180" role="img" aria-label="A half-plane shaded above a dashed boundary line for a strict greater-than inequality"><path d="M40 150H330M75 165V15" stroke="#526277" stroke-width="2"/><path d="M75 65L305 20V150H75Z" fill="#dceef2"/><path d="M75 65L305 20" stroke="#087c91" stroke-width="3" stroke-dasharray="8 6"/><text x="210" y="105">shade above</text></svg>',
 parabola: '<svg viewBox="0 0 360 180" role="img" aria-label="Upward-opening parabola with its vertex and axis of symmetry"><path d="M40 145H330M180 165V15" stroke="#526277" stroke-width="2"/><path d="M90 32Q180 190 270 32" fill="none" stroke="#087c91" stroke-width="4"/><path d="M180 32V145" stroke="#b28a08" stroke-dasharray="5 5"/><circle cx="180" cy="112" r="5" fill="#b28a08"/><text x="190" y="115">vertex</text><text x="185" y="27">axis</text></svg>',
 transform: '<svg viewBox="0 0 360 180" role="img" aria-label="A function graph and its shifted copy"><path d="M40 145H330M75 165V15" stroke="#526277" stroke-width="2"/><path d="M95 132Q135 50 180 105T275 30" fill="none" stroke="#aab4c1" stroke-width="3" stroke-dasharray="5 5"/><path d="M130 115Q170 33 215 88T310 13" fill="none" stroke="#087c91" stroke-width="4"/><text x="235" y="154">shifted graph</text></svg>',
 growth: '<svg viewBox="0 0 360 180" role="img" aria-label="Increasing exponential curve compared with a decreasing exponential curve"><path d="M40 145H330M75 165V15" stroke="#526277" stroke-width="2"/><path d="M82 135C145 125 200 90 300 20" fill="none" stroke="#087c91" stroke-width="4"/><path d="M82 25C150 55 210 105 300 130" fill="none" stroke="#b28a08" stroke-width="4"/><text x="252" y="24">growth</text><text x="260" y="125">decay</text></svg>',
 units: '<svg viewBox="0 0 360 180" role="img" aria-label="Conversion chain with units cancelling between factors"><rect x="24" y="52" width="90" height="48" rx="8" fill="#edf4f7" stroke="#087c91"/><rect x="135" y="52" width="90" height="48" rx="8" fill="#f8f2d5" stroke="#b28a08"/><rect x="246" y="52" width="90" height="48" rx="8" fill="#edf4f7" stroke="#087c91"/><text x="42" y="82">miles</text><text x="152" y="82">hours</text><text x="265" y="82">minutes</text><path d="M115 76H134M226 76H245" stroke="#526277" stroke-width="2"/><text x="81" y="135">cancel matching units</text></svg>',
 boxplot: '<svg viewBox="0 0 420 210" role="img" aria-label="Box plot with a whisker from minimum to first quartile, a box from first to third quartile, median inside, and whisker to maximum"><path d="M42 105H378M68 80V130M104 80V130M210 66V144M306 80V130M352 80V130" stroke="#526277" stroke-width="3"/><path d="M68 105H104M306 105H352" stroke="#087c91" stroke-width="5"/><rect x="104" y="72" width="202" height="66" rx="4" fill="#e7f2f4" stroke="#087c91" stroke-width="3"/><path d="M210 72V138" stroke="#b28a08" stroke-width="5"/><text x="49" y="158">minimum</text><text x="90" y="158">Q₁</text><text x="180" y="158">median</text><text x="292" y="158">Q₃</text><text x="330" y="158">maximum</text><text x="145" y="190">box width = IQR = Q₃ − Q₁</text></svg>',
 stddev: '<svg viewBox="0 0 420 270" role="img" aria-label="Two dot plots each with twelve observations and mean five; the upper values have smaller standard deviation because they cluster near five, and the lower values have larger standard deviation because they are spread out"><path d="M56 98H380M56 194H380" stroke="#64748b" stroke-width="2"/><path d="M218 35V215" stroke="#b28a08" stroke-width="2" stroke-dasharray="5 5"/><g fill="#087c91"><circle cx="164" cy="88" r="6"/><circle cx="191" cy="88" r="6"/><circle cx="191" cy="74" r="6"/><circle cx="191" cy="60" r="6"/><circle cx="191" cy="46" r="6"/><circle cx="218" cy="88" r="6"/><circle cx="218" cy="74" r="6"/><circle cx="245" cy="88" r="6"/><circle cx="245" cy="74" r="6"/><circle cx="245" cy="60" r="6"/><circle cx="245" cy="46" r="6"/><circle cx="272" cy="88" r="6"/><circle cx="83" cy="184" r="6"/><circle cx="83" cy="170" r="6"/><circle cx="110" cy="184" r="6"/><circle cx="110" cy="170" r="6"/><circle cx="164" cy="184" r="6"/><circle cx="164" cy="170" r="6"/><circle cx="272" cy="184" r="6"/><circle cx="272" cy="170" r="6"/><circle cx="326" cy="184" r="6"/><circle cx="326" cy="170" r="6"/><circle cx="353" cy="184" r="6"/><circle cx="353" cy="170" r="6"/></g><g font-family="Arial,sans-serif" font-size="13" fill="#334155"><text x="57" y="24">Smaller SD: values cluster near mean</text><text x="57" y="148">Larger SD: values spread farther</text><text x="57" y="248">Dashed line marks mean = 5</text><text x="365" y="248">value</text></g><g stroke="#64748b" stroke-width="1"><path d="M83 98V104M110 98V104M137 98V104M164 98V104M191 98V104M218 98V104M245 98V104M272 98V104M299 98V104M326 98V104M353 98V104"/><path d="M83 194V200M110 194V200M137 194V200M164 194V200M191 194V200M218 194V200M245 194V200M272 194V200M299 194V200M326 194V200M353 194V200"/></g><g font-family="Arial,sans-serif" font-size="11" fill="#475569"><text x="79" y="118">0</text><text x="132" y="118">2</text><text x="187" y="118">4</text><text x="241" y="118">6</text><text x="295" y="118">8</text><text x="347" y="118">10</text><text x="79" y="214">0</text><text x="132" y="214">2</text><text x="187" y="214">4</text><text x="241" y="214">6</text><text x="295" y="214">8</text><text x="347" y="214">10</text></g></svg>',
 scatter: '<svg viewBox="0 0 420 290" role="img" aria-label="Scatter plot with numbered axes, actual observations, an upward line of best fit, and a positive residual at study time five hours"><path d="M62 224H374M62 44V224" stroke="#475569" stroke-width="2"/><g stroke="#e2e8f0" stroke-width="1"><path d="M62 188H374M62 152H374M62 116H374M62 80H374"/><path d="M114 44V224M166 44V224M218 44V224M270 44V224M322 44V224M374 44V224"/></g><path d="M62 206L374 98" stroke="#b28a08" stroke-width="3"/><g fill="#087c91" stroke="white" stroke-width="1.5"><circle cx="114" cy="184" r="6"/><circle cx="166" cy="161" r="6"/><circle cx="218" cy="141" r="6"/><circle cx="270" cy="121" r="6"/><circle cx="322" cy="71" r="7"/><circle cx="374" cy="83" r="6"/></g><path d="M322 71V98" stroke="#c2410c" stroke-width="3" stroke-dasharray="5 4"/><circle cx="322" cy="98" r="4" fill="#b28a08"/><g font-family="Arial,sans-serif" font-size="12" fill="#334155"><text x="170" y="268">Study time (hours)</text><text x="6" y="34">Test score</text><text x="49" y="229">0</text><text x="46" y="192">2</text><text x="46" y="156">4</text><text x="46" y="120">6</text><text x="46" y="84">8</text><text x="41" y="48">10</text><text x="59" y="242">0</text><text x="110" y="242">1</text><text x="162" y="242">2</text><text x="214" y="242">3</text><text x="266" y="242">4</text><text x="318" y="242">5</text><text x="370" y="242">6</text><text x="205" y="65">line of best fit</text><text x="330" y="67">actual</text><text x="329" y="113">predicted</text><text x="327" y="89" fill="#9a3412">positive residual</text></g></svg>',
 stemleaf: '<svg viewBox="0 0 420 235" role="img" aria-label="Stem-and-leaf plot of daily low temperatures: stems 1, 2 and 3 with sorted leaves; key 2 bar 1 equals 21 degrees Fahrenheit"><rect x="42" y="30" width="336" height="164" rx="10" fill="#f8fafc" stroke="#cbd5e1" stroke-width="2"/><path d="M115 48V175" stroke="#087c91" stroke-width="3"/><path d="M42 76H378M42 116H378M42 156H378" stroke="#e2e8f0" stroke-width="1"/><g font-family="Arial,sans-serif" font-size="20" fill="#1e293b"><text x="75" y="67">1</text><text x="75" y="107">2</text><text x="75" y="147">3</text><text x="137" y="67">7  7  8  9</text><text x="137" y="107">1  1  2  2  6  6  6  8</text><text x="137" y="147">1  8</text></g><g font-family="Arial,sans-serif" font-size="15" fill="#475569"><text x="42" y="218">Key: 2 | 1 = 21°F · list leaves in order</text><text x="64" y="22">Stem</text><text x="175" y="22">Leaves</text></g></svg>',
 tree: '<svg viewBox="0 0 360 180" role="img" aria-label="Two-stage probability tree illustrating multiplication along a path"><circle cx="40" cy="90" r="6" fill="#087c91"/><path d="M46 88L145 45M46 92L145 135M151 43L260 22M151 47L260 68M151 132L260 112M151 137L260 158" stroke="#087c91" stroke-width="3"/><text x="95" y="43">A</text><text x="90" y="144">not A</text><text x="270" y="25">B</text><text x="270" y="73">not B</text><text x="270" y="115">B</text><text x="270" y="164">not B</text></svg>',
 triangle: '<svg viewBox="0 0 360 180" role="img" aria-label="Right triangle labeled opposite, adjacent and hypotenuse"><path d="M65 145H285V40Z" fill="#eef5f6" stroke="#087c91" stroke-width="4"/><path d="M267 145V127H285" fill="none" stroke="#526277" stroke-width="2"/><text x="145" y="166">adjacent</text><text x="292" y="96">opposite</text><text x="150" y="80">hypotenuse</text><text x="87" y="137">θ</text></svg>',
 specialtriangles: '<svg viewBox="0 0 420 210" role="img" aria-label="Special right triangle side ratios: a 30-60-90 triangle with sides x, x square root 3, and 2x, and a 45-45-90 triangle with legs s and hypotenuse s square root 2"><path d="M38 155H149V91Z" fill="#eef5f6" stroke="#087c91" stroke-width="3"/><path d="M136 155V142H149" fill="none" stroke="#526277" stroke-width="2"/><text x="70" y="178">x√3</text><text x="154" y="128">x</text><text x="78" y="105">2x</text><text x="34" y="149">30°</text><text x="125" y="109">60°</text><text x="48" y="33">30°–60°–90°</text><path d="M236 155H326V65Z" fill="#f8f2d5" stroke="#b28a08" stroke-width="3"/><path d="M314 155V143H326" fill="none" stroke="#526277" stroke-width="2"/><text x="267" y="178">s</text><text x="330" y="111">s</text><text x="265" y="98">s√2</text><text x="234" y="149">45°</text><text x="297" y="83">45°</text><text x="244" y="33">45°–45°–90°</text></svg>',
 trig: '<svg viewBox="0 0 360 180" role="img" aria-label="One-cycle sine graph showing amplitude and period"><path d="M35 92H330M55 160V20" stroke="#526277" stroke-width="2"/><path d="M55 92C80 20 110 20 135 92S190 164 215 92 270 20 295 92 320 164 330 92" fill="none" stroke="#087c91" stroke-width="3"/><path d="M45 35V92M40 35H50M40 92H50" stroke="#b28a08" stroke-width="2"/><text x="62" y="39">amplitude</text><text x="145" y="153">period</text></svg>',
 circle: '<svg viewBox="0 0 360 180" role="img" aria-label="Circle showing radius, central angle and a shaded sector"><circle cx="150" cy="90" r="62" fill="none" stroke="#087c91" stroke-width="3"/><path d="M150 90L210 90A60 60 0 0 0 180 38Z" fill="#f8f2d5" stroke="#b28a08" stroke-width="2"/><path d="M150 90L210 90M150 90L180 38" stroke="#526277" stroke-width="2"/><circle cx="150" cy="90" r="4" fill="#526277"/><text x="177" y="98">r</text><text x="224" y="62">arc</text></svg>',
 area: '<svg viewBox="0 0 360 180" role="img" aria-label="Triangle and trapezoid illustrating perpendicular height and parallel bases"><path d="M25 145L92 35L160 145Z" fill="#e7f2f4" stroke="#087c91" stroke-width="3"/><path d="M92 35V145" stroke="#b28a08" stroke-width="2" stroke-dasharray="4 4"/><text x="98" y="96">h</text><path d="M210 125L240 55H320L340 125Z" fill="#f8f2d5" stroke="#b28a08" stroke-width="3"/><path d="M280 55V125" stroke="#526277" stroke-width="2" stroke-dasharray="4 4"/><text x="283" y="95">h</text></svg>',
 solid: '<svg viewBox="0 0 360 180" role="img" aria-label="Cylinder and cone with base area B and height h"><ellipse cx="100" cy="42" rx="48" ry="14" fill="#e7f2f4" stroke="#087c91" stroke-width="3"/><path d="M52 42V130M148 42V130" stroke="#087c91" stroke-width="3"/><ellipse cx="100" cy="130" rx="48" ry="14" fill="#e7f2f4" stroke="#087c91" stroke-width="3"/><text x="80" y="92">B·h</text><ellipse cx="260" cy="130" rx="50" ry="14" fill="#f8f2d5" stroke="#b28a08" stroke-width="3"/><path d="M210 130L260 30L310 130" fill="none" stroke="#b28a08" stroke-width="3"/><text x="244" y="104">⅓Bh</text><text x="274" y="83">h</text></svg>',
 polygon: '<svg viewBox="0 0 360 180" role="img" aria-label="Regular hexagon showing interior angle and diagonals"><path d="M90 35L145 35L174 82L145 130L90 130L61 82Z" fill="#eef5f6" stroke="#087c91" stroke-width="3"/><path d="M90 35L145 130M145 35L90 130M61 82L174 82" stroke="#b28a08" stroke-width="2"/><text x="226" y="65">interior sum</text><text x="226" y="93">180°(n − 2)</text><text x="226" y="121">diagonals</text></svg>',
 polynomial: '<svg viewBox="0 0 360 180" role="img" aria-label="Cubic graph with a crossing root and a repeated root touching the x-axis"><path d="M35 112H330M180 160V18" stroke="#526277" stroke-width="2"/><path d="M45 30C100 20 113 108 160 112C207 116 218 43 267 47C301 49 315 92 326 152" fill="none" stroke="#087c91" stroke-width="3"/><circle cx="160" cy="112" r="4" fill="#b28a08"/><circle cx="267" cy="47" r="4" fill="#b28a08"/><text x="128" y="132">cross</text><text x="273" y="39">touch</text></svg>',
 complex: '<svg viewBox="0 0 360 180" role="img" aria-label="Complex plane showing real and imaginary axes and the point a plus bi"><path d="M45 140H320M90 165V18" stroke="#526277" stroke-width="2"/><path d="M90 140L235 55" stroke="#087c91" stroke-width="3"/><circle cx="235" cy="55" r="5" fill="#b28a08"/><text x="240" y="52">(a, b)</text><text x="288" y="132">real</text><text x="98" y="27">imaginary</text></svg>',
 products: '<svg viewBox="0 0 360 180" role="img" aria-label="Area model for squaring a sum, showing x squared, two xy rectangles and y squared"><rect x="72" y="30" width="115" height="115" fill="#e7f2f4" stroke="#087c91" stroke-width="3"/><path d="M145 30V145M72 88H187" stroke="#526277" stroke-width="2"/><text x="101" y="70">x²</text><text x="151" y="69">xy</text><text x="102" y="123">xy</text><text x="151" y="123">y²</text><text x="218" y="78">(x + y)²</text><text x="218" y="106">= x² + 2xy + y²</text></svg>',
 ratio: '<svg viewBox="0 0 360 180" role="img" aria-label="Ratio bar partitioned into three parts and five parts"><rect x="45" y="60" width="270" height="44" fill="#eef2f6" stroke="#526277" stroke-width="2"/><path d="M45 60V104M90 60V104M135 60V104M180 60V104M225 60V104M270 60V104M315 60V104" stroke="#087c91" stroke-width="2"/><path d="M45 60H180V104H45Z" fill="#d4e9ed"/><text x="95" y="91">3 parts</text><text x="224" y="91">5 parts</text><text x="85" y="140">total parts = 8</text></svg>',
 sequence: '<svg viewBox="0 0 360 180" role="img" aria-label="Arithmetic sequence plotted as equally spaced discrete points"><path d="M40 145H330M70 165V15" stroke="#526277" stroke-width="2"/><path d="M90 125L140 105L190 85L240 65L290 45" stroke="#087c91" stroke-width="2"/><circle cx="90" cy="125" r="5" fill="#b28a08"/><circle cx="140" cy="105" r="5" fill="#b28a08"/><circle cx="190" cy="85" r="5" fill="#b28a08"/><circle cx="240" cy="65" r="5" fill="#b28a08"/><circle cx="290" cy="45" r="5" fill="#b28a08"/><text x="205" y="153">term number n</text></svg>'
};

const REVISION_FORMULA_VISUAL_CAPTIONS = {
  desmosRestrictions: 'y=2x{0<x<10} restricts the line to this segment; both endpoints are excluded. Graph Settings changes the viewing window.',
  boxplot: 'Five-number summary: the box spans Q₁ to Q₃, and the centre line marks the median.',
  stddev: 'Both dot plots have the same mean. The wider spread corresponds to the larger standard deviation.',
  scatter: 'Teal dots are actual observations; the gold line gives predictions. At x = 5, the dot lies above the line, so its vertical residual (actual − predicted) is positive.',
  stemleaf: 'Every source temperature is retained; the key explains how stems and leaves combine.',
  specialtriangles: 'Side labels use the standard ratios: 30°–60°–90° gives x, x√3, 2x; 45°–45°–90° gives s, s, s√2.'
};

function revisionFormulaEscape(value) {
  return String(value ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
}

// A single authored entry can contain several standalone rules separated by
// semicolons or sentence stops. Render each as its own readable list row while
// preserving commas used inside coordinates, units, and mathematical notation.
function revisionFormulaRuleLines(value) {
  return String(value ?? '').split(/;\s+|(?<=[.!?])\s+(?=[A-Z0-9−“])/).map(line => line.trim()).filter(Boolean)
    .map(line => line.replace(/^([a-z]{2,})(?=\b)/, word => word[0].toUpperCase() + word.slice(1)));
}

function revisionFormulaPanel() {
  const course = REVISION_FORMULA_TRACKS[ST.track?.id];
  if (!course) return '<section class="dash-panel"><h2>Formula lessons</h2><p>Choose a SAT or EST track to view its lessons.</p></section>';
  const names = course.lessons.filter(name => REVISION_FORMULA_LESSONS[name]);
  const selected = REV.formulaLesson && names.includes(REV.formulaLesson) ? REV.formulaLesson : names[0];
  const variant = ST.track?.id === 'est2' ? {'Trigonometry':'Trigonometry and trig graphs','Functions and transformations':'Functions, inverses and asymptotes','Circles':'Circles and power of a point','Probability and conditional probability':'Probability, permutations and combinations'}[selected] : null;
  const lesson = REVISION_FORMULA_LESSONS[variant || selected];
  const cards = names.map(name => `<button type="button" class="formula-lesson-link ${name === selected ? 'selected' : ''}" data-formula-lesson="${revisionFormulaEscape(name)}" aria-current="${name === selected ? 'true' : 'false'}">${revisionFormulaEscape(name)}</button>`).join('');
  const facts = course.facts.map(item => `<li>${revisionFormulaEscape(item)}</li>`).join('');
  const visualNames = lesson.visuals || (lesson.visual ? [lesson.visual] : []);
  const diagrams = visualNames.map(name => `<figure class="formula-diagram">${REVISION_FORMULA_SVG[name] || ''}<figcaption>${revisionFormulaEscape(REVISION_FORMULA_VISUAL_CAPTIONS[name] || '')}</figcaption></figure>`).join('');
  const [keyPoint, ...moreRules] = lesson.formulas;
  const keyPointLines = revisionFormulaRuleLines(keyPoint);
  const ruleLines = moreRules.flatMap(revisionFormulaRuleLines);
  const examples = Array.isArray(lesson.examples) ? lesson.examples : [lesson.example];
  const noteLines = (Array.isArray(lesson.notes) ? lesson.notes : [lesson.notes]).flatMap(revisionFormulaRuleLines);
  const notes = `<ul class="formula-note-list">${noteLines.map(item=>`<li>${revisionFormulaEscape(item)}</li>`).join('')}</ul>`;
  return `<section class="dash-panel revision-panel formula-panel"><div class="review-menu"><button class="btn-ghost" data-revision-main>← Main menu</button></div><div class="dash-heading"><h2>Formula lessons</h2><span class="revision-badge">${revisionFormulaEscape(course.title)}</span></div><p class="dash-note">${revisionFormulaEscape(course.intro)}</p><details class="formula-course-notes"><summary>Track notes and exam data</summary><ul>${facts}</ul></details><div class="formula-layout"><nav class="formula-lesson-list" aria-label="Formula lessons">${cards}</nav><article class="formula-lesson"><h3>${revisionFormulaEscape(selected)}</h3><section class="formula-key-point" aria-label="Main point"><span class="formula-section-label">Main point</span>${keyPointLines.map(item=>`<p>${revisionFormulaEscape(item)}</p>`).join('')}</section>${diagrams?`<section class="formula-visual-section"><h4>Visual guide</h4><div class="formula-diagram-grid">${diagrams}</div></section>`:''}<section class="formula-content-section"><h4>Rules and formulas</h4><ul class="formula-list">${ruleLines.map(item=>`<li>${revisionFormulaEscape(item)}</li>`).join('')}</ul></section><section class="formula-example"><h4>Worked example</h4>${examples.map(item=>`<p>${revisionFormulaEscape(item)}</p>`).join('')}</section><section class="formula-notes"><h4>Notes and common traps</h4>${notes}</section><p class="dash-note formula-provenance">Prepared by Eng. Abdelrahman Ghoneem. Core lesson topics are organized from the supplied revision PDFs; added clarifications are written to state conditions and avoid ambiguous shorthand.</p></article></div><div class="review-menu"><button type="button" class="btn" data-formulas-to-questions>← Question practice</button></div></section>`;
}

// Use the same visible lesson names as the bank when the shared catalogue is loaded.
// Legacy dictionary keys remain available for older saved formula selections.
if (typeof MATH_LESSONS !== 'undefined') {
  for (const [name, sources] of Object.entries({
    'Ratios, percentages and unit conversion':['Ratios, percentages and unit conversion','Percentages and interest','Ratio, proportion and rates','Unit conversions'],
    'Exponents, radicals and growth':['Exponents, radicals and growth','Exponents and special products']
  })) {
    const items=sources.map(key=>REVISION_FORMULA_LESSONS[key]).filter(Boolean);
    REVISION_FORMULA_LESSONS[name]={...items[0],formulas:[...new Set(items.flatMap(x=>x.formulas))],examples:items.flatMap(x=>x.examples||[x.example]),notes:items.flatMap(x=>Array.isArray(x.notes)?x.notes:[x.notes])};
  }
  Object.assign(REVISION_FORMULA_LESSONS, {
    'Algebraic expressions and equations': {
      formulas:['Combine like terms: ax + bx = (a + b)x. Distribute: a(b + c) = ab + ac.','Keep an equation balanced by applying the same valid operation to both sides. To rearrange a formula, isolate the required variable.'],
      example:'If 3x + 5 = 20, subtract 5 to get 3x = 15, then divide by 3: x = 5.',
      notes:'Substitute the result into the original equation. Do not divide by a variable without checking whether it can be zero.'
    },
    'Logic and sets': {
      formulas:['An implication P ⇒ Q is equivalent to its contrapositive: not Q ⇒ not P. The converse need not be true.','A ∪ B contains elements in either set; A ∩ B contains elements in both. For finite sets, |A ∪ B| = |A| + |B| − |A ∩ B|.'],
      example:'If A = {1,2} and B = {2,3}, then A ∪ B = {1,2,3} and A ∩ B = {2}.',
      notes:'A set complement is relative to a specified universal set. A counterexample disproves an always-true claim.'
    },
    'Conic sections': {
      formulas:['Ellipse: (x − h)²/a² + (y − k)²/b² = 1, for positive a and b. Its centre is (h,k).','Horizontal hyperbola: (x − h)²/a² − (y − k)²/b² = 1. Its asymptotes are y − k = ±(b/a)(x − h).'],
      example:'For x²/9 + y²/4 = 1, the ellipse is centred at (0,0), with x-intercepts ±3 and y-intercepts ±2.',
      notes:'Check the sign between squared terms. Interchanging the denominators interchanges the horizontal and vertical semiaxes.'
    },
    'Matrices': {
      formulas:['Add equal-sized matrices entry by entry; multiply by a scalar entry by entry.','For a 2 × 2 matrix with rows (a,b) and (c,d), determinant = ad − bc. Matrix multiplication uses row-by-column products.'],
      example:'For rows (2,1) and (3,4), the determinant is 2·4 − 1·3 = 5.',
      notes:'AB is defined only when the number of columns of A equals the number of rows of B. Generally AB differs from BA.'
    },
    'Vectors': {
      formulas:['For u = (u₁,u₂) and v = (v₁,v₂), u + v = (u₁ + v₁,u₂ + v₂).','Magnitude |u| = √(u₁² + u₂²). Dot product u·v = u₁v₁ + u₂v₂ = |u||v| cos θ.'],
      example:'The vector from (1,2) to (4,6) is (3,4), with magnitude 5.',
      notes:'Subtract starting coordinates from ending coordinates. Nonzero perpendicular vectors have dot product zero.'
    },
    'Limits and continuity': {
      formulas:['A two-sided limit exists when the left-hand and right-hand limits exist and agree.','Continuity at a requires f(a) to be defined, the limit as x approaches a to exist, and that limit to equal f(a).'],
      example:'For x ≠ 2, (x² − 4)/(x − 2) = x + 2, so its limit as x approaches 2 is 4.',
      notes:'A limit concerns nearby values; it need not equal the value at the point. Preserve original domain exclusions when cancelling factors.'
    }
  });
  for (const [track,names] of Object.entries(MATH_LESSONS)) REVISION_FORMULA_TRACKS[track].lessons=[...names];
}
