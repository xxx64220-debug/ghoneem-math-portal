// Display metadata only. Content, access and grading remain on the server.
(function(){
 'use strict';
 const catalog=window.GhoneemLessonCatalog||[],index=window.GhoneemAssessmentIndex||[];
 const entries=new Map(catalog.map(c=>[c.id,c])),details=new Map(index.map(c=>[c.id,c]));
 const state={track:null,type:null,scope:'all',lesson:'',difficulty:'',query:'',pages:{},expanded:new Set()};
 const PAGE_SIZE=5;
 let searchTimer;
 const clean=s=>String(s||'').toLocaleLowerCase().replace(/[—–·]/g,' ').replace(/\s+/g,' ').trim();
 const live=e=>e.last?.status==='in_progress';
 const done=e=>!!e.last&&!live(e);
 const available=e=>e.open&&e.content_ready!==false&&(!e.last||e.assessment_type==='lesson_exam'||e.retake_available);
 // Retained for the administrator's historical additions filter.
 function isNew(exam){return entries.get(exam.id)?.new===true;}
 function lessonNames(track){
  const lessons=typeof MATH_LESSONS!=='undefined'?MATH_LESSONS[track]||[]:[];
  const names=lessons.map(l=>[l,l]);
  if(typeof MATH_LESSON_ALIASES!=='undefined')for(const [alias,lesson] of Object.entries(MATH_LESSON_ALIASES))if(lessons.includes(lesson))names.push([alias,lesson]);
  for(const c of catalog.filter(c=>c.track_id===track))names.push([c.lesson,c.lesson],[c.lesson.split(' · ').at(-1),c.lesson]);
  names.sort((a,b)=>b[0].length-a[0].length);
  return names.map(([name,lesson])=>[clean(name),lesson]);
 }
 function lessonFor(exam,track,getNames=()=>lessonNames(track)){
  const entry=details.get(exam.id)||entries.get(exam.id);if(entry?.track_id===track)return entry.lesson;
  const text=clean(exam.title);
  if(/mixed|multi.topic/.test(text))return exam.assessment_type==='quiz'?'Mixed-topic quizzes':'Mixed lesson practice';
  return getNames().find(([name])=>name.length>=5&&text.includes(name))?.[1]||(exam.assessment_type==='quiz'?'Mixed-topic quizzes':'Mixed lesson practice');
 }
 function added(e){return details.get(e.id)?.added||e.created_at||'';}
 function rank(e){return live(e)?0:available(e)?(done(e)?2:1):done(e)?3:4;}
 function order(a,b){return rank(a)-rank(b)||added(b).localeCompare(added(a))||String(a.title).localeCompare(String(b.title),undefined,{numeric:true});}
 function groups(rows,track,{scope='all',lesson='',difficulty='',query='',type='lesson_exam'}={}){
  const aliases={graph:'figures',graphs:'figures',diagram:'figures',diagrams:'figures',mcq:'multiple choice','word problem':'applications','word problems':'applications',grid:'numerical response','grid in':'numerical response',fitb:'numerical response',reading:'reading passages'};
  const needle=aliases[clean(query)]||clean(query),out=new Map();
  // Reuse immutable lookup work within this render; never cache live exam,
  // attempt, permission or completion state between renders.
  let names;const getNames=()=>names||(names=lessonNames(track));
  for(const e of rows){
   if(e.track_id&&e.track_id!==track||e.assessment_type!==type)continue;
   const c=entries.get(e.id),d=details.get(e.id);if((c&&c.track_id!==track)||(d&&d.track_id!==track))continue;
   const name=lessonFor(e,track,getNames);
   if(scope==='available'&&!available(e)||scope==='progress'&&!live(e)||scope==='completed'&&!done(e)||scope==='new'&&!isNew(e)||lesson&&name!==lesson)continue;
   if(difficulty&&c?.difficulty_label!==difficulty)continue;
   if(needle&&!clean([name,e.title,c?.difficulty_label,...(c?.formats||[]),...(d?.topics||[])].join(' ')).includes(needle))continue;
   if(!out.has(name))out.set(name,[]);out.get(name).push(e);
  }
  return [...out].sort(([a],[b])=>a.localeCompare(b)).map(([lesson,exams])=>({lesson,exams:exams.sort(order)}));
 }
 function units(exams){
  const out=new Map();
  for(const e of exams){const key=details.get(e.id)?.same_set_as||e.id;if(!out.has(key))out.set(key,[]);out.get(key).push(e);}
  return [...out.values()].map(versions=>{
   // A completed copy takes precedence over an untouched copy of identical questions.
   versions.sort((a,b)=>Number(live(b))-Number(live(a))||Number(done(b))-Number(done(a))||order(a,b));
   return {exam:versions[0],copies:versions.slice(1)};
  }).sort((a,b)=>order(a.exam,b.exam));
 }
 function reset(type){const track=ST.track?.id;if(state.track!==track||state.type!==type)Object.assign(state,{track,type,scope:'all',lesson:'',difficulty:'',query:'',pages:{},expanded:new Set()});}
 function row(exam){
  const c=entries.get(exam.id),tags=[...(c?.difficulty_label?[c.difficulty_label]:[]),...(c?.formats||[])];
  return `<article class="lesson-set">${assessmentRow(exam)}${tags.length?`<p class="lesson-formats">${tags.map(esc).join(' · ')}</p>`:''}</article>`;
 }
 function unitRow(unit){return `${row(unit.exam)}${unit.copies.length?`<details class="lesson-duplicate-sets" ${unit.copies.some(live)?'open':''}><summary>Same questions · ${unit.copies.length} other assignment${unit.copies.length===1?'':'s'}</summary><p class="dash-note">These assignments contain the same questions. Saved attempts remain separate.</p>${unit.copies.map(row).join('')}</details>`:''}`;}
 function results(){
  const items=groups(DASH.exams,ST.track?.id,state),count=items.reduce((n,g)=>n+g.exams.length,0),kind=state.type==='quiz'?'quizzes':'lesson exams';
  return `<p class="dash-note" role="status">${items.length} topic${items.length===1?'':'s'} · ${count} assignment${count===1?'':'s'}</p>${items.length?items.map((g,i)=>{
   const sets=units(g.exams),inProgress=sets.filter(u=>live(u.exam)),primary=inProgress.length?inProgress:sets.slice(0,1),extra=sets.filter(u=>!primary.includes(u));
   const page=Math.min(state.pages[g.lesson]||0,Math.max(0,Math.ceil(extra.length/PAGE_SIZE)-1)),offset=page*PAGE_SIZE,key='topic-'+i,moreKey='more-'+i;
   const open=state.lesson||state.query||inProgress.length||state.expanded.has(key),moreOpen=state.query||state.expanded.has(moreKey);
   const completed=g.exams.filter(done).length;
   return `<details class="lesson-exam-group" data-expand="${key}" ${open?'open':''}><summary><span>${esc(g.lesson)}</span><span class="lesson-set-count">${sets.length} set${sets.length===1?'':'s'}${inProgress.length?` · ${inProgress.length} in progress`:completed?` · ${completed} completed`:''}</span></summary><div class="lesson-exam-body"><p class="lesson-suggestion">${inProgress.length?'Continue your work':available(primary[0].exam)&&!done(primary[0].exam)?'Suggested next set':done(primary[0].exam)?'Review or practise again':'Assigned set'}</p>${primary.map(unitRow).join('')}${extra.length?`<details class="lesson-older-sets" data-expand="${moreKey}" ${moreOpen?'open':''}><summary>More sets (${extra.length})</summary>${extra.slice(offset,offset+PAGE_SIZE).map(unitRow).join('')}${extra.length>PAGE_SIZE?`<div class="lesson-set-pages"><span class="dash-note">${offset+1}–${Math.min(offset+PAGE_SIZE,extra.length)} of ${extra.length} more sets</span><button class="btn-ghost" data-lesson-page="${esc(g.lesson)}" data-page="${page-1}" ${page===0?'disabled':''}>Previous</button><button class="btn-ghost" data-lesson-page="${esc(g.lesson)}" data-page="${page+1}" ${offset+PAGE_SIZE>=extra.length?'disabled':''}>Next</button></div>`:''}</details>`:''}</div></details>`;
  }).join(''):`<div class="dash-empty">No ${kind} match these filters. <button class="btn-ghost" id="lessonExamReset">Show all available sets</button></div>`}`;
 }
 function panel(type){
  reset(type);const all=groups(DASH.exams,ST.track?.id,{type}),quiz=type==='quiz';
  return `<section class="dash-panel lesson-exam-library"><div class="dash-heading"><h2>${quiz?'Quizzes':'Lesson exams'}</h2></div><p class="dash-note">Choose a topic for a suggested set. Open More sets for earlier and additional practice. ${quiz?'Your quiz attempts and reviews stay available.':'Choose timed practice or no time limit. Every attempt stays saved; difficulty labels are estimates.'}</p><div class="lesson-exam-tools"><label for="lessonExamScope">Progress<select id="lessonExamScope">${[['all','All sets'],['available','Ready to take'],['progress','In progress'],['completed','Completed']].map(([v,label])=>`<option value="${v}" ${state.scope===v?'selected':''}>${label}</option>`).join('')}</select></label><label for="lessonExamLesson">Topic<select id="lessonExamLesson"><option value="">All topics</option>${all.map(g=>`<option value="${esc(g.lesson)}" ${state.lesson===g.lesson?'selected':''}>${esc(g.lesson)}</option>`).join('')}</select></label>${quiz?'':`<label for="lessonExamDifficulty">Difficulty<select id="lessonExamDifficulty"><option value="">All difficulties</option>${['Easy','Medium','Medium–Hard','Hard','Mixed'].map(d=>`<option value="${esc(d)}" ${state.difficulty===d?'selected':''}>${esc(d)}</option>`).join('')}</select></label>`}<label class="lesson-search" for="lessonExamSearch">Find a set<input type="search" id="lessonExamSearch" value="${esc(state.query)}" placeholder="Topic, title or question type…"></label></div><div id="lessonExamResults">${results()}</div></section>`;
 }
 function wire(){
  const root=document.getElementById('lessonExamResults');if(!root)return;
  // Batch typing into one render. A late callback must never repaint a new
  // course/view, or replace the control the student is currently using.
  function refresh(){
   clearTimeout(searchTimer);
   if(!root.isConnected||document.getElementById('lessonExamResults')!==root)return;
   root.innerHTML=results();math(root);wireDashboard();
  }
  for(const [id,key] of [['lessonExamScope','scope'],['lessonExamLesson','lesson'],['lessonExamDifficulty','difficulty'],['lessonExamSearch','query']]){
   const input=document.getElementById(id);if(!input)continue;
   const update=()=>{state[key]=input.value;state.pages={};state.expanded.clear();};
   if(id==='lessonExamSearch'){
    input.oninput=event=>{
     clearTimeout(searchTimer);update();
     if(event?.isComposing)return;
     if(!input.value){refresh();return;}
     searchTimer=setTimeout(refresh,150);
    };
    input.oncompositionend=()=>input.oninput();
    input.onkeydown=event=>{if(event.key==='Enter'&&!event.isComposing){event.preventDefault();update();refresh();}};
   }else input.onchange=()=>{update();refresh();};
  }
  root.querySelectorAll('[data-lesson-page]').forEach(button=>button.onclick=()=>{
   state.expanded=new Set([...root.querySelectorAll('details[data-expand][open]')].map(d=>d.dataset.expand));
   const name=button.dataset.lessonPage;state.pages[name]=Number(button.dataset.page);refresh();
   const next=[...root.querySelectorAll('[data-lesson-page]')].find(b=>b.dataset.lessonPage===name&&!b.disabled);next?.focus();
  });
  const resetButton=document.getElementById('lessonExamReset');if(resetButton)resetButton.onclick=()=>{Object.assign(state,{scope:'all',lesson:'',difficulty:'',query:'',pages:{},expanded:new Set()});paintDashboardContent();};
 }
 window.LessonExamLibrary={catalog,isNew,lessonFor,groups,units};
 if(typeof assessmentSection==='function'&&typeof DASH!=='undefined'){
  const section=assessmentSection;assessmentSection=function(type){return ['lesson_exam','quiz'].includes(type)?panel(type):section.apply(this,arguments);};
  const oldWire=wireDashboard;wireDashboard=function(){const result=oldWire.apply(this,arguments);wire();return result;};
  const paint=paintDashboard;paintDashboard=function(){const result=paint.apply(this,arguments),button=document.querySelector('.student-tabs [data-view="lesson_exam"]');if(button){button.hidden=false;button.textContent='Lesson exams';}return result;};
 }
})();
