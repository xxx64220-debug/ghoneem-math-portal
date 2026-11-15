const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {JSDOM}=require('./passage-runtime/node_modules/jsdom');
const script=fs.readFileSync('web/portal-navigation.js','utf8');
test('real admin markup keeps All tools and delayed diagnosis controls connected',async()=>{
 const dom=new JSDOM(fs.readFileSync('web/admin.html','utf8'),{runScripts:'outside-only',url:'https://portal.test/admin.html'}),w=dom.window,errors=[];
 w.addEventListener('error',event=>{errors.push(event.error);event.preventDefault();});
 w.ST={view:'overview',me:{role:'admin'}};w.render=()=>{};w.syncAdminNavigation=()=>{};
 w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};
 w.document.getElementById('tabs').classList.remove('hidden');
 w.eval(fs.readFileSync('web/hardest-questions.js','utf8'));
 w.eval(script);
 await new Promise(resolve=>w.setTimeout(resolve,20));
 assert.deepEqual(errors,[]);
 const d=w.document;d.getElementById('staffToolsShortcut').click();
 assert(d.getElementById('portalToolsMenu').open);
 const diagnosis=d.querySelector('#staffTools [data-v="finalsDiagnosisAdmin"]');assert(diagnosis);
 assert(d.querySelector('#portalToolsMenu [data-tool-target="finalsDiagnosisAdmin"]'));
 assert(diagnosis.classList.contains('portal-tool'));
 assert(d.querySelector('#adminSection option[value="finalsDiagnosisAdmin"]'));
 const search=d.getElementById('staffToolSearch');search.value='diagnosis';search.dispatchEvent(new w.Event('input'));
 assert(!diagnosis.classList.contains('portal-filtered-out'));
 search.value='unmatched';search.dispatchEvent(new w.Event('input'));assert(diagnosis.classList.contains('portal-filtered-out'));
 dom.window.close();
});

test('mobile CSS does not hide the enhanced instructor navigation',()=>{
 const dom=new JSDOM(fs.readFileSync('web/admin.html','utf8'),{runScripts:'outside-only'}),w=dom.window;
 w.ST={view:'overview'};w.render=()=>{};w.syncAdminNavigation=()=>{};w.eval(script);
 const style=w.document.createElement('style');style.textContent=fs.readFileSync('web/portal-controls.css','utf8');w.document.head.append(style);
 const toolbar=w.document.querySelector('.portal-staff-navigation');
 for(const rule of style.sheet.cssRules){if(!rule.media)continue;for(const mobile of rule.cssRules){
  if(mobile.style?.display==='none')assert(!toolbar.matches(mobile.selectorText),'Mobile rule hides the tools container: '+mobile.selectorText);
 }}
 assert.equal(w.document.getElementById('adminSection').closest('details'),null,'Section picker remains available while the directory is closed');
 dom.window.close();
});

test('All tools opens an independent menu and uses each original staff action once',()=>{
 const dom=new JSDOM('<header class="top"><div class="wrap"><button id="outBtn">Sign out</button></div></header><nav id="tabs"><div class="wrap"><button class="tab" data-v="students">Students</button><button class="tab" data-v="exams">Exams</button><button class="tab" data-v="notifications" hidden>Notifications</button><button class="tab" data-v="audit" disabled>Audit</button></div></nav><div id="view"></div>',{runScripts:'outside-only'}),w=dom.window,d=w.document,calls=[];
 w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};w.HTMLDialogElement.prototype.close=function(){this.open=false;this.dispatchEvent(new w.Event('close'));};
 w.ST={view:'students'};w.render=()=>{};w.syncAdminNavigation=()=>{};
 for(const b of d.querySelectorAll('[data-v]'))b.onclick=()=>calls.push(b.dataset.v);
 w.eval(script);const trigger=d.getElementById('staffToolsShortcut');trigger.click();
 let menu=d.getElementById('portalToolsMenu');assert(menu.open);assert.equal(menu.parentElement,d.body);assert.equal(trigger.getAttribute('aria-expanded'),'true');
 assert(!menu.querySelector('[data-tool-target="notifications"]'));assert(menu.querySelector('[data-tool-target="audit"]').disabled);
 const search=menu.querySelector('input');search.value='create';search.dispatchEvent(new w.Event('input'));
 assert(!menu.querySelector('[data-tool-target="exams"]').classList.contains('portal-filtered-out'));
 menu.querySelector('[data-tool-target="exams"]').click();assert.deepEqual(calls,['exams']);assert(!menu.open);assert.equal(trigger.getAttribute('aria-expanded'),'false');
 trigger.click();menu=d.getElementById('portalToolsMenu');assert.equal(menu.querySelector('input').value,'');
 menu.querySelector('input').dispatchEvent(new w.KeyboardEvent('keydown',{key:'Escape',bubbles:true}));
 menu.dispatchEvent(new w.Event('cancel',{cancelable:true}));assert(!menu.open);assert.equal(d.activeElement,trigger);
 trigger.click();d.querySelector('[data-v="students"]').hidden=true;d.querySelector('#portalToolsMenu [data-tool-target="students"]').click();assert.deepEqual(calls,['exams']);
 d.getElementById('tabs').classList.add('hidden');trigger.click();assert(!d.getElementById('portalToolsMenu').open);
 dom.window.close();
});

test('older browsers can open the inline directory without a dialog API',()=>{
 const dom=new JSDOM('<header class="top"><div class="wrap"><button id="outBtn"></button></div></header><nav id="tabs"><button data-v="students">Students</button></nav>',{runScripts:'outside-only'}),w=dom.window,d=w.document;
 w.ST={view:'students'};w.render=()=>{};w.syncAdminNavigation=()=>{};w.eval(script);
 d.getElementById('staffToolsShortcut').click();assert(d.getElementById('staffTools').open);assert.equal(d.activeElement.tagName,'SUMMARY');
 dom.window.close();
});

test('student menu follows course rerenders and keeps hidden tools unavailable',()=>{
 const dom=new JSDOM('<header class="top"><div class="wrap"><button id="outBtn">Sign out</button></div></header><main id="vList"><div id="examList"></div></main>',{runScripts:'outside-only'}),w=dom.window,d=w.document;
 w.HTMLDialogElement.prototype.showModal=function(){this.open=true;};w.HTMLDialogElement.prototype.close=function(){this.open=false;this.dispatchEvent(new w.Event('close'));};
 w.ST={track:{id:'sat',name:'SAT Math'}};w.DASH={view:'overview'};
 w.paintDashboard=()=>{d.getElementById('examList').innerHTML='<nav class="student-tabs"><button data-view="overview">Progress</button><button data-view="history">History</button><button data-view="revision" hidden>Revision</button></nav><div id="dashboardContent"></div>';for(const b of d.querySelectorAll('[data-view]'))b.onclick=()=>w.setDashboardView(b.dataset.view);};
 w.setDashboardView=id=>{w.DASH.view=id;w.paintDashboard();};w.eval(script);w.paintDashboard();
 const trigger=d.getElementById('studentToolsShortcut');trigger.click();assert(d.getElementById('portalToolsMenu').open);assert(!d.querySelector('#portalToolsMenu [data-tool-target="revision"]'));
 d.querySelector('#portalToolsMenu [data-tool-target="history"]').click();assert.equal(w.DASH.view,'history');assert.equal(d.activeElement.id,'dashboardContent');
 trigger.click();assert.equal(d.querySelector('#portalToolsMenu [data-tool-target="history"]').getAttribute('aria-current'),'page');
 assert.equal(d.getElementById('studentSection').closest('details'),null);
 d.getElementById('portalToolsClose').click();assert.equal(d.activeElement,trigger);
 dom.window.close();
});
test('Quizzes links from plans open the category without starting an exam or bypassing access',async()=>{
 const html=fs.readFileSync('web/index.html','utf8'),code=html.slice(html.indexOf('async function openStudyLink()'),html.indexOf('function show(id)'));
 for(const allowed of [true,false]){
  const dom=new JSDOM('<div id="dashboardContent"></div>',{runScripts:'outside-only',url:'https://portal.test/?study_track=est&study_activity=quiz'}),w=dom.window;
  w.ST={tracks:[{id:'est'}]};w.DASH={access:{practice_open:allowed},view:'history'};w.$=id=>w.document.getElementById(id);w.openTrack=async()=>{};w.setDashboardView=view=>w.DASH.view=view;w.startExam=()=>{throw Error('must not start an attempt');};
  w.eval(code);assert.equal(await w.openStudyLink(),true);assert.equal(w.DASH.view,allowed?'quiz':'history');dom.window.close();
 }
});
test('course cards provide separate accessible category buttons with the correct course',()=>{
 const html=fs.readFileSync('web/index.html','utf8'),code=html.slice(html.indexOf('function renderTracks()'),html.indexOf('/* ========================== EXAM LIST'));
 const dom=new JSDOM('<div id="trackGrid"></div>',{runScripts:'outside-only'}),w=dom.window,calls=[];
 w.ST={tracks:[{id:'sat',name:'SAT Math',exams_available:3,attempts_done:1},{id:'sat_eng',name:'SAT English',exams_available:2,attempts_done:0}]};w.$=id=>w.document.getElementById(id);w.esc=String;w.openTrack=(track,view)=>calls.push([track.id,view]);
 w.eval(code);w.renderTracks();const cards=w.document.querySelectorAll('.track-card');assert.equal(cards.length,2);
 for(const card of cards){assert.equal(card.tagName,'ARTICLE');assert.equal(card.querySelectorAll('button button, button a').length,0);for(const button of card.querySelectorAll('button'))button.click();}
 assert.deepEqual(calls,[['sat',undefined],['sat','mistakes'],['sat','assignments'],['sat','retakes'],['sat','full_exam'],['sat','quiz'],['sat','lesson_exam'],['sat_eng',undefined],['sat_eng','mistakes'],['sat_eng','assignments'],['sat_eng','retakes'],['sat_eng','full_exam'],['sat_eng','quiz'],['sat_eng','lesson_exam']]);dom.window.close();
});
test('primary destinations keep assessment selection intact',()=>{
 const dom=new JSDOM('<main id="examList"></main>',{runScripts:'outside-only'}),w=dom.window;
 w.ST={track:{id:'sat',name:'SAT Math'}};w.DASH={view:'daily'};
 w.paintDashboard=()=>{w.document.getElementById('examList').innerHTML='<nav class="student-tabs">'+['daily','quiz','full_exam','lesson_exam','overview','mistakes'].map(id=>'<button data-view="'+id+'">'+id+'</button>').join('')+'</nav><div id="dashboardContent"></div>';};w.setDashboardView=id=>{w.DASH.view=id;w.paintDashboard();};
 w.eval(script);w.paintDashboard();assert.deepEqual([...w.document.querySelectorAll('.portal-shortcuts button')].slice(0,3).map(b=>b.textContent),['Exams','Quizzes','Results']);
 w.document.querySelector('[data-nav-view="quiz"]').click();assert.equal(w.DASH.view,'quiz');assert.equal(w.document.querySelector('[data-nav-view="quiz"]').getAttribute('aria-current'),'page');assert.equal(w.document.querySelector('#studentTools').open,false);assert(w.document.querySelector('[data-view="mistakes"]'));dom.window.close();
});
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

test('tool search includes descriptions, preserves controls, and clears cleanly',()=>{
 const dom=new JSDOM('<main id="examList"></main>',{runScripts:'outside-only'}),w=dom.window;
 w.ST={track:{id:'est_eng',name:'EST English'}};w.DASH={view:'vocabulary'};w.paintDashboard=()=>{w.document.getElementById('examList').innerHTML='<nav class="student-tabs"><button data-view="vocabulary">Vocabulary</button><button data-view="history">History</button><button data-view="revision" hidden>Restricted practice</button></nav><div id="dashboardContent"></div>';w.document.querySelector('[data-view="history"]').onclick=()=>w.setDashboardView('history');};w.setDashboardView=id=>{w.DASH.view=id;w.paintDashboard();};
 w.eval(script);w.paintDashboard();const d=w.document,input=d.getElementById('studentToolSearch');input.value='released solutions';input.dispatchEvent(new w.Event('input'));assert(!d.querySelector('[data-view="history"]').classList.contains('portal-filtered-out'));assert(d.querySelector('[data-view="vocabulary"]').classList.contains('portal-filtered-out'));
 input.value='zzzz';input.dispatchEvent(new w.Event('input'));assert.equal(d.querySelector('.portal-tool-empty').hidden,false);input.value='';input.dispatchEvent(new w.Event('input'));assert(d.querySelector('[data-view="revision"]').hidden);assert(!d.querySelector('#studentSection option[value="revision"]'));
 d.querySelector('[data-view="history"]').click();assert.equal(w.DASH.view,'history');assert.equal(d.querySelectorAll('#studentNavigation').length,1);assert.equal(d.querySelectorAll('[data-view="history"]').length,1);dom.window.close();
});

test('instructor shortcuts preserve original handlers and hidden staff tools',()=>{
 const dom=new JSDOM('<nav id="tabs"><div class="wrap"><a class="tab" href="/study-plan.html">Daily study plans</a><button class="tab" data-v="teachingDashboard">Teaching dashboard</button><button class="tab" data-v="results">Students</button><button class="tab" data-v="notifications" hidden>Notifications</button></div><div class="admin-section-nav"><select id="adminSection"></select></div></nav><div id="view"></div>',{runScripts:'outside-only'}),w=dom.window;
 let clicks=0;w.ST={view:'results'};w.render=()=>{};w.syncAdminNavigation=()=>{};const original=w.document.querySelector('[data-v="results"]');original.onclick=()=>clicks++;
 w.eval(script);w.syncAdminNavigation();w.document.querySelector('[data-nav-admin="results"]').click();assert.equal(clicks,1);assert.equal(w.document.querySelector('[data-v="results"]'),original);assert(w.document.querySelector('[data-v="notifications"]').hidden);assert(w.document.querySelector('#staffTools a[href="/study-plan.html"]'));assert.equal(w.document.querySelector('#staffTools a').classList.contains('tab'),false);dom.window.close();
});

test('shared navigation follows selected course and EST history changes',()=>{
 const dom=new JSDOM('<body data-portal-page="study"><header><a id="back" href="/">Back</a></header><select id="track"><option value="sat">SAT</option><option value="est2">EST II</option></select></body>',{runScripts:'outside-only',url:'https://portal.test/study-plan.html?track=est2'}),w=dom.window;
 w.eval(script);assert(w.document.querySelector('.portal-page-navigation a[href="/est-revision.html?track=est2"]'));w.document.getElementById('track').value='est2';w.document.getElementById('track').dispatchEvent(new w.Event('change'));assert(w.document.querySelector('.portal-page-navigation a[href="/est-revision.html?track=est2"]'));assert(w.document.querySelector('.portal-page-navigation a[href="/?study_track=est2&study_activity=overview"]'));dom.window.close();
 const est=new JSDOM('<body data-portal-page="est-revision"><header></header><a data-course="est2" href="?track=est2">EST II</a></body>',{runScripts:'outside-only',url:'https://portal.test/est-revision.html?track=est'}),v=est.window;v.document.querySelector('[data-course]').onclick=e=>{e.preventDefault();v.history.pushState(null,'','?track=est2');};v.eval(script);v.document.querySelector('[data-course]').click();assert(v.document.querySelector('.portal-page-navigation a[href="/study-plan.html?track=est2&view=today"]'));est.window.close();
});

test('family shortcuts open the requested section without replacing the private-link token',async()=>{
 const dom=new JSDOM(fs.readFileSync('web/parent.html','utf8'),{runScripts:'outside-only',url:'https://portal.test/parent.html#test-private-token'}),w=dom.window;
 w.fetch=async()=>({ok:true,status:200,json:async()=>({name:'Sample',groups:{},skills:[]})});w.eval(fs.readFileSync('web/parent.js','utf8'));await new Promise(r=>setImmediate(r));
 const d=w.document;assert.equal(d.getElementById('familyNavigation').hidden,false);d.querySelector('[data-family-target="familyCompleted"]').click();assert(d.getElementById('familyCompleted').open);assert.equal(w.location.hash,'#test-private-token');assert.equal(d.activeElement.id,'familyCompleted');assert(d.getElementById('familyScores'));assert(d.getElementById('familyPractice'));dom.window.close();
});

test('planner primary routes preserve student context and choose staff handlers after role resolution',()=>{
 const dom=new JSDOM('<body data-portal-page="study"><header><a id="back" href="/admin.html">Back</a></header><select id="track"><option value="est2">EST II</option></select><select id="student"><option value="adam">Adam</option></select><select id="group"><option value="group-a">Group</option></select><button id="calendarTab" aria-pressed="true"></button></body>',{runScripts:'outside-only',url:'https://portal.test/study-plan.html'}),w=dom.window,d=w.document;
 w.eval(script);
 const links=[...d.querySelectorAll('.portal-primary a')];assert.deepEqual(links.map(a=>a.textContent),['Today','Exams','Quizzes','Study Plans','Results']);
 assert.equal(new URL(links[3].href).searchParams.get('student'),'adam');assert.equal(new URL(links[3].href).searchParams.get('group'),'group-a');
 assert.equal(links[3].getAttribute('aria-current'),'page');assert.match(links[1].href,/admin.html\?section=exams&track=est2/);assert.match(links[2].href,/section=quizAdmin/);assert.match(links[4].href,/section=results/);
 assert(!d.querySelector('.portal-page-more').open);dom.window.close();
});

test('staff URL hints allow only safe existing destinations after authentication',()=>{
 const html=fs.readFileSync('web/admin.html','utf8'),code=html.slice(html.indexOf('function applyPlannerDestination()'),html.indexOf('async function notifications()'));
 for(const [role,section,track,hidden,expected] of [['admin','results','est2',false,'results'],['student','results','est2',false,'overview'],['instructor','notifications','est2',false,'overview'],['admin','results','foreign',false,'overview'],['admin','results','est2',true,'overview']]){
 const dom=new JSDOM('<select id="trackSel"><option value="est2">EST II</option></select><button data-v="results" '+(hidden?'hidden':'')+'>Results</button>',{runScripts:'outside-only',url:'https://portal.test/admin.html?section='+section+'&track='+track}),w=dom.window;
 w.ST={view:'overview',track:'',me:{role},tracks:[{id:'est2'}]};w.$=id=>w.document.getElementById(id);w.eval(code);w.applyPlannerDestination();assert.equal(w.ST.view,expected);if(expected==='results'){assert.equal(w.ST.track,'est2');assert.equal(w.location.search,'');}dom.window.close();}
});


test('released practice navigation links every supported course without starting an exam',()=>{
 const html=fs.readFileSync('web/index.html','utf8');
 assert.match(html,/data-practice-bundles-enabled="true"/);
 const dom=new JSDOM('<html data-practice-bundles-enabled="true"><body><a id="practiceBundlesShortcut" href="/practice-bundles.html" hidden style="display:none">Practice bundles</a><main id="vList"><div id="examList"></div></main></body></html>',{runScripts:'outside-only',url:'https://portal.test/'}),w=dom.window,d=w.document;
 w.ST={track:{id:'sat',name:'SAT Math'}};w.DASH={view:'overview'};
 w.paintDashboard=()=>{d.getElementById('examList').innerHTML='<nav class="student-tabs"><button data-view="overview">Progress</button><button data-view="full_exam">Exams</button></nav><div id="dashboardContent"></div>';};
 w.setDashboardView=id=>{w.DASH.view=id;w.paintDashboard();};w.startExam=()=>{throw Error('Navigation must not start an exam');};
 w.eval(script);
 assert.equal(d.getElementById('practiceBundlesShortcut').hidden,false);assert.equal(d.getElementById('practiceBundlesShortcut').style.display,'');
 for(const track of ['sat','est','est2','act2','est_eng','sat_eng']){
  w.ST.track={id:track,name:track};w.paintDashboard();
  const links=[...d.querySelectorAll('#studentNavigation a')].filter(a=>a.textContent==='Practice');
  assert.equal(links.length,1);assert.equal(links[0].getAttribute('href'),'/practice-bundles.html?track='+track);
 }
 dom.window.close();
});
