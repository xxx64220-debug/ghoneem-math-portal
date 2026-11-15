// Present only the current course's server-authorized exam catalog.
window.StudentWork = (() => {
 'use strict';
 let page=0,selection='';
 const live=e=>e.last?.status==='in_progress';
 function locked(e){
  if(e.module_number!==2||!e.exam_set_code||live(e))return false;
  const first=DASH.exams.find(x=>x.exam_set_code===e.exam_set_code&&x.module_number===1);
  return !first?.last||first.last.status==='in_progress';
 }
 function ready(e){return e.content_ready!==false&&!locked(e)&&(live(e)?DASH.access?.practice_open!==false||DASH.access?.can_finish:e.open&&DASH.access?.practice_open!==false);}
 function rows(view){
  const exams=DASH.exams||[];
  return exams.filter(e=>{
   if(DASH.access?.practice_open===false)return view==='assignments'&&DASH.access?.can_finish&&live(e);
   return view==='retakes'?e.assessment_type!=='lesson_exam'&&e.retake_available&&e.last&&!live(e):!e.last||live(e);
  }).sort((a,b)=>Number(live(b))-Number(live(a))||Number(ready(b))-Number(ready(a))||Number(a.assessment_type==='lesson_exam')-Number(b.assessment_type==='lesson_exam')||(a.title||'').localeCompare(b.title||''));
 }
 function shortcuts(){
  return '<div class="student-work-shortcuts" aria-label="Assignments and retakes">'+['assignments','retakes'].map(view=>{
   const items=rows(view),available=items.filter(ready).length,unavailable=view==='retakes'&&DASH.access?.practice_open===false;
   return `<button type="button" class="student-work-shortcut" data-work-view="${view}" ${unavailable?'disabled':''} aria-current="${DASH.view===view&&!DASH.searchTerm?'page':'false'}"><span class="student-work-label">${view==='assignments'?'Assignments':'Retakes'} <b>${available}</b></span><span>${unavailable?'Retakes require active course access':view==='assignments'?`${available} ready to start or resume · ${items.length} pending`:`${available} ready · Instructor-approved attempts`}</span><strong>${view==='assignments'?'View assignments':'View retakes'} →</strong></button>`;
  }).join('')+'</div>';
 }
 function panel(view){
  const key=ST.track?.id+':'+view;if(selection!==key){selection=key;page=0;}
  const items=rows(view),pages=Math.max(1,Math.ceil(items.length/10));page=Math.min(page,pages-1);
  const title=view==='retakes'?'Your retakes':'Your assignments';
  const empty=DASH.access?.practice_open===false?'No active work is available with your current course access.':view==='retakes'?'No retakes have been granted. Repeatable lesson practice is available under Lessons.':'No pending assignments in this course. Completed work is in Exam history.';
  return `<section class="dash-panel student-work-panel"><div class="dash-heading"><h2>${title}</h2><span class="dash-note">${items.length} ${view==='retakes'?'granted':'pending'}</span></div><p class="dash-note">${view==='retakes'?'Retakes approved by your instructor. Start buttons appear when the assessment is open.':'Your unfinished assessments, with work you can resume first. Completed assessments are in Exam history.'}</p>${items.slice(page*10,page*10+10).map(e=>{
   const status=live(e)?'In progress':e.content_ready===false?'Under review':locked(e)?'Complete Module 1 first':!e.open?'Not currently open':view==='retakes'?'Retake available':'Ready to start';
   return `<article class="exam-row"><div class="student-work-info"><h3>${esc(e.title)}</h3><p class="meta">${esc(ASSESSMENTS[e.assessment_type]||'Assessment')} · ${e.questions} questions · ${live(e)&&e.last.untimed?'No time limit':Math.round(e.duration_seconds/60)+' min'}</p><span class="student-work-status">${status}</span></div>${e.assessment_type==='lesson_exam'&&!live(e)&&ready(e)?`<label class="practice-mode">Timer<select data-timer="${esc(e.id)}" aria-label="Timer for ${esc(e.title)}"><option value="untimed">No time limit</option><option value="timed">Timed</option></select></label>`:''}<button class="btn" data-start="${esc(e.id)}" ${ready(e)?'':'disabled'}>${live(e)?'Resume':view==='retakes'?'Start retake':'Start assignment'}</button></article>`;
  }).join('')||`<p class="dash-empty">${empty}</p>`}${pages>1?`<div class="history-pager"><button class="btn-ghost" data-work-page="${page-1}" ${page===0?'disabled':''}>Previous</button><span>Page ${page+1} of ${pages}</span><button class="btn-ghost" data-work-page="${page+1}" ${page+1===pages?'disabled':''}>Next</button></div>`:''}</section>`;
 }
 function wire(){
  document.querySelectorAll('[data-work-view]').forEach(b=>b.onclick=()=>{page=0;setDashboardView(b.dataset.workView);});
  document.querySelectorAll('[data-work-page]').forEach(b=>b.onclick=()=>{page=Number(b.dataset.workPage);paintDashboardContent();const content=document.getElementById('dashboardContent');if(content){content.tabIndex=-1;content.focus({preventScroll:true});content.scrollIntoView?.({block:'start'});}});
 }
 return {rows,ready,shortcuts,panel,wire};
})();
