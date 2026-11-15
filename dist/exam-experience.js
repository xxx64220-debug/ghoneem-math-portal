/* Exam presentation and optional annotations. Answers still use the original autosave/submission path. */
(() => {
 'use strict';
 const byId=id=>document.getElementById(id),answered=q=>q.response!=null&&q.response!=='';
 const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 let current=null,annotations={},dirty=new Map(),writing=null,activeQuestion=null,started=0,revision=0,announced=new Set();
 const key=id=>'ghoneem-exam-tools:'+id;
 function readLocal(id){try{return JSON.parse(localStorage.getItem(key(id))||'{}');}catch{return {};}}
 function store(){if(!current)return;try{localStorage.setItem(key(current.attempt.id),JSON.stringify(annotations));}catch{}}
 function row(id){return annotations[id]||(annotations[id]={eliminated:[],seconds:0,flagged:false});}
 function valid(item,q){return {eliminated:Array.isArray(item?.eliminated)?item.eliminated.filter(v=>v!==q.response&&(q.choices||[]).some(c=>c.key===v)):[],seconds:Math.min(86400,Math.max(0,Number(item?.seconds)||0)),flagged:item?.flagged===true};}
 function change(id){revision++;dirty.set(id,revision);store();}
 function accrue(){
  if(!current||!activeQuestion||!started)return;
  const elapsed=Math.max(0,(performance.now()-started)/1000);started=0;
  row(activeQuestion).seconds=Math.min(86400,row(activeQuestion).seconds+elapsed);change(activeQuestion);
 }
 function question(id){
  if(!current)return;
  if(activeQuestion!==id){accrue();activeQuestion=id;}
  if(!started&&document.visibilityState!=='hidden'&&document.body.classList.contains('in-exam')&&!document.querySelector('dialog.exam-dialog[open]')&&!(innerWidth<900&&!byId('satCalculatorPanel').hidden))started=performance.now();
  const jump=byId('questionJump'),length=current.questions.length;
  if(jump){jump.textContent=`Q ${ST.idx+1} / ${length} ▾`;jump.setAttribute('aria-label',`Question ${ST.idx+1} of ${length}, open question list`);}
  byId('nextBtn').textContent=ST.idx===length-1?'Review & submit':'Next';byId('nextBtn').disabled=false;
 }
 async function flush(){
  if(writing)return writing;
  if(!current||!dirty.size||ST.accessBlocked||navigator.onLine===false)return;
  const run=current;
  writing=(async()=>{try{
   while(current===run&&dirty.size&&!ST.accessBlocked&&navigator.onLine!==false){
    const items=[...dirty],payload=items.map(([id])=>({attempt_id:run.attempt.id,question_id:id,eliminated:[...row(id).eliminated],seconds:Math.round(row(id).seconds),flagged:ST.flags.has(id)}));
    const result=await sb.from('attempt_annotations').upsert(payload,{onConflict:'attempt_id,question_id'});
    if(result.error||current!==run)break;
    items.forEach(([id,version])=>{if(dirty.get(id)===version)dirty.delete(id);});
   }
  }catch{/* Local annotations remain available after refresh. Answers have their own queue. */}})();
  try{await writing;}finally{writing=null;}
 }
 async function start(run,transfer=false){
  accrue();current=run;activeQuestion=null;started=0;annotations={};dirty=new Map();revision=0;announced=new Set();
  const local=transfer?{}:readLocal(run.attempt.id);
  run.questions.forEach(q=>{annotations[q.id]=valid(local[q.id],q);if(local[q.id])dirty.set(q.id,++revision);});
  byId('referenceBtn').hidden=run.exam.track_id!=='sat';
  byId('offlineNotice').hidden=navigator.onLine!==false;
  try{
   const {data,error}=await sb.from('attempt_annotations').select('question_id,eliminated,seconds,flagged').eq('attempt_id',run.attempt.id);
   if(current!==run||error)return;
   for(const item of data||[]){const q=run.questions.find(q=>q.id===item.question_id);if(!q)continue;
    const localRow=row(q.id);localRow.seconds=Math.max(localRow.seconds,Number(item.seconds)||0);
    if(!dirty.has(q.id)){annotations[q.id]=valid({...item,seconds:localRow.seconds},q);item.flagged?ST.flags.add(q.id):ST.flags.delete(q.id);}
   }
   store();persistExamFlags();renderQ();renderPalette();
  }catch{/* Core examination is independent of annotation availability. */}
 }
 function stop(){accrue();void flush();current=null;activeQuestion=null;started=0;document.body.classList.remove('answer-keyboard');document.querySelectorAll('dialog.exam-dialog[open]').forEach(d=>d.close());}
 function eliminate(id,option){
  if(!current)return;const q=current.questions.find(q=>q.id===id);if(!q||(q.choices||[]).every(c=>c.key!==option))return;
  const value=row(id),had=value.eliminated.includes(option);value.eliminated=had?value.eliminated.filter(k=>k!==option):[...value.eliminated,option];
  change(id);if(!had&&q.response===option)save(q,'');renderQ();void flush();
 }
 function select(id,option){const value=row(id);if(value.eliminated.includes(option)){value.eliminated=value.eliminated.filter(k=>k!==option);change(id);renderQ();void flush();}}
 function flag(id){row(id).flagged=ST.flags.has(id);change(id);void flush();}
 function dialog(id,label,body){
  accrue();document.querySelectorAll('dialog.exam-dialog[open]').forEach(d=>d.close());
  let d=byId(id);if(!d){d=document.createElement('dialog');d.id=id;d.className='exam-dialog';document.body.append(d);}
  d.setAttribute('aria-labelledby',id+'Title');d.innerHTML=`<div class="exam-dialog-heading"><h2 id="${id}Title">${escape(label)}</h2><button type="button" class="btn-ghost" data-close aria-label="Close ${escape(label)}">✕</button></div>${body}`;
  d.querySelector('[data-close]').onclick=()=>d.close();d.addEventListener('click',event=>{if(event.target===d){const b=d.getBoundingClientRect();if(event.clientX<b.left||event.clientX>b.right||event.clientY<b.top||event.clientY>b.bottom)d.close();}},{once:true});
  d.addEventListener('close',()=>{if(current&&activeQuestion)question(activeQuestion);},{once:true});
  d.showModal();return d;
 }
 function counts(){const qs=ST.run?.questions||[];return {total:qs.length,done:qs.filter(answered).length,flags:qs.filter(q=>ST.flags.has(q.id)).length};}
 function grid(){return `<p class="exam-legend"><span>● Answered</span><span>○ Unanswered</span><span class="legend-flag">${FLAG_ICON}Flagged</span></p><div class="exam-question-grid">${ST.run.questions.map((q,i)=>`<button type="button" class="pal ${answered(q)?'answered':''} ${ST.flags.has(q.id)?'flagged':''} ${ST.idx===i?'current':''}" data-question="${i}" aria-label="Question ${i+1}, ${answered(q)?'answered':'unanswered'}${ST.flags.has(q.id)?', flagged':''}">${i+1}${ST.flags.has(q.id)?FLAG_ICON:''}</button>`).join('')}</div>`;}
 function wireGrid(d){d.querySelectorAll('[data-question]').forEach(b=>b.onclick=()=>{captureInput();ST.idx=Number(b.dataset.question);d.close();renderQ();renderPalette();byId('qcard').tabIndex=-1;byId('qcard').focus({preventScroll:true});window.scrollTo(0,0);});}
 function review(){
  if(!ST.run)return;captureInput();const c=counts();
  const d=dialog('examReviewSheet','Review & submit',`<p id="examReviewCounts">${c.done} answered · ${c.total-c.done} unanswered · ${c.flags} flagged</p>${grid()}<div class="exam-review-actions"><button class="btn-secondary" data-review-blank ${c.done===c.total?'disabled':''}>Review unanswered</button><button class="btn-secondary" data-review-flag ${!c.flags?'disabled':''}>Review flagged</button></div><p class="dash-note">Submitting ends this attempt. You cannot change your answers afterwards.</p><button class="btn exam-submit" id="submitConfirmed">Submit now</button>`);
  wireGrid(d);
  const go=predicate=>{const i=ST.run.questions.findIndex(predicate);if(i>=0)d.querySelector(`[data-question="${i}"]`).click();};
  d.querySelector('[data-review-blank]').onclick=()=>go(q=>!answered(q));d.querySelector('[data-review-flag]').onclick=()=>go(q=>ST.flags.has(q.id));
  byId('submitConfirmed').onclick=()=>{d.close();void submitExam(false,true);};
 }
 const reference=`<p class="dash-note">SAT Math reference · r = radius, h = perpendicular height, b = base, l = length, w = width.</p><div class="sat-reference-grid">${[
  ['Circle','A = πr²<br>C = 2πr'],['Rectangle','A = lw'],['Triangle','A = ½bh'],['Right triangle','a² + b² = c²<br>c is the hypotenuse'],['30°–60°–90° triangle','Opposite 30°: x<br>Opposite 60°: x√3<br>Hypotenuse: 2x'],['45°–45°–90° triangle','Legs: s, s<br>Hypotenuse: s√2'],['Rectangular prism','V = lwh'],['Cylinder','V = πr²h'],['Sphere','V = ⁴⁄₃πr³'],['Cone','V = ⅓πr²h'],['Rectangular pyramid','V = ⅓lwh']
 ].map(([name,formula])=>`<section><h3>${name}</h3><p>${formula}</p></section>`).join('')}</div><p>Full circle: 360° = 2π radians.<br>Triangle interior angles total 180°.</p><p class="dash-note">Formula reference for practice. <a href="https://satsuite.collegeboard.org/media/pdf/sat-student-guide.pdf" target="_blank" rel="noopener noreferrer">College Board SAT guide ↗</a></p>`;
 function openReference(){if(ST.run?.exam.track_id==='sat')dialog('examReferenceSheet','Reference',reference);}
 function menu(){
  const d=dialog('examMoreSheet','Exam options','<button class="btn" id="menuReview">Review & submit</button><button class="btn-secondary" id="menuLeave">Save & return to course</button><p class="dash-note">For a timed exam, the clock continues while you are away.</p><details><summary>Keyboard shortcuts</summary><dl class="exam-shortcuts"><dt>← / →</dt><dd>Previous / next</dd><dt>F</dt><dd>Flag question</dd><dt>A–D</dt><dd>Choose an option</dd><dt>R</dt><dd>SAT reference</dd></dl><p class="dash-note">Shortcuts pause while you type or use a dialog.</p></details>');
  byId('menuReview').onclick=()=>{d.close();review();};
  byId('menuLeave').onclick=async()=>{captureInput();const b=byId('menuLeave');b.disabled=true;if(!await flushAnswers()){b.disabled=false;return;}accrue();void flush();d.close();if(typeof stopExamActivity==='function')stopExamActivity();clearInterval(ST.timer);stop();ST.run=null;await openTrack(ST.track);};
 }
 async function timing(attemptId,questions,host){
  if(!host||!attemptId)return;
  let rows=readLocal(attemptId);
  try{const {data,error}=await sb.from('attempt_annotations').select('question_id,seconds').eq('attempt_id',attemptId);if(!error)for(const item of data||[])rows[item.question_id]={seconds:Math.max(Number(rows[item.question_id]?.seconds)||0,Number(item.seconds)||0)};}catch{}
  if(!host.isConnected)return;
  const items=(questions||[]).map((q,i)=>({i,seconds:Number(rows[q.id||q.question_id]?.seconds)||0})).filter(x=>x.seconds>0),total=items.reduce((sum,x)=>sum+x.seconds,0);
  if(!items.length)return;
  host.innerHTML=`<details class="timing-summary"><summary>Time per question</summary><p>Average active time: ${Math.round(total/items.length)} s across ${items.length} recorded questions.${ST.track?.id==='sat'?' SAT target pace: about 95 s.':''}</p><h3>Slowest questions</h3><ol>${items.sort((a,b)=>b.seconds-a.seconds).slice(0,3).map(x=>`<li>Question ${x.i+1}: ${Math.round(x.seconds)} s</li>`).join('')}</ol><p class="dash-note">Counts time on a visible question. Hidden tabs, reference sheets and the mobile calculator are paused. Time is a practice guide and does not affect your score.</p></details>`;
 }
 function timer(left){for(const threshold of [300,60])if(left<=threshold&&!announced.has(threshold)){announced.add(threshold);byId('examAnnouncements').textContent=threshold===300?'5 minutes remaining.':'1 minute remaining.';}}
 byId('satCalculatorToggle')?.addEventListener('click',()=>{accrue();if(current&&activeQuestion)question(activeQuestion);});
 byId('satCalculatorClose')?.addEventListener('click',()=>{if(current&&activeQuestion)question(activeQuestion);});
 byId('questionJump')?.addEventListener('click',()=>{captureInput();wireGrid(dialog('examNavigator','Questions',grid()));});
 byId('examMore')?.addEventListener('click',menu);byId('referenceBtn')?.addEventListener('click',openReference);
 document.addEventListener('keydown',event=>{
  if(!ST.run||!document.body.classList.contains('in-exam')||submitting||event.altKey||event.ctrlKey||event.metaKey||event.repeat||event.target.closest('input,textarea,select,[contenteditable="true"],dialog')||document.querySelector('dialog[open]'))return;
  const k=event.key.toLowerCase();if(k==='arrowleft'){event.preventDefault();byId('prevBtn').click();}else if(k==='arrowright'){event.preventDefault();byId('nextBtn').click();}else if(k==='f'){event.preventDefault();byId('flagBtn').click();}else if(k==='r'){event.preventDefault();openReference();}else if(/^[a-d]$/.test(k)){const choice=byId('qcard').querySelector(`[data-k="${k.toUpperCase()}"]`);if(choice){event.preventDefault();choice.click();}}
 });
 document.addEventListener('focusin',e=>{if(e.target.id==='gin')document.body.classList.add('answer-keyboard');});
 document.addEventListener('focusout',e=>{if(e.target.id==='gin')document.body.classList.remove('answer-keyboard');});
 document.addEventListener('visibilitychange',()=>{accrue();if(document.visibilityState!=='hidden'&&activeQuestion)question(activeQuestion);void flush();});
 window.addEventListener('pagehide',()=>{accrue();store();});
 window.addEventListener('offline',()=>{if(ST.run){byId('offlineNotice').hidden=false;byId('saving').textContent='Saved on this device';}});
 window.addEventListener('online',()=>{if(ST.run){byId('offlineNotice').hidden=true;void flush();}});
 setInterval(()=>{if(current){accrue();question(activeQuestion);void flush();}},15000);
 window.ExamExperience={start,stop,question,flush,accrue,review,eliminate,select,flag,timer,timing,isEliminated:(id,k)=>row(id).eliminated.includes(k)};
})();
