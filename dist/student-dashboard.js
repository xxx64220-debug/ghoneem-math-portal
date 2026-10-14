// Student dashboard: progress, assessment categories, complete history and lesson priorities.
const ASSESSMENTS={lesson_exam:'Lesson exams',quiz:'Quizzes',full_exam:'Full exams'};
const PRIORITIES={focus:['Focus first','Review the lesson, then work through another assigned assessment.'],practice:['Keep practising','Revisit mistakes and practise the question types you missed.'],strong:['Strong','Keep this lesson fresh with occasional mixed practice.'],more_evidence:['More practice needed to assess','Complete more questions before relying on a lesson rating.'],not_started:['Not assessed yet','Complete an assigned assessment to see your progress.']};
let DASH={view:'overview',exams:[],history:[],lessons:[],summary:{},historyType:'all',historyPage:0};
let dashboardRequest=0;
const dateText=t=>t?new Date(t).toLocaleDateString(undefined,{day:'numeric',month:'short',year:'numeric'}):'—';
const percentText=v=>v==null?'—':`${v}%`;
async function openTrack(t){
 const request=++dashboardRequest;
 ST.track=t;document.documentElement.style.setProperty('--accent',t.theme?.accent||'#C9A227');
 $('chip').textContent=t.theme?.label||t.id.toUpperCase();$('listTitle').textContent=t.name;
 $('listSub').textContent='Your assessments, progress, and next steps.';
 show('vList');$('examList').innerHTML='<p class="dash-empty" role="status">Loading your progress…</p>';
 try{
  const {ok,json}=await fn('me-tracks',{qs:`?track=${encodeURIComponent(t.id)}`});
  if(request!==dashboardRequest)return;
  if(!ok)throw new Error(friendly(json.error));
  DASH={...DASH,view:'overview',historyPage:0,historyType:'all',exams:json.exams||[],history:json.dashboard?.history||[],lessons:json.dashboard?.lessons||[],summary:json.dashboard?.summary||{}};
  paintDashboard();
 }catch(e){if(request===dashboardRequest){$('examList').innerHTML=`<div class="dash-empty" role="alert">${esc(e.message)}<br><button class="btn" id="retryDashboard">Try again</button></div>`;$('retryDashboard').onclick=()=>openTrack(t);}}
}
function setDashboardView(view){DASH.view=view;DASH.historyPage=0;paintDashboard();}
function paintDashboard(){
 const tabs=[['overview','My progress'],['lesson_exam','Lesson exams'],['quiz','Quizzes'],['full_exam','Full exams'],['history','Exam history'],['focus','Lesson focus']];
 $('examList').innerHTML=`<nav class="student-tabs" aria-label="Student dashboard">${tabs.map(([id,name])=>`<button class="student-tab ${DASH.view===id?'active':''}" data-view="${id}" aria-current="${DASH.view===id?'page':'false'}">${name}${ASSESSMENTS[id]?` <span>${DASH.exams.filter(e=>e.assessment_type===id).length}</span>`:''}</button>`).join('')}</nav><div id="dashboardContent" aria-live="polite"></div>`;
 document.querySelectorAll('[data-view]').forEach(b=>b.onclick=()=>setDashboardView(b.dataset.view));
 const content=$('dashboardContent');
 if(DASH.view==='overview')content.innerHTML=dashboardOverview();
 else if(ASSESSMENTS[DASH.view])content.innerHTML=assessmentSection(DASH.view);
 else if(DASH.view==='history')content.innerHTML=historySection();
 else content.innerHTML=focusSection();
 wireDashboard();
}
function dashboardOverview(){
 const s=DASH.summary,live=DASH.exams.filter(e=>e.last?.status==='in_progress');
 const available=DASH.exams.filter(e=>e.open&&(!e.last||e.retake_available));
 const priorities=DASH.lessons.filter(l=>['focus','practice'].includes(l.priority)).slice(0,3);
 return `<div class="dashboard-stats"><div class="dash-stat"><span>Completed attempts</span><strong>${s.completed||0}</strong></div><div class="dash-stat"><span>Average score</span><strong>${percentText(s.average_percent)}</strong></div><div class="dash-stat"><span>Best score</span><strong>${percentText(s.best_percent)}</strong></div><div class="dash-stat"><span>Lessons to focus on</span><strong>${s.lessons_to_focus||0}</strong></div></div>
 ${live.length?`<section class="dash-panel"><h2>Continue your exam</h2>${live.map(assessmentRow).join('')}</section>`:''}
 <div class="dashboard-columns"><section class="dash-panel"><div class="dash-heading"><h2>Your score trend</h2><button class="dash-link" data-go="history">All results →</button></div>${scoreTrend()}<p class="dash-note">Raw scores as percentages. Different assessments vary in difficulty; retakes are included.</p></section>
 <section class="dash-panel"><div class="dash-heading"><h2>What to work on next</h2><button class="dash-link" data-go="focus">All lessons →</button></div>${priorities.length?priorities.map(l=>lessonCard(l,true)).join(''):`<div class="dash-empty">${!s.completed?'Complete your first assessment to get personal lesson priorities.':DASH.lessons.some(l=>l.priority==='strong')?'Your assessed lessons are looking strong. Keep practising and check the full lesson list.':'More reviewed questions are needed before we can identify your priorities.'}</div>`}</section></div>
 ${s.review_pending?`<p class="dash-notice">${s.review_pending} completed assessment${s.review_pending===1?' has':'s have'} review pending. Their lesson breakdown will appear when your instructor releases the answers.</p>`:''}
 <section class="dash-panel"><h2>Ready to take</h2>${available.length?available.slice(0,5).map(assessmentRow).join(''):'<p class="dash-empty">No new assessments are open right now. You can review your history or check the assessment tabs.</p>'}</section>`;
}
function scoreTrend(){
 const rows=DASH.history.filter(h=>h.percent!=null).slice(0,8).reverse();
 if(!rows.length)return '<div class="dash-empty">Your score trend will appear after your first completed assessment.</div>';
 return `<div class="score-trend" aria-label="Recent assessment scores">${rows.map(h=>`<button class="trend-column" data-review="${h.id}" aria-label="${esc(h.title)}, attempt ${h.attempt_no}, ${h.percent}%"><span class="trend-value">${h.percent}%</span><span class="trend-track"><i style="height:${Math.max(2,Math.min(100,h.percent))}%"></i></span><span class="trend-label">${esc(new Date(h.submitted_at).toLocaleDateString(undefined,{day:'numeric',month:'short'}))}</span></button>`).join('')}</div>`;
}
function assessmentRow(e){
 const a=e.last,live=a?.status==='in_progress',done=a&&!live;
 const label=live?'Resume':done?'Review':'Start';
 const score=done?`<span class="badge done">${a.score == null ? 'Awaiting grading' : a.score+'/'+a.total}</span>`:'';
 return `<div class="exam-row"><div style="flex:1;min-width:170px"><h3>${esc(e.title)}</h3><div class="meta">${e.questions} questions · ${Math.round(e.duration_seconds/60)} min${!e.open&&!live?' · Not open':''}${done?' · Completed':''}</div></div>${score}<button class="btn" ${done?`data-review="${a.id}"`:`data-start="${e.id}"`} ${!done&&!live&&!e.open?'disabled':''}>${label}</button>${done&&e.retake_available&&e.open?`<button class="btn" data-start="${e.id}">Start retake</button>`:''}</div>`;
}
function assessmentSection(type){
 const rows=DASH.exams.filter(e=>e.assessment_type===type);
 return `<section class="dash-panel"><div class="dash-heading"><h2>${ASSESSMENTS[type]}</h2><span class="dash-note">${rows.length} assigned</span></div><p class="dash-note">${type==='lesson_exam'?'Assessments focused on individual lessons.':type==='quiz'?'Short checks of what you have learned.':'Longer papers covering several lessons.'} One attempt per assessment unless your instructor grants a retake.</p>${rows.length?rows.map(assessmentRow).join(''):`<div class="dash-empty">No ${ASSESSMENTS[type].toLowerCase()} are assigned yet.</div>`}</section>`;
}
function historySection(){
 const rows=DASH.history.filter(h=>DASH.historyType==='all'||h.assessment_type===DASH.historyType);
 const pages=Math.max(1,Math.ceil(rows.length/10));DASH.historyPage=Math.min(DASH.historyPage,pages-1);
 const slice=rows.slice(DASH.historyPage*10,DASH.historyPage*10+10);
 return `<section class="dash-panel"><div class="dash-heading"><h2>Exam history</h2><label class="history-filter">Show <select id="historyFilter">${[['all','All assessments'],...Object.entries(ASSESSMENTS)].map(([id,name])=>`<option value="${id}" ${DASH.historyType===id?'selected':''}>${name}</option>`).join('')}</select></label></div><p class="dash-note">Every completed attempt, including retakes and expired exams.</p>${slice.length?`<div class="student-table"><table><thead><tr><th>Assessment</th><th>Type</th><th>Date</th><th>Attempt</th><th>Score</th><th>Time</th><th></th></tr></thead><tbody>${slice.map(h=>`<tr><td><b>${esc(h.title)}</b>${h.status==='expired'?'<span class="history-detail">Time expired</span>':''}</td><td>${ASSESSMENTS[h.assessment_type]||'Lesson exams'}</td><td>${dateText(h.submitted_at)}</td><td>${h.attempt_no}</td><td><b>${h.score == null ? 'Awaiting grading' : h.score+'/'+h.total}</b><span class="history-detail">${percentText(h.percent)}${h.scaled_score!=null?' · scaled '+h.scaled_score:''}</span></td><td>${Math.floor((h.time_used||0)/60)}m ${(h.time_used||0)%60}s</td><td><button class="btn-ghost" data-review="${h.id}">${h.review_open?'Review':'View score'}</button>${!h.review_open?`<span class="history-detail">${h.review_unlocks_at?'Answers open '+dateText(h.review_unlocks_at):'Review pending'}</span>`:''}</td></tr>`).join('')}</tbody></table></div><div class="history-pager"><button class="btn-ghost" id="historyPrev" ${DASH.historyPage===0?'disabled':''}>Previous</button><span>Page ${DASH.historyPage+1} of ${pages} · ${rows.length} attempts</span><button class="btn-ghost" id="historyNext" ${DASH.historyPage>=pages-1?'disabled':''}>Next</button></div>`:'<div class="dash-empty">No completed attempts in this category yet.</div>'}</section>`;
}
function lessonCard(l,compact=false){
 const [label,advice]=PRIORITIES[l.priority]||PRIORITIES.not_started;
 return `<article class="lesson-card ${esc(l.priority)}"><div class="lesson-card-top"><h3>${esc(l.lesson)}</h3><span class="priority-label">${label}</span></div><div class="lesson-score"><strong>${percentText(l.percent)}</strong><span>${l.correct}/${l.seen} distinct questions correct</span></div><div class="lesson-meter" role="meter" aria-label="${esc(l.lesson)} accuracy" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${l.percent||0}"><i style="width:${l.percent||0}%"></i></div>${!compact?`<p>${advice}</p>${l.last_practiced?`<span class="dash-note">Last reviewed practice: ${dateText(l.last_practiced)}</span>`:''}`:''}</article>`;
}
function focusSection(){
 return `<section class="dash-panel"><h2>Lesson focus</h2><p class="dash-note">Based on your latest reviewed result for each question. Repeating the same question does not increase the evidence count.</p><div class="priority-guide"><span><b>Focus first</b> · below 60%</span><span><b>Keep practising</b> · 60–79%</span><span><b>Strong</b> · 80% and above</span></div><p class="dash-note">A rating needs at least 3 distinct reviewed questions. These are practice indicators, not predicted exam scores.</p>${DASH.lessons.length?`<div class="lesson-grid">${DASH.lessons.map(l=>lessonCard(l)).join('')}</div>`:'<div class="dash-empty">Your lesson list will appear when your instructor assigns an assessment.</div>'}</section>`;
}
function wireDashboard(){
 document.querySelectorAll('[data-go]').forEach(b=>b.onclick=()=>setDashboardView(b.dataset.go));
 document.querySelectorAll('[data-review]').forEach(b=>b.onclick=()=>openReview(b.dataset.review));
 document.querySelectorAll('[data-start]').forEach(b=>b.onclick=async()=>{b.disabled=true;try{await startExam(b.dataset.start);}finally{b.disabled=false;}});
 if($('historyFilter'))$('historyFilter').onchange=e=>{DASH.historyType=e.target.value;DASH.historyPage=0;paintDashboard();};
 if($('historyPrev'))$('historyPrev').onclick=()=>{DASH.historyPage--;paintDashboard();};
 if($('historyNext'))$('historyNext').onclick=()=>{DASH.historyPage++;paintDashboard();};
}
