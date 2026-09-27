const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '..', 'web', 'revision-formulas.js'), 'utf8');
const context = vm.createContext({ ST: { track: { id: 'sat' } }, REV: { formulaLesson: '' } });
vm.runInContext(source, context, { filename: 'revision-formulas.js' });

test('every course lesson resolves to a complete formula lesson and an accessible diagram', () => {
  const result = vm.runInContext(`Object.fromEntries(Object.entries(REVISION_FORMULA_TRACKS).map(([track, course]) => [track, course.lessons.map(name => ({name, lesson: REVISION_FORMULA_LESSONS[name], svg: REVISION_FORMULA_SVG[REVISION_FORMULA_LESSONS[name]?.visual]}))]))`, context);
  for (const [track, entries] of Object.entries(result)) {
    assert.ok(entries.length >= 12, `${track} course is missing lesson coverage`);
    for (const { name, lesson, svg } of entries) {
      assert.ok(lesson, `${track} is missing formula content for ${name}`);
      assert.ok(lesson.formulas.length >= 2, `${name} needs formula coverage`);
      assert.ok((lesson.examples || [lesson.example]).join(' ').length > 10, `${name} needs a worked example`);
      assert.ok((Array.isArray(lesson.notes) ? lesson.notes : [lesson.notes]).join(' ').length > 10, `${name} needs usage notes`);
      assert.match(svg, /<svg[\s\S]*?role="img"[\s\S]*?aria-label=/, `${name} needs an accessible diagram`);
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

test('Formula lessons button switches the revision panel into the formula catalogue', () => {
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
  integration.paintDashboardContent = () => { integration.rendered = vm.runInContext('revisionPanel()', integration); };
  const button = { onclick: null };
  buttons.push(button);
  vm.runInContext('wireRevision()', integration);
  assert.equal(vm.runInContext('REV.mode', integration), 'questions');
  button.onclick();
  assert.equal(vm.runInContext('REV.mode', integration), 'formulas');
  assert.match(integration.rendered, /Formula lessons/);
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
  assert.match(html, /positive association/);
  assert.match(html, /residual/);
  assert.match(html, /7  7  8  9/);
  assert.match(html, /1  1  2  2  6  6  6  8/);
  assert.match(html, /1  8/);
  assert.match(html, /2 \| 1 = 21°F/);
});
