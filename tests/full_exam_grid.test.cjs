const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const {examFixtures,extract}=require('./full_exam_grid_fixture.cjs');
const html=fs.readFileSync(process.env.EXAM_GRID_SOURCE||'web/index.html','utf8');
function setup(track='sat',rows=examFixtures(track)){
 const dom=new JSDOM('<main id="dashboardContent"></main>',{runScripts:'outside-only'}),c=dom.getInternalVMContext(),actions=[];
 Object.assign(c,{ST:{track:{id:track}},DASH:{exams:rows},$:id=>c.document.getElementById(id),esc:s=>String(s??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch])),startExam:async(id,untimed)=>actions.push({action:'start',id,untimed}),openReview:id=>actions.push({action:'review',id})});
 vm.runInContext(extract(html,'function assessmentRow(','function historySection('),c);
 vm.runInContext(extract(html,'function wireDashboard()','/* ========================== EXAM RUNNER'),c);
 const render=()=>{c.document.querySelector('main').innerHTML=c.fullExamSection();c.wireDashboard();};render();
 return {dom,c,doc:c.document,actions,render};
}
test('SAT pairs remain intact, live pair first, then natural title ordering',()=>{
 const f=setup(),cards=[...f.doc.querySelectorAll('.exam-pair')];
 assert.equal(cards.length,8);assert.match(cards[0].querySelector('h2').textContent,/30/);assert.match(cards[1].querySelector('h2').textContent,/2$/);assert.match(cards.at(-1).querySelector('h2').textContent,/10$/);
 for(const c of cards)assert.deepEqual([...c.querySelectorAll('h3')].map(h=>h.textContent),['Module 1','Module 2']);
 f.dom.window.close();
});
test('unpaired in-progress modules sort before ordinary singles without losing records',()=>{
 const rows=examFixtures(),before=JSON.stringify(rows),f=setup('sat',rows);
 const singles=[...f.doc.querySelectorAll('.full-exam-grid:not(.paired-exams)>.exam-row')];
 assert.match(singles[0].textContent,/Unpaired Paper 40/);assert.match(singles[1].textContent,/Paper 2/);assert.match(singles[2].textContent,/Paper 10/);
 assert.equal(f.doc.querySelectorAll('[data-start],[data-review]').length,21);assert.equal(JSON.stringify(rows),before);
 f.dom.window.close();
});
for(const track of ['est','est2','act2'])test(track+' preserves single-paper ordering, readiness, retake and review controls',async()=>{
 const f=setup(track),q=s=>f.doc.querySelector(s);
 assert.match(q('.full-exam-grid>.exam-row').textContent,/Paper 30/);
 for(const id of ['held','closed']){const b=q(`[data-start="${id}"]`);assert(b.disabled);b.click();}
 assert.deepEqual(f.actions,[]);
 q('[data-start="resume"]').click();await new Promise(resolve=>setImmediate(resolve));q('[data-review="complete-attempt"]').click();q('[data-start="complete"]').click();await new Promise(resolve=>setImmediate(resolve));
 assert.deepEqual(f.actions,[{action:'start',id:'resume',untimed:false},{action:'review',id:'complete-attempt'},{action:'start',id:'complete',untimed:false}]);
 assert(q('[data-start="complete"]').isConnected);assert.equal(q('[data-start="complete"]').disabled,false);
 assert.match(q('[data-review="pending-attempt"]').parentElement.textContent,/Awaiting grading/);
 f.dom.window.close();
});
test('SAT locks Module 2 until completion, resumes existing work and keeps full-exam review',async()=>{
 const f=setup(),q=s=>f.doc.querySelector(s);
 assert(q('[data-start="p2m2"]').disabled);q('[data-start="p2m2"]').click();assert.equal(f.actions.length,0);
 q('[data-start="p30m2"]').click();await new Promise(resolve=>setImmediate(resolve));assert.deepEqual(f.actions[0],{action:'start',id:'p30m2',untimed:false});
 q('.exam-pair:nth-child(3) .pair-score button').click();assert.deepEqual(f.actions[1],{action:'review',id:'a4m2'});
 assert.match(q('.exam-pair:nth-child(3) .pair-score').textContent,/37\/44/);
 f.c.DASH.exams.find(e=>e.id==='p2m1').last={id:'new-result',status:'submitted',score:15,total:22};f.render();assert.equal(q('[data-start="p2m2"]').disabled,false);
 f.dom.window.close();
});
test('all tile action names include their visible action and specific exam title',()=>{
 for(const track of ['sat','est']){const f=setup(track);for(const b of f.doc.querySelectorAll('.full-exam-grid button')){const name=b.getAttribute('aria-label');assert(name?.startsWith(b.textContent+': '));assert(name.length>b.textContent.length+10);}f.dom.window.close();}
});
test('both submitted modules with a pending score say Awaiting grading',()=>{
 const f=setup(),card=[...f.doc.querySelectorAll('.exam-pair')].find(c=>c.querySelector('h2').textContent.includes('Practice 5'));
 assert.equal(card.querySelector('.pair-score strong').textContent,'Awaiting grading');
 assert.equal(card.querySelectorAll('[data-review]').length,3);assert.equal(card.querySelectorAll('[data-start]').length,0);f.dom.window.close();
});
test('unsafe title text stays text in headings and accessible button names',()=>{
 const rows=examFixtures('est').slice(0,1);rows[0].title='<img src=x onerror=alert(1)> "Exam"';const f=setup('est',rows);
 assert.equal(f.doc.querySelector('img'),null);assert.equal(f.doc.querySelector('h3').textContent,rows[0].title);assert.equal(f.doc.querySelector('[data-start]').getAttribute('aria-label'),'Start: '+rows[0].title);f.dom.window.close();
});
test('empty course catalogues show an empty state without controls',()=>{
 for(const track of ['sat','est','est2','act2']){const f=setup(track,[]);assert.match(f.doc.querySelector('main').textContent,/No full/);assert.equal(f.doc.querySelectorAll('button').length,0);f.dom.window.close();}
});
test('source and deployed artifact copies match',()=>{if(!process.env.EXAM_GRID_SOURCE)assert.equal(fs.readFileSync('web/index.html','utf8'),fs.readFileSync('dist/index.html','utf8'));});
