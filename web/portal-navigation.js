// Navigation only. Existing rendered destinations and their access checks remain authoritative.
(function(){
 'use strict';
 const byId=id=>document.getElementById(id);
 const bundlesEnabled=document.documentElement.dataset.practiceBundlesEnabled==='true';
 if(bundlesEnabled){const shortcut=byId('practiceBundlesShortcut');if(shortcut){shortcut.hidden=false;shortcut.style.removeProperty('display');}}
 const make=(tag,cls,text)=>{const el=document.createElement(tag);if(cls)el.className=cls;if(text)el.textContent=text;return el;};
 const labels={assignments:'Assignments',retakes:'Retakes',daily:'Daily quiz',vocabulary:'Vocabulary self-test',revision:'Topic practice',finalsDiagnosis:'Diagnosis',mistakes:'My mistakes',drill:'Weak-topic drill',overview:'My progress',lesson_exam:'Lesson exams',quiz:'Quizzes',full_exam:'Full exams',history:'Exam history',focus:'Lesson focus'};
 const descriptions={assignments:'Pending work and assessments to resume',retakes:'Instructor-approved repeat attempts',daily:'Five questions, streaks and leaderboard',vocabulary:'Word meanings, context and saved self-tests',formulas:'Quick reference by lesson',revision:'Revise a topic and practise questions',finalsDiagnosis:'Find the skills to work on next',mistakes:'Review and correct previous answers',drill:'Practise your weaker topics',overview:'Scores, participation and recent activity',lesson_exam:'Choose a lesson and its assigned tests',quiz:'Short assigned assessments',full_exam:'Timed exams and simulations',history:'Past attempts, scores and released solutions',focus:'Topic-by-topic strengths and gaps',teachingDashboard:'Group and student performance in one place',students:'Accounts, course access and family links',groups:'Membership, planning and group controls',exams:'Create, publish and assign assessments',bank:'Browse, edit and review questions',coursePlans:'Group roadmaps and preparation dates',results:'Scores and submitted attempts',lessons:'Compare topic performance across students',questions:'Find commonly missed questions',reportsAdmin:'Reported question and website problems',integrityAdmin:'Review recorded exam activity',devices:'Browser approvals and device access',audit:'Administrative change history',notifications:'Student announcements',registrations:'Review student registration requests',bankOperations:'Question use and trial cycles',quizAdmin:'Daily questions and quiz settings',revisionAdmin:'Manage released practice questions',formulasAdmin:'Course reference materials',finalsDiagnosisAdmin:'Weak topics and revision priorities'};
 const studentGroups=[['Study & practise',['daily','vocabulary','revision','formulas','drill']],['Exams & assignments',['assignments','retakes','lesson_exam','quiz','full_exam']],['Progress & review',['overview','mistakes','finalsDiagnosis','history','focus']]];
 const staffGroups=[['Teach & plan',['teachingDashboard','overview','coursePlans','groups','exams','quizAdmin']],['Students & progress',['students','registrations','results','lessons','finalsDiagnosisAdmin','questions']],['Content & review',['bank','revisionAdmin','formulasAdmin','bankOperations','reportsAdmin','integrityAdmin']],['Settings',['devices','audit','notifications','subscriptions']]];
 function link(label,href){const a=make('a','portal-shortcut',label);a.href=href;return a;}
 function button(label,action){const b=make('button','portal-shortcut',label);b.type='button';b.onclick=action;return b;}
 function scrollToContent(id){const target=byId(id);if(target){target.tabIndex=-1;target.focus({preventScroll:true});target.scrollIntoView?.({block:'start',behavior:'auto'});}}
 function directory(host,items,groups,key,searchId){
  const filter=make('div','portal-tool-search');const label=make('label','', 'Find a section');label.htmlFor=searchId;
  const input=make('input');input.type='search';input.id=searchId;input.placeholder='Search tools, exams, plans…';input.autocomplete='off';filter.append(label,input);host.append(filter);
  const grid=make('div','portal-tool-groups');const used=new Set();
  function group(name,nodes){if(!nodes.length)return;const section=make('section','portal-tool-group');section.append(make('h3','',name));const list=make('div','portal-tool-list');
   nodes.forEach(node=>{const id=node.dataset[key];used.add(node);node.classList.add('portal-tool');if(descriptions[id]){const hint=make('small','portal-tool-hint',descriptions[id]);node.append(hint);}list.append(node);});section.append(list);grid.append(section);
  }
  groups.forEach(([name,ids])=>group(name,ids.flatMap(id=>items.filter(b=>b.dataset[key]===id))));
  group('More tools',items.filter(b=>!used.has(b)));host.append(grid);
  const empty=make('p','portal-tool-empty','No matching section. Try “exams”, “progress” or “practice”.');empty.hidden=true;empty.setAttribute('role','status');host.append(empty);
  const apply=()=>{const term=input.value.trim().toLowerCase();let count=0;
   items.forEach(b=>{const match=!b.hidden&&b.textContent.toLowerCase().includes(term);b.classList.toggle('portal-filtered-out',!match);if(match)count++;});
   grid.querySelectorAll('.portal-tool-group').forEach(s=>s.classList.toggle('portal-filtered-out',![...s.querySelectorAll('.portal-tool')].some(b=>!b.hidden&&!b.classList.contains('portal-filtered-out'))));empty.hidden=count>0;
  };input.oninput=apply;apply();return apply;
 }
 function studentNavigation(){
  const tabs=document.querySelector('#examList .student-tabs');if(!tabs)return;
  byId('studentNavigation')?.remove();
  const items=[...tabs.querySelectorAll('[data-view]')];
  items.forEach(b=>{const name=labels[b.dataset.view];if(name&&b.firstChild)b.firstChild.textContent=name+(b.querySelector('span')?' ':'');});
  const hub=make('section','portal-navigation');hub.id='studentNavigation';hub.setAttribute('aria-label','Course navigation');
  const top=make('div','portal-nav-heading');top.append(make('strong','','Your course'));const course=button('My courses',()=>byId('switchBtn')?.click());
  if(byId('switchBtn')&&(typeof ST!=='undefined'&&ST.tracks?.length>1))top.append(course);hub.append(top);
  const quick=make('nav','portal-shortcuts portal-primary');quick.setAttribute('aria-label','Quick access');
  const track=typeof ST!=='undefined'?ST.track?.id:'';
  if(['sat','est','est2','act2'].includes(track)){quick.append(link('Today','/study-plan.html?track='+encodeURIComponent(track)+'&view=today'));}
  for(const id of ['full_exam','quiz','overview']){
   const target=items.find(b=>b.dataset.view===id&&!b.hidden);if(!target)continue;
   const b=button(id==='lesson_exam'?'Lessons':id==='full_exam'?'Exams':id==='overview'?'Results':labels[id],()=>setDashboardView(id));b.dataset.navView=id;b.setAttribute('aria-current',DASH.view===id&&!DASH.searchTerm?'page':'false');quick.append(b);
  }
  if(bundlesEnabled&&track)quick.insertBefore(link('Practice','/practice-bundles.html?track='+encodeURIComponent(track)),quick.querySelector('[data-nav-view=overview]'));
  if(['sat','est','est2','act2'].includes(track))quick.insertBefore(link('Study Plans','/study-plan.html?track='+encodeURIComponent(track)+'&view=calendar'),quick.querySelector('[data-nav-view=overview]'));
  hub.append(quick);
  if(window.StudentWork){const work=make('div');work.innerHTML=StudentWork.shortcuts();hub.append(work);}
  const details=make('details','portal-directory');details.id='studentTools';const summary=make('summary','','All learning tools · formulas, revision & more');details.append(summary);
  const picker=make('div','portal-section-picker');const label=make('label','','Go to section');label.htmlFor='studentSection';const select=make('select');select.id='studentSection';
  const used=new Set();studentGroups.forEach(([name,ids])=>{const group=make('optgroup');group.label=name;ids.forEach(id=>{const b=items.find(b=>b.dataset.view===id&&!b.hidden);if(!b)return;const o=make('option','',b.textContent.trim());o.value=id;o.disabled=b.disabled;group.append(o);used.add(id);});if(group.children.length)select.append(group);});
  items.filter(b=>!used.has(b.dataset.view)&&!b.hidden).forEach(b=>{const o=make('option','',b.textContent.trim());o.value=b.dataset.view;o.disabled=b.disabled;select.append(o);});if(DASH.view==='assigned_task'){const task=make('option','','Assigned daily task');task.value='assigned_task';task.disabled=true;select.append(task);}select.value=DASH.view;select.onchange=()=>setDashboardView(select.value);picker.append(label,select);hub.append(picker);
  tabs.replaceChildren();directory(tabs,items,studentGroups,'view','studentToolSearch');details.append(tabs);
  const resources=make('div','portal-resource-links');
  if(['sat','est','est2'].includes(track))resources.append(link('December revision guide',track==='sat'?'/sat-revision.html':'/est-revision.html?track='+track));
  if(resources.children.length)details.append(resources);hub.append(details);
  const current=make('p','navigation-location');current.id='navigationLocation';current.textContent=(typeof ST!=='undefined'?ST.track?.name:byId('listTitle')?.textContent)+' / '+(DASH.searchTerm?'Search results':select.selectedOptions[0]?.textContent||'Dashboard');hub.append(current);
  const anchor=byId('dashboardWeeklyObjective')||byId('dashboardObjective')||byId('examList');anchor.before(hub);if(window.StudentWork)StudentWork.wire();
  byId('dashboardSearch')?.addEventListener('input',()=>{const searching=!!DASH.searchTerm?.trim();current.textContent=(ST.track?.name||'My course')+' / '+(searching?'Search results':select.selectedOptions[0]?.textContent||'Dashboard');hub.querySelectorAll('[data-work-view]').forEach(b=>b.setAttribute('aria-current',!searching&&b.dataset.workView===DASH.view?'page':'false'));quick.querySelectorAll('[data-nav-view]').forEach(b=>b.setAttribute('aria-current',!searching&&b.dataset.navView===DASH.view?'page':'false'));});
 }
 if(typeof openTrack==='function'){const open=openTrack;openTrack=function(){byId('studentNavigation')?.remove();return open.apply(this,arguments);};}
 if(typeof paintDashboard==='function'){
  const paint=paintDashboard;paintDashboard=function(){byId('studentNavigation')?.remove();const r=paint.apply(this,arguments);studentNavigation();return r;};
  const navigate=setDashboardView;setDashboardView=function(){const r=navigate.apply(this,arguments);scrollToContent('dashboardContent');return r;};
  if(document.querySelector('#examList .student-tabs'))studentNavigation();
 }
 function adminNavigation(){
  const root=byId('tabs');if(!root||byId('staffTools'))return;
  const items=[...root.querySelectorAll('[data-v]')],links=[...root.querySelectorAll('a.tab')];
  const old=root.querySelector('.wrap');const toolbar=make('div','wrap portal-staff-navigation');
  const quick=make('nav','portal-shortcuts portal-primary');quick.setAttribute('aria-label','Instructor quick access');
  const plan=links.find(a=>a.getAttribute('href')==='/study-plan.html');
  if(plan){for(const [label,view] of [['Today','today'],['Study Plans','calendar']]){const a=link(label,'/study-plan.html?view='+view);a.dataset.planView=view;quick.append(a);}}
  for(const [id,label] of [['exams','Exams'],['quizAdmin','Quizzes'],['results','Results']]){
   const target=items.find(b=>b.dataset.v===id);if(!target)continue;const b=button(label,()=>target.click());b.dataset.navAdmin=id;quick.append(b);
  }
  toolbar.append(quick);
  const details=make('details','portal-directory');details.id='staffTools';details.append(make('summary','','All instructor tools'));
  const sectionPicker=root.querySelector('.admin-section-nav');if(sectionPicker){const home=button('Overview',()=>{ST.view='overview';syncAdminNavigation();render();scrollToContent('view');});sectionPicker.append(home);toolbar.append(sectionPicker);}
  const apply=directory(details,items,staffGroups,'v','staffToolSearch');
  if(links.length){const resources=make('div','portal-resource-links');links.forEach(a=>{a.classList.remove('tab');a.classList.add('portal-shortcut');resources.append(a);});details.append(resources);}
  toolbar.append(details);const location=make('p','navigation-location');location.id='staffNavigationLocation';toolbar.append(location);root.append(toolbar);if(old&&!old.children.length)old.remove();
  root.classList.add('portal-tabs-enhanced');
  // Close after choosing; use the original controls so loading and authorization stay intact.
  root.addEventListener('click',e=>{if(e.target.closest('[data-v]')){details.open=false;scrollToContent('view');}});
  byId('adminSection')?.addEventListener('change',()=>{details.open=false;scrollToContent('view');});
  const sync=syncAdminNavigation;syncAdminNavigation=function(){const r=sync.apply(this,arguments);
   const active=items.find(b=>b.dataset.v===ST.view);location.textContent='Instructor / '+(active?.childNodes[0]?.textContent.trim()||'Overview');
   items.forEach(b=>b.setAttribute('aria-current',b.dataset.v===ST.view?'page':'false'));
   quick.querySelectorAll('[data-nav-admin]').forEach(b=>{const source=items.find(i=>i.dataset.v===b.dataset.navAdmin);b.hidden=!!source?.hidden;b.disabled=!!source?.disabled;b.setAttribute('aria-current',b.dataset.navAdmin===ST.view?'page':'false');});
   quick.querySelectorAll('[data-plan-view]').forEach(a=>{const params=new URLSearchParams({view:a.dataset.planView});if(['sat','est','est2','act2'].includes(ST.track))params.set('track',ST.track);a.href='/study-plan.html?'+params;});
   apply();return r;};
  details.addEventListener('toggle',()=>{if(details.open)apply();});
  // Deferred extensions may add controls after the original tabs have moved.
  // Keep those controls in the directory and search without replacing handlers.
  new MutationObserver(()=>{
   const added=[...root.querySelectorAll('[data-v]')].filter(b=>!items.includes(b));
   if(!added.length)return;
   added.forEach(b=>{
    items.push(b);b.classList.add('portal-tool');
    const id=b.dataset.v;if(descriptions[id])b.append(make('small','portal-tool-hint',descriptions[id]));
    const name=staffGroups.find(([,ids])=>ids.includes(id))?.[0];
    const group=[...details.querySelectorAll('.portal-tool-group')].find(g=>g.querySelector('h3')?.textContent===name);
    if(group)group.querySelector('.portal-tool-list').append(b);
   });
   apply();
  }).observe(root,{childList:true,subtree:true});
 }
 if(typeof syncAdminNavigation==='function')adminNavigation();
 if(typeof renderTracks==='function'){const paintTracks=renderTracks;renderTracks=function(){const r=paintTracks.apply(this,arguments);const plan=byId('chooserPlanShortcut');if(plan)plan.hidden=!ST.tracks.some(t=>['sat','est','est2','act2'].includes(t.id));return r;};}
 function pageNavigation(){
  const page=document.body.dataset.portalPage;if(!page)return;
  const header=document.querySelector('body>header');if(!header)return;
  if(page==='study'){const requested=new URLSearchParams(location.search).get('track'),select=byId('track');if(select&&[...select.options].some(o=>o.value===requested))select.value=requested;}
  const nav=make('nav','portal-page-navigation');nav.setAttribute('aria-label','Portal navigation');header.after(nav);
  const update=()=>{
   const selection=byId('track')||byId('course'),params=new URLSearchParams(location.search);
   const requested=selection?.value||params.get('track');
   const track=page==='sat-revision'?'sat':['sat','est','est2','act2','sat_eng','est_eng'].includes(requested)?requested:(page==='est-revision'?'est':'sat');
   const math=['sat','est','est2','act2'].includes(track);
   nav.replaceChildren();const isStaff=document.body.dataset.portalRole==='staff'||byId('back')?.getAttribute('href')==='/admin.html';
   const context=new URLSearchParams({track});
   if(['study','checkpoint'].includes(page))for(const id of ['group','student']){const value=byId(id)?.value;if(value)context.set(id,value);}
   const planUrl=view=>{const p=new URLSearchParams(context);const date=byId('date')?.value||byId('checkpointDate')?.value||params.get('date');if(date)p.set('date',date);p.set('view',view);return '/study-plan.html?'+p;};
   const primary=make('div','portal-primary');
   const activeView=byId('calendarTab')?.getAttribute('aria-pressed')==='true'||byId('roadmapTab')?.getAttribute('aria-pressed')==='true'||byId('progressTab')?.getAttribute('aria-pressed')==='true';
   const activity=(student,section)=>isStaff?'/admin.html?'+new URLSearchParams({section,track}):'/?'+new URLSearchParams({study_track:track,study_activity:student});
   const routes=[
    ...(math?[['Today',planUrl('today'),page==='study'&&!activeView]]:[]),
    ['Exams',activity('full_exam','exams'),false],['Quizzes',activity('quiz','quizAdmin'),false],
    ...(!isStaff?[['Practice','/practice-bundles.html?'+new URLSearchParams({track}),page==='practice']]:[]),
    ...(math?[['Study Plans',planUrl('calendar'),page==='study'&&activeView]]:[]),
    ['Results',activity('overview','results'),false]
   ];
   routes.forEach(([label,href,active])=>{const a=link(label,href);if(active)a.setAttribute('aria-current','page');primary.append(a);});nav.append(primary);
   const more=make('details','portal-page-more');more.append(make('summary','','More tools'));
   const secondary=make('div','portal-resource-links');secondary.append(link(isStaff?'Instructor console':'My courses',isStaff?'/admin.html':'/'));
   if(!isStaff)for(const [label,id] of [['Assignments','assignments'],['Retakes','retakes'],['Lesson exams','lesson_exam'],['Lesson focus','focus'],['My mistakes','mistakes'],['Diagnosis','finalsDiagnosis'],['Exam history','history']]){
    if(track==='sat_eng'&&['mistakes','finalsDiagnosis'].includes(id))continue;
    secondary.append(link(label,activity(id,'')));
   }
   if(math){const p=new URLSearchParams(context);p.set('mode','assessments');const a=link('Progress & corrections','/checkpoint.html?'+p);if(page==='checkpoint')a.setAttribute('aria-current','page');secondary.append(a);}
   if(['sat','est','est2'].includes(track))secondary.append(link('December revision',track==='sat'?'/sat-revision.html':'/est-revision.html?track='+track));
   more.append(secondary);nav.append(more);
   const back=byId('portalBack');if(back){back.href=activity('assignments','exams');back.textContent='← Back to course';}
  };update();for(const id of ['track','course','group','student','date','checkpointDate'])byId(id)?.addEventListener('change',update);
  document.addEventListener('study-plan-view',update);document.addEventListener('portal-context',update);window.addEventListener('popstate',update);document.addEventListener('click',e=>{if(e.target.closest?.('[data-course]'))update();});
  for(const id of ['track','course'])if(byId(id))new MutationObserver(update).observe(byId(id),{childList:true});
  if(byId('back'))new MutationObserver(update).observe(byId('back'),{attributes:true,attributeFilter:['href']});
 }
 pageNavigation();
 // The header menu lives in the browser's top layer, outside legacy tab wrappers.
 // Rebuild from current controls each time: roles, courses and late extensions
 // still determine availability. Selecting a tool invokes its original handler.
 function openToolMenu(admin,trigger){
  const scope=byId(admin?'tabs':'vList');
  if(!scope||scope.hidden||scope.classList.contains('hidden'))return;
  if(admin)adminNavigation();
  const source=byId(admin?'staffTools':'studentTools');if(!source)return;
  const available=node=>node.isConnected&&!node.closest('[hidden],.hidden')&&!node.disabled;
  const visible=node=>!node.hidden&&!node.classList.contains('hidden')&&node.style.display!=='none';
  const previous=byId('portalToolsMenu');if(previous?.open)return;previous?.remove();
  const menu=make('dialog','portal-tools-menu portal-directory');menu.id='portalToolsMenu';menu.setAttribute('aria-labelledby','portalToolsTitle');
  const heading=make('div','portal-tools-heading');const title=make('h2','',admin?'Instructor tools':'Learning tools');title.id='portalToolsTitle';
  const close=()=>{if(menu.open)menu.close();trigger.setAttribute('aria-expanded','false');};
  const dismiss=()=>{close();trigger.focus({preventScroll:true});};
  const closeButton=button('Close',dismiss);closeButton.id='portalToolsClose';heading.append(title,closeButton);menu.append(heading);
  const key=admin?'v':'view';const active=admin?ST.view:DASH.view;
  const nodes=[...source.querySelectorAll(admin?'[data-v]':'[data-view]')].filter(visible).map(original=>{
   const copy=original.cloneNode(true);copy.querySelectorAll('.portal-tool-hint').forEach(h=>h.remove());
   const item=button(copy.textContent.trim(),()=>{close();if(available(original)&&visible(original))original.click();});
   item.dataset.toolTarget=original.dataset[key];item.disabled=original.disabled;item.setAttribute('aria-current',item.dataset.toolTarget===active?'page':'false');return item;
  });
  directory(menu,nodes,admin?staffGroups:studentGroups,'toolTarget','portalToolsSearch');
  const resources=make('div','portal-resource-links');const seen=new Set();
  for(const original of source.querySelectorAll('a[href]')){if(!visible(original)||seen.has(original.href))continue;seen.add(original.href);const a=original.cloneNode(true);a.removeAttribute('id');a.onclick=()=>close();resources.append(a);}
  if(resources.children.length)menu.append(resources);
  menu.addEventListener('cancel',e=>{e.preventDefault();dismiss();});
  menu.addEventListener('close',()=>trigger.setAttribute('aria-expanded','false'));
  // If native dialogs are unavailable, the visible inline directory still works.
  if(typeof menu.showModal!=='function'){source.open=true;source.querySelector('summary')?.focus();source.scrollIntoView?.({block:'start',behavior:'auto'});return;}
  document.body.append(menu);menu.showModal();trigger.setAttribute('aria-expanded','true');closeButton.focus({preventScroll:true});
 }
 const masthead=document.querySelector('header.top .wrap');
 if(masthead){const admin=!!byId('tabs');const menu=button('All tools',()=>openToolMenu(admin,menu));menu.id=admin?'staffToolsShortcut':'studentToolsShortcut';menu.setAttribute('aria-controls','portalToolsMenu');menu.setAttribute('aria-haspopup','dialog');menu.setAttribute('aria-expanded','false');masthead.insertBefore(menu,byId('outBtn'));}

 document.addEventListener('keydown',e=>{if(e.key==='Escape'){const details=e.target.closest?.('details.portal-directory');if(details?.open){details.open=false;details.querySelector('summary').focus();}}});
})();
