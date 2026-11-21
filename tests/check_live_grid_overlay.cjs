// Read-only contract comparison of a captured live HTML file and its draft overlay.
// node tests/check_live_grid_overlay.cjs LIVE_INDEX DRAFT_INDEX
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const {JSDOM}=require('./english-runtime/node_modules/jsdom');
const {examFixtures,extract}=require('./full_exam_grid_fixture.cjs');
const [live,draft]=process.argv.slice(2).map(p=>fs.readFileSync(p,'utf8'));
const anchor='function wireDashboard()';assert.equal(live.slice(live.indexOf(anchor)),draft.slice(draft.indexOf(anchor)),'all handlers, runner, submission and later scripts must stay unchanged');
function controls(html,track,access,variant){
 const dom=new JSDOM('<main></main>',{runScripts:'outside-only'}),c=dom.getInternalVMContext(),rows=examFixtures(track);
 if(variant==='stale-first'&&track==='sat')rows.find(e=>e.id==='p30m1').last=null;
 Object.assign(c,{ST:{track:{id:track}},DASH:{exams:rows,access},esc:s=>String(s??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]))});
 vm.runInContext(extract(html,'function displayTitle(','function dashboardOverview(')+extract(html,'function assessmentRow(','function historySection('),c);
 c.document.querySelector('main').innerHTML=c.fullExamSection();
 const out=[...c.document.querySelectorAll('button[data-start],button[data-review]')].map(b=>({key:b.dataset.start?'start:'+b.dataset.start:'review:'+b.dataset.review,disabled:b.disabled,label:b.textContent})).sort((a,b)=>a.key.localeCompare(b.key));dom.window.close();return out;
}
let count=0;
for(const track of ['sat','est','est2','act2'])for(const access of [{practice_open:true},{practice_open:false,can_finish:false},{practice_open:false,can_finish:true}])for(const variant of ['normal','stale-first']){
 assert.deepEqual(controls(draft,track,access,variant),controls(live,track,access,variant));count++;
}
console.log(JSON.stringify({cases:count,passed:true,handlersAndRunnerUnchanged:true,backendCalls:0}));
