const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {JSDOM}=require('./passage-runtime/node_modules/jsdom');
const script=fs.readFileSync('web/portal-navigation.js','utf8');
test('student section picker includes extension destinations and stays synchronized',()=>{
 const dom=new JSDOM('<h1 id="listTitle">SAT Math</h1><main id="examList"></main>',{runScripts:'outside-only'}),w=dom.window;
 w.DASH={view:'daily'};w.ST={track:{name:'SAT Math'}};w.scrollTo=()=>{};
 w.paintDashboard=()=>{w.document.getElementById('examList').innerHTML='<nav class="student-tabs"><button data-view="finalsDiagnosis">Finals diagnosis</button><button data-view="daily">Daily practice</button><button data-view="quiz">Quizzes <span>2</span></button><button data-view="overview">My progress</button></nav>';};
 w.setDashboardView=view=>{w.DASH.view=view;w.paintDashboard();};
 w.eval(script);w.paintDashboard();
 assert.equal(w.document.querySelector('#studentSection').value,'daily');
 assert.ok(w.document.querySelector('option[value="finalsDiagnosis"]'));
 const picker=w.document.querySelector('#studentSection');picker.value='quiz';picker.dispatchEvent(new w.Event('change'));
 assert.equal(w.DASH.view,'quiz');assert.match(w.document.querySelector('#navigationLocation').textContent,/SAT Math \/ Quizzes/);
 assert.equal(w.document.querySelectorAll('#studentSection').length,1);
 w.setDashboardView('overview');assert.equal(w.document.querySelector('#studentSection').value,'overview');
 dom.window.close();
});
test('instructor overview shortcut uses the existing render path',()=>{
 const dom=new JSDOM('<nav id="tabs"><button data-v="overview"></button><button data-v="bank"></button><div class="admin-section-nav"><select id="adminSection"></select></div></nav>',{runScripts:'outside-only'}),w=dom.window;
 w.ST={view:'bank'};w.scrollTo=()=>{};let renders=0;w.render=()=>renders++;w.syncAdminNavigation=()=>{};
 w.eval(script);w.syncAdminNavigation();
 assert.equal(w.document.querySelector('[data-v="bank"]').getAttribute('aria-current'),'page');
 w.document.querySelector('.admin-section-nav button').click();assert.equal(w.ST.view,'overview');assert.equal(renders,1);
 dom.window.close();
});
