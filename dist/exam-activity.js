// Best-effort browser activity only. Never blocks answers or changes scores.
let EXAM_ACTIVITY=null;
function activityStore(state){try{sessionStorage.setItem('exam-activity:'+state.id,JSON.stringify(state.queue));}catch{}}
function startExamActivity(run){
 const type=DASH.exams.find(e=>e.id===run.exam.id)?.assessment_type;
 const enabled=['quiz','full_exam'].includes(type)&&run.attempt.deadline_at!=='infinity';
 const notice=document.getElementById('examActivityNotice');
 if(notice){notice.hidden=!enabled;notice.textContent='Exam activity is recorded: switching tabs or apps, or locking your screen, may be reported to your instructor. This does not automatically affect your score.';}
 if(!enabled){EXAM_ACTIVITY=null;return;}
 let queue=[];try{const saved=JSON.parse(sessionStorage.getItem('exam-activity:'+run.attempt.id)||'[]');if(Array.isArray(saved))queue=saved.slice(-200);}catch{}
 EXAM_ACTIVITY={id:run.attempt.id,queue,active:true,hidden:false,sending:false,deadline:new Date(run.attempt.deadline_at).getTime()};
 recordExamActivity('started');if(document.visibilityState==='hidden'){EXAM_ACTIVITY.hidden=true;recordExamActivity('hidden');}
}
function recordExamActivity(kind){
 const state=EXAM_ACTIVITY;if(!state?.active||Date.now()+ST.skew>state.deadline)return;
 if(state.queue.length<200)state.queue.push({id:crypto.randomUUID(),kind,at:new Date(Date.now()+ST.skew).toISOString()});
 activityStore(state);void flushExamActivity(state);
}
async function flushExamActivity(state=EXAM_ACTIVITY){
 if(!state||state.sending||!state.queue.length)return;
 state.sending=true;
 try{
  const events=state.queue.slice(0,20);
  const r=await fn('exam-activity',{method:'POST',body:{action:'events',data:{attempt_id:state.id,events}}});
  if(r.ok){const accepted=new Set(r.json.accepted||[]);state.queue=state.queue.filter(e=>!accepted.has(e.id));activityStore(state);}
  else if(['activity_window_closed','activity_limit_reached','activity_not_enabled','attempt_not_found'].includes(r.json.error)){state.queue=[];activityStore(state);}
 }catch{/* A later visibility/online event or retry can sync the queue. */}
 finally{state.sending=false;}
}
function stopExamActivity(){if(EXAM_ACTIVITY){EXAM_ACTIVITY.active=false;void flushExamActivity();}const notice=document.getElementById('examActivityNotice');if(notice)notice.hidden=true;}
document.addEventListener('visibilitychange',()=>{
 const state=EXAM_ACTIVITY;if(!state?.active||ST.run?.attempt.id!==state.id)return;
 const hidden=document.visibilityState==='hidden';if(hidden===state.hidden)return;
 state.hidden=hidden;recordExamActivity(hidden?'hidden':'visible');
 if(!hidden)void flushExamActivity();
});
window.addEventListener('online',()=>void flushExamActivity());
setInterval(()=>void flushExamActivity(),20000);
