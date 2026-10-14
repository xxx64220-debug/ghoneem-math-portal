const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const c=vm.createContext({ST:{track:{id:'sat'}},REV:{formulaLesson:''}});
vm.runInContext(fs.readFileSync('web/lesson-taxonomy.js','utf8'),c);
vm.runInContext(fs.readFileSync('web/revision-formulas.js','utf8'),c);
const rows=JSON.parse(fs.readFileSync('content-releases/20260929_lesson_taxonomy/assignments.json','utf8'));
const corrections=JSON.parse(fs.readFileSync('content-releases/20260929_lesson_taxonomy_corrections/assignments.json','utf8'));
const correctionById=new Map(corrections.map(x=>[x.id,x]));
const finalRows=rows.map(x=>correctionById.has(x.id)?{...x,lesson:correctionById.get(x.id).new_lesson}:x);
test('active lesson names resolve while archived EST I sequences stay excluded from new imports',()=>{
 assert.equal(rows.length,6916);assert.equal(new Set(rows.map(x=>x.id)).size,rows.length);
 assert.equal(corrections.length,13);assert.equal(new Set(corrections.map(x=>x.id)).size,corrections.length);
 const archived=finalRows.filter(r=>r.track_id==='est'&&r.lesson==='Sequences');assert.equal(archived.length,28);
 for(const r of finalRows){c.r=r;if(archived.includes(r))assert.throws(()=>vm.runInContext('canonicalMathLesson(r.track_id,r.lesson)',c));else assert.equal(vm.runInContext('canonicalMathLesson(r.track_id,r.lesson)',c),r.lesson);}
 assert.equal(vm.runInContext("REVISION_FORMULA_TRACKS.est.lessons.includes('Sequences')",c),false);
 assert.equal(vm.runInContext("canonicalMathLesson('est2','Sequences')",c),'Sequences');
 for(const t of ['sat','est','est2']){c.ST.track.id=t;const names=vm.runInContext(`MATH_LESSONS[ST.track.id]`,c);for(const n of names){c.REV.formulaLesson=n;const html=vm.runInContext('revisionFormulaPanel()',c);assert.ok(html.includes(`<h3>${n}</h3>`));assert.ok(!html.includes('>undefined<'));}}
});
test('aliases consolidate and mixed categories are rejected on import',()=>{
 assert.equal(vm.runInContext("canonicalMathLesson('sat','Vertex form')",c),'Quadratics and polynomials');
 assert.equal(vm.runInContext("canonicalMathLesson('est','Rational expressions')",c),'Functions and transformations');
 assert.equal(vm.runInContext("canonicalMathLesson('sat','Cofunction identities')",c),'Trigonometry');
 assert.equal(vm.runInContext("canonicalMathLesson('est','Factor theorem')",c),'Polynomial division and remainder');
 assert.equal(vm.runInContext("canonicalMathLesson('sat','Algebraic expressions')",c),'Algebraic expressions and equations');
 for(const label of ['Statistics, Probability & Data Analysis','Systems of equations and inequalities','Triangles and trigonometry','Area, Perimeter, & Volume','Range','Graphs and models']){
  c.label=label;assert.throws(()=>vm.runInContext("canonicalMathLesson('sat',label)",c));
 }
 assert.throws(()=>vm.runInContext("canonicalMathLesson('sat','')",c));
 assert.equal(vm.runInContext("canonicalMathLesson('est_eng','Grammar')",c),'Grammar');
});
test('advanced EST II assignments stay specific and track-scoped',()=>{
 const expected={
  'Complex numbers':14,'Conic sections':7,'Limits and continuity':7,'Logarithms and exponentials':16,
  'Matrices':9,'Polynomial division and remainder':1,'Sequences':23,'Vectors':3
 };
 for(const [lesson,count] of Object.entries(expected))assert.equal(finalRows.filter(x=>x.track_id==='est2'&&x.lesson===lesson).length,count,lesson);
 assert.equal(finalRows.find(x=>x.id==='092c7a10-fc9f-5ef6-8192-485c8682a7ee').lesson,'Conic sections');
 assert.equal(finalRows.find(x=>x.id==='0532f0f7-43db-507d-8997-a9d925f35316').lesson,'Limits and continuity');
 assert.equal(finalRows.find(x=>x.id==='dc963911-a748-5368-a85d-40227434e37c').lesson,'Vectors');
 assert.throws(()=>vm.runInContext("canonicalMathLesson('sat','Vectors')",c));
 assert.throws(()=>vm.runInContext("canonicalMathLesson('est','Conic sections')",c));
});
test('proven over-broad assignments are corrected without changing membership',()=>{
 const expected={
  '12039edd-0ed2-4caf-847b-1f8b79633f6d':'Functions and transformations',
  '5f8bdfe2-cb1a-409e-b86a-1f4c6fd5c15a':'Trigonometry',
  'da7220f9-fad9-570f-a8df-5500fe4f5823':'Polynomial division and remainder'
 };
 for(const [id,lesson] of Object.entries(expected)){
  const before=rows.find(x=>x.id===id),after=finalRows.find(x=>x.id===id);
  assert.equal(after.lesson,lesson);assert.equal(after.track_id,before.track_id);assert.equal(after.topic,before.topic);
 }
});
test('import normalization preserves diagrams and detailed skill labels',()=>{
 const q=vm.runInContext("normalizeQuestionLesson('sat',{topic:'Vertex form',stem:'Example',assets:{image:'figure.png'}})",c);
 assert.equal(q.topic,'Quadratics and polynomials');assert.equal(q.assets.image,'figure.png');assert.equal(q.assets.lesson_subtopic,'Vertex form');
});
