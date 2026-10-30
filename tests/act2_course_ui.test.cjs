const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const read=f=>fs.readFileSync(f,'utf8');
test('ACT 2 references cover all lessons without displaying source links and preserve other course references',()=>{
 const dom=new JSDOM('<main></main>',{runScripts:'outside-only'}),c=dom.getInternalVMContext();
 Object.assign(c,{ST:{track:{id:'act2'}},REV:{formulaLesson:''}});
 for(const f of ['lesson-taxonomy','act2-course','revision-formulas','lesson-exam-catalog'])vm.runInContext(read('web/'+f+'.js'),c);
 const names=vm.runInContext('MATH_LESSONS.act2',c);assert.equal(names.length,26);
 for(const track of ['act2','sat','est','est2'])for(const lesson of vm.runInContext(`MATH_LESSONS.${track}`,c)){
  c.lesson=lesson;c.track=track;const html=vm.runInContext('revisionFormulaPanel({track,selectedLesson:lesson,standalone:true})',c);
  assert(html.includes('<h3>'+lesson+'</h3>'));assert(!html.includes('>undefined<'));assert(!html.includes('ACT 2 Math materials'));assert.doesNotMatch(html,/<a\b|https?:\/\/|Open the materials below/i);
 }
 const materials=c.ACT2Course.materials;assert.equal(materials.length,15);assert.equal(new Set(materials.map(m=>m.url)).size,15);
 c.document.querySelector('main').innerHTML=vm.runInContext("revisionFormulaPanel({track:'act2',standalone:true})",c);
 assert.equal(c.document.querySelectorAll('details[open]').length,0,'track notes start collapsed');
 assert.equal(c.document.querySelectorAll('a[href]').length,0);
 const exams=c.GhoneemLessonCatalog.filter(e=>e.track_id==='act2');
 const core=exams.filter(e=>e.edition==='23 Oct 2026');assert.equal(core.length,19);
 assert.equal(exams.length,55,'includes the later fresh-bank lesson sets');
 assert.deepEqual([...core.map(e=>e.lesson)].sort(),[...names.slice(0,19)].sort());assert(exams.every(e=>e.questions===25));
 for(const row of exams)for(const secret of ['correct','explanation','question_ids','stem'])assert.equal(secret in row,false);
 dom.window.close();
});
test('ACT 2 full papers use a single timer and formula practice opens lesson exams',()=>{
 const dom=new JSDOM('<div id="practice"></div>',{runScripts:'outside-only'}),c=dom.getInternalVMContext();let destination;
 Object.assign(c,{ST:{track:{id:'act2'}},DASH:{access:{practice_open:true},revisionVisible:false,exams:[{title:'ACT 2 diagnostic',assessment_type:'full_exam',questions:50,duration_seconds:3600}]},esc:String,assessmentRow:e=>'<article>'+e.title+'</article>',setDashboardView:v=>destination=v,FORMULAS:{}});
 const html=read('web/index.html');vm.runInContext(html.slice(html.indexOf('function fullExamSection('),html.indexOf('function historySection(')),c);
 const out=c.fullExamSection();assert.match(out,/50 multiple-choice questions/);assert.match(out,/60 minutes/);assert.match(out,/ACT 2 diagnostic/);assert.doesNotMatch(out,/SAT practice|Module 1/);
 c.document.getElementById('practice').innerHTML='<button data-formulas-to-questions>Practice</button>';
 vm.runInContext(html.slice(html.indexOf('function wireFormulas('),html.indexOf('function searchSection(')),c);c.wireFormulas();
 assert.equal(c.document.querySelector('button').disabled,false);c.document.querySelector('button').click();assert.equal(destination,'lesson_exam');
 dom.window.close();
});
