const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const c=vm.createContext({ST:{track:{id:'sat'}},REV:{formulaLesson:''}});
vm.runInContext(fs.readFileSync('web/lesson-taxonomy.js','utf8'),c);
vm.runInContext(fs.readFileSync('web/revision-formulas.js','utf8'),c);
const rows=JSON.parse(fs.readFileSync('content-releases/20260929_lesson_taxonomy/assignments.json','utf8'));
test('every question and formula resolves to the shared track lesson list',()=>{
 assert.equal(rows.length,6916);assert.equal(new Set(rows.map(x=>x.id)).size,rows.length);
 for(const r of rows){c.r=r;assert.equal(vm.runInContext('canonicalMathLesson(r.track_id,r.lesson)',c),r.lesson);}
 for(const t of ['sat','est','est2']){c.ST.track.id=t;const names=vm.runInContext(`MATH_LESSONS[ST.track.id]`,c);for(const n of names){c.REV.formulaLesson=n;const html=vm.runInContext('revisionFormulaPanel()',c);assert.ok(html.includes(`<h3>${n}</h3>`));assert.ok(!html.includes('>undefined<'));}}
});
test('aliases consolidate and mixed categories are rejected on import',()=>{
 assert.equal(vm.runInContext("canonicalMathLesson('sat','Vertex form')",c),'Quadratics and polynomials');
 assert.equal(vm.runInContext("canonicalMathLesson('est','Rational expressions')",c),'Functions and transformations');
 assert.throws(()=>vm.runInContext("canonicalMathLesson('est','Statistics, Probability & Data Analysis')",c));
 assert.throws(()=>vm.runInContext("canonicalMathLesson('sat','')",c));
 assert.equal(vm.runInContext("canonicalMathLesson('est_eng','Grammar')",c),'Grammar');
});
test('import normalization preserves diagrams and detailed skill labels',()=>{
 const q=vm.runInContext("normalizeQuestionLesson('sat',{topic:'Vertex form',stem:'Example',assets:{image:'figure.png'}})",c);
 assert.equal(q.topic,'Quadratics and polynomials');assert.equal(q.assets.image,'figure.png');assert.equal(q.assets.lesson_subtopic,'Vertex form');
});
