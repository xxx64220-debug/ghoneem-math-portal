const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '..', 'web', 'revision-formulas.js'), 'utf8');
const context = vm.createContext({ ST: { track: { id: 'sat' } }, REV: { formulaLesson: '' } });
vm.runInContext(source, context, { filename: 'revision-formulas.js' });

test('every course lesson has rules, examples and notes; math lessons have accessible diagrams', () => {
  const result = vm.runInContext(`Object.fromEntries(Object.entries(REVISION_FORMULA_TRACKS).map(([track, course]) => [track, course.lessons.map(name => ({name, lesson: REVISION_FORMULA_LESSONS[name], svg: REVISION_FORMULA_SVG[REVISION_FORMULA_LESSONS[name]?.visual]}))]))`, context);
  for (const [track, entries] of Object.entries(result)) {
    assert.ok(entries.length >= 12, `${track} course is missing lesson coverage`);
    for (const { name, lesson, svg } of entries) {
      assert.ok(lesson, `${track} is missing formula content for ${name}`);
      assert.ok(lesson.formulas.length >= 2, `${name} needs formula coverage`);
      assert.ok((lesson.examples || [lesson.example]).join(' ').length > 10, `${name} needs a worked example`);
      assert.ok((Array.isArray(lesson.notes) ? lesson.notes : [lesson.notes]).join(' ').length > 10, `${name} needs usage notes`);
      if (track !== 'est_eng') assert.match(svg, /<svg[\s\S]*?role="img"[\s\S]*?aria-label=/, `${name} needs an accessible diagram`);
    }
  }
});

test('formula catalogue follows the selected track and does not expose another track label', () => {
  const sat = vm.runInContext('revisionFormulaPanel()', context);
  assert.match(sat, /Digital SAT Math/);
  assert.doesNotMatch(sat, /EST Math II/);
  context.ST.track.id = 'est2';
  context.REV.formulaLesson = '';
  const est2 = vm.runInContext('revisionFormulaPanel()', context);
  assert.match(est2, /EST Math II/);
  assert.doesNotMatch(est2, /Digital SAT Math/);
  assert.match(est2, /Logarithms and exponentials/);
});

test('lesson diagrams are self-contained SVG and lesson text is HTML-escaped', () => {
  context.ST.track.id = 'est';
  context.REV.formulaLesson = 'Unit conversions';
  const html = vm.runInContext('revisionFormulaPanel()', context);
  assert.match(html, /aria-label="Conversion chain/);
  assert.match(html, /1 mile ≈ 1.609 km/);
  assert.doesNotMatch(html, /<script\b/i);
  const escaped = vm.runInContext(`revisionFormulaEscape('<script>&"')`, context);
  assert.equal(escaped, '&lt;script&gt;&amp;&quot;');
});

test('Formula lessons shortcut opens the separate reference without changing revision state', () => {
  const buttons = [];
  const document = {
    querySelectorAll(selector) {
      if (selector === '[data-revision-formulas]') return buttons;
      return [];
    },
    querySelector() { return null; },
    getElementById() { return null; }
  };
  const integration = vm.createContext({ ST: { track: { id: 'sat' } }, DASH: { view: 'revision', searchTerm: '' }, document });
  vm.runInContext(fs.readFileSync(path.join(__dirname, '..', 'web', 'final-revision.js'), 'utf8'), integration, { filename: 'final-revision.js' });
  vm.runInContext(source, integration, { filename: 'revision-formulas.js' });
  vm.runInContext("REV.data={items:[]}; REV.track='sat';", integration);
  integration.setDashboardView = view => { integration.DASH.view = view; integration.rendered = vm.runInContext('revisionFormulaPanel({standalone:true})', integration); };
  vm.runInContext("REV.session={marker:'saved'};REV.lesson='Circles';",integration);
  const button = { onclick: null };
  buttons.push(button);
  vm.runInContext('wireRevision()', integration);
  assert.equal(vm.runInContext('REV.mode', integration), 'questions');
  button.onclick();
  assert.equal(integration.DASH.view, 'formulas');
  assert.equal(vm.runInContext('REV.mode', integration), 'questions');
  assert.equal(vm.runInContext('REV.session.marker', integration), 'saved');
  assert.equal(vm.runInContext('REV.lesson', integration), 'Circles');
  assert.match(integration.rendered, /Formulas/);
  assert.match(integration.rendered, /Digital SAT Math/);
});

test('statistics lesson keeps the source notes and shows accurate labeled data displays', () => {
  context.ST.track.id = 'est';
  context.REV.formulaLesson = 'Statistics and data analysis';
  const html = vm.runInContext('revisionFormulaPanel()', context);
  for (const phrase of [
    'small SD means values lie close to the mean',
    'Margin of error',
    'systematic selects at regular intervals',
    'Residual = actual − predicted',
    'a left tail often has mean',
    'Sort the leaves within each stem',
    'outlier can move the mean and range',
    'Positive residuals lie above the fitted line'
  ]) assert.ok(html.includes(phrase), `statistics lesson is missing: ${phrase}`);
  assert.match(html, /Main point/);
  assert.match(html, /Visual guide/);
  assert.match(html, /Smaller SD/);
  assert.match(html, /Larger SD/);
  assert.match(html, /numbered axes/);
  assert.match(html, /positive residual at study time five hours/);
  assert.match(html, /residual/);
  assert.match(html, /7  7  8  9/);
  assert.match(html, /1  1  2  2  6  6  6  8/);
  assert.match(html, /1  8/);
  assert.match(html, /2 \| 1 = 21°F/);
});

test('handwritten revision points are present in conversions, circles and triangles', () => {
  context.ST.track.id = 'est';
  context.REV.formulaLesson = 'Unit conversions';
  let html = vm.runInContext('revisionFormulaPanel()', context);
  for (const phrase of ['16 oz = 1 lb', '1 US gallon = 4 US quarts', '2000 lb = 1 US short ton', '1 m³ = (100 cm)³', 'conversion fraction direction', '°F = (9/5)°C + 32']) {
    assert.ok(html.includes(phrase), `conversion lesson is missing: ${phrase}`);
  }
  context.REV.formulaLesson = 'Circles';
  html = vm.runInContext('revisionFormulaPanel()', context);
  for (const phrase of ['The diameter is the longest chord', 'A semicircle is 180°', 'major arc is greater than 180°', 'centre = (−D/2, −E/2)', 'Power of a point', 'far-minus-near arc DIFFERENCE']) {
    assert.ok(html.includes(phrase), `circle lesson is missing: ${phrase}`);
  }
  context.REV.formulaLesson = 'Triangles and similarity';
  html = vm.runInContext('revisionFormulaPanel()', context);
  for (const phrase of ['two smallest sides is greater than the largest', 'greater → acute, equal → right, less → obtuse', 'altitude meets the opposite side at 90°', 'h² = pq', 'proportional SAS']) {
    assert.ok(html.includes(phrase), `triangle lesson is missing: ${phrase}`);
  }
});

test('separate formula rules and notes onto individual lines', () => {
  context.ST.track.id = 'est';
  context.REV.formulaLesson = 'Triangles and similarity';
  let html = vm.runInContext('revisionFormulaPanel()', context);
  const keyPoint = html.match(/<section class="formula-key-point"[\s\S]*?<\/section>/)?.[0] || '';
  assert.ok((keyPoint.match(/<p>/g) || []).length >= 2, 'split rules in the highlighted main point');
  assert.match(keyPoint, /<p>Area = ½bh\.<\/p>/);
  assert.match(keyPoint, /<p>For a right triangle, a² \+ b² = c² with c the hypotenuse\.<\/p>/);
  assert.equal(vm.runInContext("revisionFormulaRuleLines('First rule; second rule. Third rule.').length", context), 3);

  context.REV.formulaLesson = 'Circles';
  html = vm.runInContext('revisionFormulaPanel()', context);
  const ruleList = html.match(/<ul class="formula-list">([\s\S]*?)<\/ul>/)?.[1] || '';
  const noteList = html.match(/<ul class="formula-note-list">([\s\S]*?)<\/ul>/)?.[1] || '';
  assert.ok((ruleList.match(/<li>/g) || []).length >= 8, 'circle formulas and angle rules each get their own row');
  assert.ok((noteList.match(/<li>/g) || []).length >= 5, 'circle notes become separate note rows');
  assert.ok((ruleList.match(/<li>/g) || []).length >= 8, 'semicolon-separated formula clauses become separate list rows');
  assert.ok((noteList.match(/<li>/g) || []).length >= 5, 'semicolon-separated notes become separate list rows');
});

test('worked examples agree with independently calculated slope, vertex, circle, counting and complex arithmetic',()=>{
 const lesson=name=>vm.runInContext(`REVISION_FORMULA_LESSONS[${JSON.stringify(name)}]`,context);
 const slope=(2-1)/(5-0);assert.equal(slope,1/5);assert.match(lesson('Linear functions and slope').example,/m = 1\/5/);
 const h=-(-4)/(2*1),k=h*h-4*h+1;assert.deepEqual([h,k],[2,-3]);assert.match(lesson('Quadratics and polynomials').example,/vertex is \(2, −3\)/);
 const radiusSquared=(-6/2)**2+(4/2)**2+12;assert.equal(radiusSquared,25);assert(lesson('Circles').examples.some(x=>x.includes('(x − 3)² + (y + 2)² = 25')));
 const fact=n=>n<2?1:n*fact(n-1);assert.equal(fact(8)/(fact(2)*fact(6)),28);assert.equal(fact(8)/fact(6),56);
 assert.match(lesson('Probability, permutations and combinations').example,/8C2 = 28.*8P2 = 56/);
 const denominator=2*2+3*3,real=5*2+10*3,imaginary=10*2-5*3;
 assert.deepEqual([real,imaginary,denominator],[40,5,13]);assert.match(lesson('Complex numbers').example,/40\/13 \+ \(5\/13\)i/);
 assert.equal(2.5*24*60*60,216000);assert(lesson('Unit conversions').examples.some(x=>x.includes('216,000 s')));
});

test('SAT calculator restrictions retain valid curly-brace inputs',()=>{
 const lesson=vm.runInContext("REVISION_FORMULA_LESSONS['Desmos calculator guidance']",context);
 const text=[...lesson.formulas,...lesson.examples,...lesson.notes].join(' ');
 assert.match(text,/y=2x\{0<x<10\}/);
 assert.doesNotMatch(text,/y=2x\(0<x<10\)/);
});
