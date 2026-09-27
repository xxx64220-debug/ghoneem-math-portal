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
    lessons: ['Linear functions and slope','Systems of equations','Inequalities and absolute value','Quadratics and polynomials','Functions and transformations','Exponents, radicals and growth','Ratios, percentages and unit conversion','Statistics and data analysis','Probability and conditional probability','Geometry and triangles','Trigonometry','Circles','Area and perimeter','Volume and surface area']
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
    formulas: ['Slope: m = (y₂ − y₁) / (x₂ − x₁), when x₂ ≠ x₁.', 'Slope-intercept: y = mx + b. Point-slope: y − y₁ = m(x − x₁).', 'Standard form Ax + By = C (B ≠ 0): slope = −A/B. Distance: d = √((x₂ − x₁)² + (y₂ − y₁)²). Midpoint: ((x₁ + x₂)/2, (y₁ + y₂)/2).', 'Parallel nonvertical lines have equal slopes. Perpendicular nonvertical lines have slopes whose product is −1.'],
    example: 'From (0, 1) and (5, 2), m = 1/5, so the line is y = x/5 + 1. In a context, slope is the change in output per one unit of input; b is the output at x = 0.',
    notes: 'A vertical line x = c has undefined slope; a horizontal line y = c has slope 0. In Ax + By = C, if B = 0 the line is vertical, so do not use −A/B. Label rise and run before calculating.', visual: 'line'
  },
  'Systems of equations': {
    formulas: ['A solution is an ordered pair that satisfies every equation; graphically, it is an intersection.', 'For y = m₁x + b₁ and y = m₂x + b₂: different slopes → one intersection; same slope with different intercepts → no solution; same slope and intercept → infinitely many.', 'For a line and a curve, substitute one equation into the other. The resulting real roots give the intersection x-values.'],
    example: 'y = 2x + 3 and y = 2x − 1 have the same slope but different intercepts, so they are parallel and have no solution.',
    notes: 'Coefficient-ratio shortcuts assume equations are written consistently and denominators in the ratios are nonzero. Substitution or elimination handles zero coefficients safely. Use a graph as a check; closely spaced intersections may be hard to read exactly.', visual: 'system'
  },
  'Inequalities and absolute value': {
    formulas: ['Adding or subtracting the same value preserves an inequality. Multiplying or dividing by a negative reverses the inequality sign.', '|u| = k (k ≥ 0): u = k or u = −k. |u| < k (k > 0): −k < u < k. |u| > k (k ≥ 0): u < −k or u > k.', 'y > mx + b: dashed boundary, shade above. y ≥ mx + b: solid boundary, shade above. Reverse above/below for < and ≤.'],
    example: '−2x > 6 gives x < −3 after dividing by −2 and reversing the sign. |x − 3| ≤ 2 gives 1 ≤ x ≤ 5.',
    notes: 'If k < 0, |u| = k has no solution; |u| < k has no solution; |u| > k is always true. For a compound inequality, AND means intersection and OR means union. A test point such as (0, 0) can identify a shaded half-plane.', visual: 'inequality'
  },
  'Quadratics and polynomials': {
    formulas: ['Standard quadratic: y = ax² + bx + c, a ≠ 0. Axis: x = −b/(2a); vertex: (−b/(2a), f(−b/(2a))).', 'Quadratic formula: x = (−b ± √(b² − 4ac)) / (2a). Discriminant Δ = b² − 4ac: Δ > 0 two distinct real roots; Δ = 0 one repeated real root; Δ < 0 no real roots.', 'For ax² + bx + c = 0: sum of roots = −b/a; product = c/a. Vertex form y = a(x − h)² + k has vertex (h, k).', 'Remainder theorem: dividing P(x) by (x − r) leaves remainder P(r). Factor theorem: (x − r) is a factor exactly when P(r) = 0.'],
    example: 'For y = x² − 4x + 1, the axis is x = 2, and f(2) = −3, so the vertex is (2, −3). Since a > 0, it is a minimum.',
    notes: 'Identify a, b and c including signs before using the quadratic formula. “Tangent” to the x-axis means Δ = 0 only when solving the quadratic for its x-intercepts. A repeated factor touches the axis; odd multiplicity crosses it.', visual: 'parabola'
  },
  'Functions and transformations': {
    formulas: ['f(a) = b means the graph includes (a, b). Composition: (f ∘ g)(x) = f(g(x)); evaluate the inside function first.', 'Domain restrictions: denominator ≠ 0; an even root requires its radicand ≥ 0; an even root in a denominator requires its radicand > 0.', 'f(x) + k shifts up k; f(x) − k shifts down k; f(x − h) shifts right h; f(x + h) shifts left h.', '−f(x) reflects across the x-axis; f(−x) reflects across the y-axis. For a rational function, cancel common factors before identifying vertical asymptotes; a cancelled zero is a hole.'],
    example: 'For f(x) = 3x + 5, f(2) = 11. For g(x) = √(x + 1), the real domain is x ≥ −1.',
    notes: 'For a simplified rational function with numerator degree n and denominator degree d: n < d gives horizontal asymptote y = 0; n = d gives the ratio of leading coefficients; n = d + 1 gives a slant asymptote from division. If n > d + 1, polynomial division gives a higher-degree polynomial asymptote, not a horizontal one.', visual: 'transform'
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
    formulas: ['Mean = sum of values / number of values. Median = middle value after sorting (or mean of the two middle values). Mode = most frequent value.', 'Range = maximum − minimum. IQR = Q₃ − Q₁.', 'Residual = observed value − predicted value. A positive residual means the observed value lies above the model prediction.', 'Adding c to every data value adds c to the mean and median; it leaves range, IQR and standard deviation unchanged. Multiplying every value by c scales spread measures by |c|.'],
    example: 'For 2, 4, 4, 7, 9: mean = 26/5 = 5.2, median = 4, mode = 4, and range = 7.',
    notes: 'Sort before finding the median or quartiles. The median is less affected by extreme values than the mean. Box plots summarize min, Q₁, median, Q₃ and max. Check the quartile convention stated by the question or course.', visual: 'boxplot'
  },
  'Probability and conditional probability': {
    formulas: ['P(A) = favourable outcomes / all equally likely outcomes, with 0 ≤ P(A) ≤ 1. Complement: P(not A) = 1 − P(A).', 'Addition rule: P(A or B) = P(A) + P(B) − P(A and B). For mutually exclusive events, the overlap is 0.', 'Multiplication rule: P(A and B) = P(A)P(B | A). For independent events, this becomes P(A)P(B).', 'Conditional probability: P(A | B) = P(A and B) / P(B), provided P(B) > 0. At least one = 1 − P(none).', 'Counting: n! arrangements of n distinct objects; n!/(k₁!k₂!…) when objects repeat. nPr = n!/(n − r)!; nCr = n!/[r!(n − r)!].'],
    example: 'If 30 of 70 males passed, then P(pass | male) = 30/70. The denominator is the male total because “male” is the given group.',
    notes: 'Without replacement, update the total and category counts after each draw. “AND” is not automatically multiplication of independent probabilities; use the conditional multiplication rule. “OR” requires subtracting an overlap unless the events cannot happen together.', visual: 'tree'
  },
  'Geometry and triangles': {
    formulas: ['A straight angle = 180°; a full turn = 360°; vertical angles are equal. Triangle interior angles sum to 180°.', 'Exterior angle of a triangle = sum of the two remote interior angles. Pythagorean theorem for a right triangle: a² + b² = c², with c the hypotenuse.', 'Triangle inequality: for third side x and other sides a, b, |a − b| < x < a + b.', 'Similar figures with side scale factor k have perimeter ratio k, area ratio k² and volume ratio k³.'],
    example: 'A 3:5 side ratio gives area ratio 9:25 and volume ratio 27:125 for similar solids.',
    notes: 'For an acute/right/obtuse triangle, compare a² + b² with c², where c is the longest side: greater/ equal/ less, respectively. Congruence tests include SSS, SAS, ASA and AAS; AAA establishes similarity, not congruence. SSA is not a general congruence test.', visual: 'triangle'
  },
  'Trigonometry': {
    formulas: ['Right triangle only: sin θ = opposite/hypotenuse; cos θ = adjacent/hypotenuse; tan θ = opposite/adjacent = sin θ/cos θ.', 'Reciprocals: csc θ = 1/sin θ; sec θ = 1/cos θ; cot θ = 1/tan θ.', 'sin²θ + cos²θ = 1; 1 + tan²θ = sec²θ; 1 + cot²θ = csc²θ.', 'Degrees to radians: degrees × π/180. Radians to degrees: radians × 180/π. In a sine graph y = A sin(Bx + C) + D: amplitude = |A|, period = 2π/|B|, phase shift = −C/B, midline y = D.'],
    example: 'In a 3–4–5 right triangle, for the angle opposite the side of length 3: sin θ = 3/5, cos θ = 4/5, tan θ = 3/4.',
    notes: 'For a non-right triangle, label each side opposite its matching capital angle. Sine law: a/sin A = b/sin B = c/sin C. Cosine law: a² = b² + c² − 2bc cos A. These identities use matched opposite pairs; do not write sin(a)/A. On calculator questions, check degree/radian mode.', visual: 'trig'
  },
  'Circles': {
    formulas: ['Circumference C = 2πr = πd; area A = πr². A tangent is perpendicular to the radius at the point of tangency.', 'Degree measure: arc length = (θ/360°)·2πr; sector area = (θ/360°)·πr². Radian measure: arc = rθ; sector area = ½r²θ.', 'Circle equation: (x − h)² + (y − k)² = r²; centre (h, k), radius r.', 'Intersecting chords inside: angle = ½(sum of intercepted arcs). Secants outside: angle = ½(far arc − near arc).'],
    example: 'For centre (3, −2) and radius 5: (x − 3)² + (y + 2)² = 25. The signs inside the brackets reverse when reading the centre.',
    notes: 'Angles must be in matching units in arc/sector formulas. For power of a point: intersecting chords give (part)(part) = (part)(part); two outside secants give (outside)(whole) = (outside)(whole); tangent-secant gives tangent² = (outside)(whole).', visual: 'circle'
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
    formulas: ['Isosceles triangle: equal sides face equal angles. Equilateral: three equal sides and three 60° angles.', 'Special right triangles: 45°–45°–90° sides x, x, x√2. 30°–60°–90° sides x, x√3, 2x (short leg, long leg, hypotenuse).', 'Similar triangles have equal corresponding angles and proportional corresponding side lengths.', 'For right-triangle altitude to hypotenuse: with hypotenuse c split into segments p and q, h² = pq; each leg squared = c times its adjacent hypotenuse segment.'],
    example: 'A 30°–60°–90° triangle with hypotenuse 12 has short leg 6 and long leg 6√3.',
    notes: 'Match corresponding vertices before writing a proportion. If side scale factor is small:large = a:b, areas scale a²:b² and volumes of similar solids scale a³:b³.', visual: 'triangle'
  },
  'Polynomial division and remainder': {
    formulas: ['Polynomial division: dividend = divisor × quotient + remainder; the remainder degree is less than the divisor degree.', 'Remainder on division by (x − a) is P(a). (x − a) is a factor exactly when P(a) = 0.', 'For a rational function whose numerator degree is exactly one more than its denominator degree, polynomial division gives a slant asymptote; discard only the proper fractional remainder when writing that asymptote.'],
    example: 'For P(x) = x³ + 5x + 10 divided by x − 5, the remainder is P(5) = 160; no long division is needed to find it.',
    notes: 'Synthetic division uses a for divisor x − a and −a for divisor x + a. Include zero coefficients for missing powers. A repeated zero may touch the x-axis; inspect multiplicity.', visual: 'polynomial'
  },
  'Complex numbers': {
    formulas: ['i² = −1. A complex number is a + bi, with real part a and imaginary coefficient b.', 'Conjugate: a + bi ↔ a − bi. Product of conjugates = a² + b².', '|a + bi| = √(a² + b²).', '(a + bi)/(c + di) = ((ac + bd)/(c² + d²)) + ((bc − ad)/(c² + d²))i, when c² + d² ≠ 0.'],
    example: '(5 + 10i)/(2 + 3i): multiply by (2 − 3i)/(2 − 3i) to get 40/13 + (5/13)i.',
    notes: 'When complex numbers are equal, match real parts and imaginary coefficients separately. Powers of i repeat every four: i, −1, −i, 1.', visual: 'complex'
  },
  'Exponents and special products': {
    formulas: ['(x + y)² = x² + 2xy + y²; (x − y)² = x² − 2xy + y².', 'x² − y² = (x − y)(x + y).', 'x² + y² = (x + y)² − 2xy.', 'For aᵐ = aⁿ ⇒ m = n only when the base conditions make the exponential function one-to-one (for real exponents, a > 0 and a ≠ 1).'],
    example: 'If x + y = 6 and xy = 5, then x² + y² = 6² − 2·5 = 26.',
    notes: 'Do not confuse (x + y)² with x² + y²; the middle term 2xy is essential. The equation 1ˣ = 1 does not determine x.', visual: 'products'
  },
  'Percentages and interest': {
    formulas: ['Percent = (part / whole) × 100%. New = original(1 ± r), with r as a decimal.', 'Compound once per period: A = P(1 + r)ᵗ. Compounded n times per year: A = P(1 + r/n)ⁿᵗ.', 'Simple interest: I = Prt; total A = P(1 + rt).', 'Successive percent changes are applied by multiplying their factors.'],
    example: 'A 1000 deposit at 10% annual interest compounded twice in one year is 1000(1 + 0.10/2)² = 1102.50.',
    notes: 'Convert percent to decimal before substituting (10% = 0.10). In percent change, divide by the original amount. “Simple” interest adds the same interest each period; “compound” interest earns interest on accumulated interest.', visual: 'growth'
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
    formulas: ['Multiply by a conversion fraction equal to 1, with units arranged to cancel.', '1 km = 1000 m; 1 m = 100 cm = 1000 mm; 1 kg = 1000 g; 1 g = 1000 mg; 1 L = 1000 mL.', '1 inch = 2.54 cm exactly; 1 ft = 12 in; 1 yd = 3 ft; 1 mile = 5280 ft; 1 US gallon = 4 US quarts.', '1 day = 24 h; 1 h = 60 min = 3600 s; 1 week = 7 days. 180° = π radians.'],
    example: 'Convert 2.5 days to seconds: 2.5 days × 24 h/day × 60 min/h × 60 s/min = 216,000 seconds.',
    notes: 'For derived units, square or cube the conversion factor when converting area or volume. Example: 1 m² = (100 cm)² = 10,000 cm². Distinguish US and imperial gallons; only use the gallon conversion printed in the question unless the convention is explicit. Approximate: 1 mile ≈ 1.609 km; 1 kg ≈ 2.205 lb.', visual: 'units'
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

const REVISION_FORMULA_SVG = {
 line: '<svg viewBox="0 0 360 180" role="img" aria-label="Coordinate axes with a rising straight line showing slope as rise over run"><path d="M45 145H330M75 165V18" stroke="#526277" stroke-width="2"/><path d="M82 135L300 42" stroke="#087c91" stroke-width="4"/><path d="M130 115V94H180" fill="none" stroke="#ba920d" stroke-width="3"/><text x="143" y="88">rise</text><text x="145" y="132">run</text><text x="305" y="40">m</text></svg>',
 system: '<svg viewBox="0 0 360 180" role="img" aria-label="Two lines intersect at a point, representing the solution to a system"><path d="M40 145H330M75 165V15" stroke="#526277" stroke-width="2"/><path d="M82 138L290 30M85 35L292 142" stroke="#087c91" stroke-width="3"/><circle cx="184" cy="85" r="5" fill="#b28a08"/><text x="195" y="78">solution</text></svg>',
 inequality: '<svg viewBox="0 0 360 180" role="img" aria-label="A half-plane shaded above a dashed boundary line for a strict greater-than inequality"><path d="M40 150H330M75 165V15" stroke="#526277" stroke-width="2"/><path d="M75 65L305 20V150H75Z" fill="#dceef2"/><path d="M75 65L305 20" stroke="#087c91" stroke-width="3" stroke-dasharray="8 6"/><text x="210" y="105">shade above</text></svg>',
 parabola: '<svg viewBox="0 0 360 180" role="img" aria-label="Upward-opening parabola with its vertex and axis of symmetry"><path d="M40 145H330M180 165V15" stroke="#526277" stroke-width="2"/><path d="M90 32Q180 190 270 32" fill="none" stroke="#087c91" stroke-width="4"/><path d="M180 32V145" stroke="#b28a08" stroke-dasharray="5 5"/><circle cx="180" cy="112" r="5" fill="#b28a08"/><text x="190" y="115">vertex</text><text x="185" y="27">axis</text></svg>',
 transform: '<svg viewBox="0 0 360 180" role="img" aria-label="A function graph and its shifted copy"><path d="M40 145H330M75 165V15" stroke="#526277" stroke-width="2"/><path d="M95 132Q135 50 180 105T275 30" fill="none" stroke="#aab4c1" stroke-width="3" stroke-dasharray="5 5"/><path d="M130 115Q170 33 215 88T310 13" fill="none" stroke="#087c91" stroke-width="4"/><text x="235" y="154">shifted graph</text></svg>',
 growth: '<svg viewBox="0 0 360 180" role="img" aria-label="Increasing exponential curve compared with a decreasing exponential curve"><path d="M40 145H330M75 165V15" stroke="#526277" stroke-width="2"/><path d="M82 135C145 125 200 90 300 20" fill="none" stroke="#087c91" stroke-width="4"/><path d="M82 25C150 55 210 105 300 130" fill="none" stroke="#b28a08" stroke-width="4"/><text x="252" y="24">growth</text><text x="260" y="125">decay</text></svg>',
 units: '<svg viewBox="0 0 360 180" role="img" aria-label="Conversion chain with units cancelling between factors"><rect x="24" y="52" width="90" height="48" rx="8" fill="#edf4f7" stroke="#087c91"/><rect x="135" y="52" width="90" height="48" rx="8" fill="#f8f2d5" stroke="#b28a08"/><rect x="246" y="52" width="90" height="48" rx="8" fill="#edf4f7" stroke="#087c91"/><text x="42" y="82">miles</text><text x="152" y="82">hours</text><text x="265" y="82">minutes</text><path d="M115 76H134M226 76H245" stroke="#526277" stroke-width="2"/><text x="81" y="135">cancel matching units</text></svg>',
 boxplot: '<svg viewBox="0 0 360 180" role="img" aria-label="Box plot showing minimum, first quartile, median, third quartile and maximum"><path d="M35 92H325M55 72V112M85 72V112M150 55V129M235 72V112M305 72V112" stroke="#526277" stroke-width="3"/><path d="M85 62H235V122H85Z" fill="#e7f2f4" stroke="#087c91" stroke-width="3"/><text x="40" y="145">min</text><text x="73" y="145">Q₁</text><text x="133" y="145">median</text><text x="223" y="145">Q₃</text><text x="292" y="145">max</text></svg>',
 tree: '<svg viewBox="0 0 360 180" role="img" aria-label="Two-stage probability tree illustrating multiplication along a path"><circle cx="40" cy="90" r="6" fill="#087c91"/><path d="M46 88L145 45M46 92L145 135M151 43L260 22M151 47L260 68M151 132L260 112M151 137L260 158" stroke="#087c91" stroke-width="3"/><text x="95" y="43">A</text><text x="90" y="144">not A</text><text x="270" y="25">B</text><text x="270" y="73">not B</text><text x="270" y="115">B</text><text x="270" y="164">not B</text></svg>',
 triangle: '<svg viewBox="0 0 360 180" role="img" aria-label="Right triangle labeled opposite, adjacent and hypotenuse"><path d="M65 145H285V40Z" fill="#eef5f6" stroke="#087c91" stroke-width="4"/><path d="M267 145V127H285" fill="none" stroke="#526277" stroke-width="2"/><text x="145" y="166">adjacent</text><text x="292" y="96">opposite</text><text x="150" y="80">hypotenuse</text><text x="87" y="137">θ</text></svg>',
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

function revisionFormulaEscape(value) {
  return String(value ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
}

function revisionFormulaPanel() {
  const course = REVISION_FORMULA_TRACKS[ST.track?.id];
  if (!course) return '<section class="dash-panel"><h2>Formula lessons</h2><p>Choose a SAT or EST track to view its lessons.</p></section>';
  const names = course.lessons.filter(name => REVISION_FORMULA_LESSONS[name]);
  const selected = REV.formulaLesson && names.includes(REV.formulaLesson) ? REV.formulaLesson : names[0];
  const lesson = REVISION_FORMULA_LESSONS[selected];
  const cards = names.map(name => `<button type="button" class="formula-lesson-link ${name === selected ? 'selected' : ''}" data-formula-lesson="${revisionFormulaEscape(name)}" aria-current="${name === selected ? 'true' : 'false'}">${revisionFormulaEscape(name)}</button>`).join('');
  const facts = course.facts.map(item => `<li>${revisionFormulaEscape(item)}</li>`).join('');
  const formulas = lesson.formulas.map(item => `<li>${revisionFormulaEscape(item)}</li>`).join('');
  const svg = REVISION_FORMULA_SVG[lesson.visual] || '';
  return `<section class="dash-panel revision-panel formula-panel"><div class="review-menu"><button class="btn-ghost" data-revision-main>← Main menu</button></div><div class="dash-heading"><h2>Formula lessons</h2><span class="revision-badge">${revisionFormulaEscape(course.title)}</span></div><p class="dash-note">${revisionFormulaEscape(course.intro)}</p><details class="formula-course-notes"><summary>Track notes and exam data</summary><ul>${facts}</ul></details><div class="formula-layout"><nav class="formula-lesson-list" aria-label="Formula lessons">${cards}</nav><article class="formula-lesson"><h3>${revisionFormulaEscape(selected)}</h3><div class="formula-diagram">${svg}</div><h4>Rules and formulas</h4><ul class="formula-list">${formulas}</ul><h4>Worked example</h4><p>${revisionFormulaEscape(lesson.example)}</p><h4>Notes and common traps</h4><p>${revisionFormulaEscape(lesson.notes)}</p><p class="dash-note formula-provenance">Prepared by Eng. Abdelrahman Ghoneem. Core lesson topics are organized from the supplied revision PDFs; added clarifications are written to state conditions and avoid ambiguous shorthand.</p></article></div><div class="review-menu"><button type="button" class="btn" data-formulas-to-questions>← Question practice</button></div></section>`;
}
