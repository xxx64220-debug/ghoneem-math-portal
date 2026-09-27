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
      assert.ok(lesson.example.length > 10, `${name} needs a worked example`);
      assert.ok(lesson.notes.length > 10, `${name} needs usage notes`);
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
