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
    '<div class="diagnosis-bottom"><h3>Bottom skills to fix first</h3>'+(bottom.length?bottom.map((x,i)=>'<article class="lesson-card '+esc(x.priority)+'"><div class="lesson-card-top"><h3>'+(i+1)+'. '+esc(x.lesson)+'</h3><span class="priority-label">'+x.percent+'%</span></div><p>'+x.correct+'/'+x.seen+' distinct reviewed questions correct. Repair this skill, then retest with unseen mixed questions.</p><button class="btn-ghost" data-diagnosis-revision="'+esc(x.lesson)+'">Practise this in Final Revision</button></article>').join(''):'<div class="dash-empty">Complete enough reviewed questions to identify reliable bottom skills.</div>')+'</div>'+
    '<div class="diagnosis-legend"><h3>Error codes</h3><p><b>C</b> — Concept &nbsp; <b>A</b> — Algebra/calculation &nbsp; <b>R</b> — Reading &nbsp; <b>D</b> — Calculator &nbsp; <b>T</b> — Timing &nbsp; <b>X</b> — Careless &nbsp; <b>RPT</b> — Repeat mistake</p><p class="dash-note">C/A/R/D/T/X are intentionally teacher-classified after reviewing the work; the portal does not guess a cause from a wrong answer.</p></div>'+
    '<div class="dash-notice"><strong>Final-week rule:</strong> Do not immediately reteach everything missed. Identify the bottom 2–3 skills, repair them, then retest.</div></section>';
 }
 async function loadFinalsRepeats(){
   if(finalsLoading||finalsLoaded)return;finalsLoading=true;
   try{
     const {data,error}=await sb.from('practice_notebook').select('question_id,tries,correct_streak').gte('tries',2).lt('correct_streak',2);
     if(error)throw error;finalsRepeat=(data||[]).length;
   }catch(_){finalsRepeat=null;}
   finally{finalsLoading=false;finalsLoaded=true;if(DASH.view==='finalsDiagnosis')paintDashboardContent();}
 }
 paintDashboard=function(){
   basePaintDashboard();
   if(ST.track?.id!=='est')return;
   const nav=document.querySelector('.student-tabs');if(!nav||nav.querySelector('[data-view="finalsDiagnosis"]'))return;
   const b=document.createElement('button');b.className='student-tab '+(DASH.view==='finalsDiagnosis'?'active':'');b.dataset.view='finalsDiagnosis';b.textContent='Finals diagnosis';
   b.onclick=()=>setDashboardView('finalsDiagnosis');nav.insertBefore(b,nav.firstChild);
 };
 paintDashboardContent=function(){
   if(DASH.view!=='finalsDiagnosis')return basePaintDashboardContent();
   const content=document.getElementById('dashboardContent');if(!content)return;
   content.innerHTML=finalsDiagnosisPanel();wireDashboard();document.querySelectorAll('[data-diagnosis-revision]').forEach(b=>b.onclick=async()=>{const lesson=b.dataset.diagnosisRevision;setDashboardView('revision');if(!REV.data)await refreshRevision();REV.collection='all';REV.level='mixed';REV.lesson=lesson;revisionPaint();});loadFinalsRepeats();
 };
})();
