// Authenticated student feedback. Reports are stored for staff review.
function reportButton(questionId='',screen=''){
 return `<button type="button" class="dash-link report-question" data-report-question="${esc(questionId)}" data-report-screen="${esc(screen)}">${questionId?'Report question':'Report a problem'}</button>`;
}
function openPortalReport(questionId='',screen=''){
 const track=ST.track?.id;if(!track)return;
 let dialog=document.getElementById('portalReport');if(!dialog){dialog=document.createElement('dialog');dialog.id='portalReport';dialog.className='portal-report';document.body.appendChild(dialog);}
 const requestId=crypto.randomUUID();
 dialog.innerHTML=`<form id="portalReportForm"><h2>${questionId?'Report this question':'Report a site problem'}</h2><p>Your message goes to your instructor’s Reports tab.${questionId?' This question is attached automatically.':''}</p><label for="portalReportMessage">What should we check?</label><textarea id="portalReportMessage" minlength="10" maxlength="3000" required placeholder="For example: a missing diagram, an answer that seems wrong, or a button that does not work."></textarea><p id="portalReportStatus" role="status"></p><div class="report-actions"><button class="btn" id="portalReportSend">Send report</button><button type="button" class="btn-ghost" id="portalReportCancel">Cancel</button></div></form>`;
 document.getElementById('portalReportCancel').onclick=()=>dialog.close();
 document.getElementById('portalReportForm').onsubmit=async event=>{
  event.preventDefault();const message=document.getElementById('portalReportMessage').value.trim(),button=document.getElementById('portalReportSend'),status=document.getElementById('portalReportStatus'),input=document.getElementById('portalReportMessage'),cancel=document.getElementById('portalReportCancel');
  if(message.length<10){status.textContent='Please describe the problem in at least 10 characters.';return;}
  button.disabled=true;status.textContent='Sending…';
  try{const {ok,json}=await fn('portal-controls',{method:'POST',body:{action:'report',data:{track,kind:questionId?'question':'functionality',question_id:questionId||null,screen:screen||DASH.view||'portal',message,request_id:requestId}}});
   if(!ok)throw new Error(friendly(json.error));
   status.textContent='Report received. Your instructor can now review it.';input.disabled=true;button.hidden=true;cancel.textContent='Close';
  }catch(error){status.textContent=error.message;button.disabled=false;}
 };
 dialog.showModal();document.getElementById('portalReportMessage').focus();
}
document.addEventListener('click',event=>{
 const button=event.target.closest?.('[data-report-question]');if(button)openPortalReport(button.dataset.reportQuestion,button.dataset.reportScreen);
});


// Use only released review results and explicit lesson metadata.
function finalsExamLessons(items){
 const groups=new Map(),seen=new Set();
 for(const q of items||[]){
  if(q.correct?.void||typeof q.is_correct!=='boolean'||!q.id||seen.has(q.id))continue;
  seen.add(q.id);
  const lesson=String(q.assets?.curriculum_lesson||q.topic||'').trim();
  const key=lesson||'Unclassified questions';
  if(!groups.has(key))groups.set(key,{lesson:key,classified:!!lesson,seen:0,correct:0,missed:0,blank:0});
  const row=groups.get(key);row.seen++;if(q.is_correct)row.correct++;else{row.missed++;if(q.response==null||q.response==='')row.blank++;}
 }
 return [...groups.values()].map(x=>({...x,percent:Math.round(100*x.correct/x.seen)})).sort((a,b)=>b.missed-a.missed||a.percent-b.percent||a.lesson.localeCompare(b.lesson));
}

/* ===================== EST FINALS DIAGNOSIS =====================
   Additive final-week summary. Reuses existing dashboard evidence and does not
   alter attempts, grading, Mistake Notebook, Weak-topic Drill, or Final Revision.
   Per-question time is deliberately not inferred from answered_at because
   revisits make that measurement unreliable.
================================================================ */
(function(){
 if(typeof paintDashboard!=='function'||typeof paintDashboardContent!=='function')return;
 const basePaintDashboard=paintDashboard,basePaintDashboardContent=paintDashboardContent;
 let finalsRepeat=null,finalsLoading=false,finalsLoaded=false;
 let finalsContext=null,finalsTrack=null,examSelected='',examReview=null,examError='',examLoading=false,examRequest=0;
 function syncFinalsContext(){
  if(finalsContext===DASH.history&&finalsTrack===ST.track?.id)return;
  finalsContext=DASH.history;finalsTrack=ST.track?.id;examRequest++;
  finalsRepeat=null;finalsLoaded=false;finalsLoading=false;examSelected='';examReview=null;examError='';examLoading=false;
 }
 function finalsExams(){return (DASH.history||[]).filter(x=>x.assessment_type==='full_exam'||x.assessment_type==='lesson_exam');}
 function finalsExamPanel(){
  const exams=finalsExams(),selected=exams.find(x=>x.id===examSelected);
  let out='<section class="diagnosis-exams"><h3>Study from your exams</h3><p class="dash-note">Choose a completed exam to see which lessons you missed. Each attempt is analysed separately; retakes are not counted as new questions in your overall topic summary.</p>';
  if(!exams.length)return out+'<div class="dash-empty">No completed exams yet. Complete an assigned exam, then return here.</div></section>';
  out+='<div class="student-table"><table><thead><tr><th>Exam</th><th>Attempt</th><th>Score</th><th>Study plan</th></tr></thead><tbody>'+exams.map(e=>'<tr><td><b>'+esc(e.title)+'</b><span class="history-detail">'+esc(typeof dateText==='function'?dateText(e.submitted_at):e.submitted_at||'')+'</span></td><td>'+esc(e.attempt_no||1)+'</td><td>'+(e.score==null?'Awaiting grading':esc(e.score)+'/'+esc(e.total)+(e.percent!=null?' · '+esc(e.percent)+'%':''))+'</td><td><button class="btn-ghost" data-diagnosis-exam="'+esc(e.id)+'" '+(!e.review_open||e.score==null?'disabled':'')+'>'+(e.id===examSelected?'Selected exam':'What should I study?')+'</button>'+(!e.review_open?'<span class="history-detail">'+(e.review_unlocks_at?'Review opens '+esc(typeof dateText==='function'?dateText(e.review_unlocks_at):e.review_unlocks_at):'Review is locked')+'</span>':'')+'</td></tr>').join('')+'</tbody></table></div>';
  if(!selected)return out+'</section>';
  out+='<h3>'+esc(selected.title)+' · Attempt '+esc(selected.attempt_no||1)+'</h3>';
  if(examLoading)return out+'<p role="status">Loading exam study plan…</p></section>';
  if(examError)return out+'<p role="alert">'+esc(examError)+'</p><button class="btn-ghost" data-diagnosis-exam="'+esc(selected.id)+'">Try again</button></section>';
  if(!examReview)return out+'</section>';
  const rows=finalsExamLessons(examReview.items),missed=rows.filter(x=>x.missed>0);
  out+='<p class="dash-notice">'+(missed.length?'Start with the missed lessons below, then retest using unseen questions.':'No mistakes in the available scored questions. Keep these lessons fresh with mixed practice.')+'</p>';
  out+=rows.length?'<div class="lesson-grid">'+rows.map(x=>'<article class="lesson-card '+(x.missed?'focus':'strong')+'"><h3>'+esc(x.lesson)+'</h3><p>'+x.correct+'/'+x.seen+' correct · '+x.percent+'%</p><p>'+x.missed+' missed'+(x.blank?' · '+x.blank+' unanswered':'')+'</p>'+(x.seen<3?'<p class="dash-note">Limited evidence: fewer than 3 questions in this exam.</p>':'')+(x.missed&&x.classified?'<button class="btn-ghost" data-diagnosis-revision="'+esc(x.lesson)+'" '+(DASH.revisionVisible===false?'disabled':'')+'>Study this in Final Revision</button>':'')+(!x.classified?'<p class="dash-note">Lesson metadata is unavailable. Review these questions with your instructor.</p>':'')+'</article>').join('')+'</div>':'<p class="dash-empty">No scored question results are available for this exam.</p>';
  return out+'<p class="dash-note">Excluded or ungraded questions are not used in this study plan.</p><button class="btn-ghost" data-review="'+esc(selected.id)+'">Review this exam</button></section>';
 }
 async function loadFinalsExam(id){
  const entry=finalsExams().find(x=>x.id===id);if(!entry?.review_open||entry.score==null)return;
  const request=++examRequest,track=ST.track?.id,context=DASH.history;
  examSelected=id;examReview=null;examError='';examLoading=true;paintDashboardContent();
  try{
   const {ok,json}=await fn('attempt-review',{qs:'?attempt_id='+encodeURIComponent(id)});
   if(request!==examRequest||track!==ST.track?.id||context!==DASH.history)return;
   if(!ok)throw new Error(typeof friendly==='function'?friendly(json.error):'Could not load this exam. Try again.');
   if(json.exam?.track_id!==track||!json.review_open)throw new Error('This exam review is not available yet.');
   examReview=json;
  }catch(e){if(request===examRequest)examError=e.message||'Could not load this exam. Try again.';}
  finally{if(request===examRequest&&track===ST.track?.id&&context===DASH.history){examLoading=false;if(DASH.view==='finalsDiagnosis')paintDashboardContent();}}
 }

 function finalsBottom(){
   return (DASH.lessons||[]).filter(x=>Number(x.seen)>=3&&x.percent!=null)
     .sort((a,b)=>Number(a.percent)-Number(b.percent)||Number(b.seen)-Number(a.seen)).slice(0,3);
 }
 function finalsLatest(){
   return (DASH.history||[]).find(x=>x.assessment_type==='full_exam'&&x.percent!=null)
     ||(DASH.history||[]).find(x=>x.percent!=null)||null;
 }
 function finalsPacing(latest){
   if(!latest)return '—';
   const exam=(DASH.exams||[]).find(x=>x.title===latest.title);
   if(!exam||!latest.time_used)return 'Recorded at exam level only';
   const used=Math.round(Number(latest.time_used)/60),allowed=Math.round(Number(exam.duration_seconds||0)/60);
   return allowed?used+'m / '+allowed+'m':'Recorded at exam level only';
 }
 function finalsDiagnosisPanel(){
   const latest=finalsLatest(),bottom=finalsBottom();
   const topics=bottom.length?bottom.map(x=>esc(x.lesson)+' '+x.percent+'%').join('<br>'):'More reviewed questions needed';
   const score=latest?(latest.score==null?'Awaiting grading':latest.score+'/'+latest.total+' · '+latest.percent+'%'):'No completed assessment yet';
   const repeats=finalsLoading?'Loading…':finalsRepeat==null?'Open Mistake Notebook for repeat history':finalsRepeat+' active repeat-error question'+(finalsRepeat===1?'':'s');
   return '<section class="dash-panel finals-diagnosis"><div class="dash-heading"><h2>Finals diagnosis</h2><span class="badge">EST I final week</span></div>'+
    '<p class="dash-note">Use this as a decision sheet: diagnose first, then teach only the bottom 2–3 skills. It does not replace Final Revision, Mistake Notebook, or Weak-topic Drill.</p>'+
    '<div class="student-table"><table><thead><tr><th>Score</th><th>Topic accuracy</th><th>Error type</th><th>Slow questions</th><th>Repeat errors</th></tr></thead><tbody><tr>'+
    '<td><b>'+score+'</b><span class="history-detail">'+(latest?esc(latest.title):'Complete a mock first')+'</span></td>'+
    '<td>'+topics+'</td>'+
    '<td><b>Teacher review</b><span class="history-detail">C / A / R / D / T / X</span></td>'+
    '<td><b>Not individually measured</b><span class="history-detail">Whole-attempt pacing: '+finalsPacing(latest)+'</span></td>'+
    '<td><b>'+repeats+'</b><span class="history-detail">RPT = the same question/pattern keeps returning</span></td></tr></tbody></table></div>'+
    '<div class="diagnosis-bottom"><h3>Bottom skills to fix first</h3>'+(bottom.length?bottom.map((x,i)=>'<article class="lesson-card '+esc(x.priority)+'"><div class="lesson-card-top"><h3>'+(i+1)+'. '+esc(x.lesson)+'</h3><span class="priority-label">'+x.percent+'%</span></div><p>'+x.correct+'/'+x.seen+' distinct reviewed questions correct. Repair this skill, then retest with unseen mixed questions.</p><button class="btn-ghost" data-diagnosis-revision="'+esc(x.lesson)+'" '+(DASH.revisionVisible===false?'disabled':'')+'>Practise this in Final Revision</button></article>').join(''):'<div class="dash-empty">Complete enough reviewed questions to identify reliable bottom skills.</div>')+'</div>'+
    finalsExamPanel()+
    '<div class="diagnosis-legend"><h3>Error codes</h3><p><b>C</b> — Concept &nbsp; <b>A</b> — Algebra/calculation &nbsp; <b>R</b> — Reading &nbsp; <b>D</b> — Calculator &nbsp; <b>T</b> — Timing &nbsp; <b>X</b> — Careless &nbsp; <b>RPT</b> — Repeat mistake</p><p class="dash-note">C/A/R/D/T/X are intentionally teacher-classified after reviewing the work; the portal does not guess a cause from a wrong answer.</p></div>'+
    '<div class="dash-notice"><strong>Final-week rule:</strong> Do not immediately reteach everything missed. Identify the bottom 2–3 skills, repair them, then retest.</div></section>';
 }
 async function loadFinalsRepeats(){
   if(finalsLoading||finalsLoaded)return;finalsLoading=true;const context=DASH.history,track=ST.track?.id;
   try{
     const {data,error}=await sb.from('practice_notebook').select('question_id,tries,correct_streak').gte('tries',2).lt('correct_streak',2);
     if(error)throw error;if(context===DASH.history&&track===ST.track?.id)finalsRepeat=(data||[]).length;
   }catch(_){if(context===DASH.history&&track===ST.track?.id)finalsRepeat=null;}
   finally{if(context===DASH.history&&track===ST.track?.id){finalsLoading=false;finalsLoaded=true;if(DASH.view==='finalsDiagnosis')paintDashboardContent();}}
 }
 paintDashboard=function(){
   syncFinalsContext();basePaintDashboard();
   if(ST.track?.id!=='est')return;
   const nav=document.querySelector('.student-tabs');if(!nav||nav.querySelector('[data-view="finalsDiagnosis"]'))return;
   const b=document.createElement('button');b.className='student-tab '+(DASH.view==='finalsDiagnosis'?'active':'');b.dataset.view='finalsDiagnosis';b.textContent='Finals diagnosis';
   b.onclick=()=>setDashboardView('finalsDiagnosis');nav.insertBefore(b,nav.firstChild);
 };
 paintDashboardContent=function(){
   syncFinalsContext();if(DASH.view!=='finalsDiagnosis')return basePaintDashboardContent();
   const content=document.getElementById('dashboardContent');if(!content)return;
   content.innerHTML=finalsDiagnosisPanel();wireDashboard();document.querySelectorAll('[data-diagnosis-revision]').forEach(b=>b.onclick=async()=>{if(DASH.revisionVisible===false)return;const lesson=b.dataset.diagnosisRevision;setDashboardView('revision');if(!REV.data)await refreshRevision();REV.collection='all';REV.level='mixed';REV.lesson=lesson;revisionPaint();});document.querySelectorAll('[data-diagnosis-exam]').forEach(b=>b.onclick=()=>loadFinalsExam(b.dataset.diagnosisExam));loadFinalsRepeats();
 };
})();
