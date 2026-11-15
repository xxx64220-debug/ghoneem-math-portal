/* Read-only teaching workspace. Existing RLS and RPC permissions remain authoritative. */
(function(root){
 'use strict';
 const day=value=>value?new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(value)):'';
 const within=(value,from,to)=>!!value&&(!from||day(value)>=from)&&(!to||day(value)<=to);
 const scored=r=>r.score!=null&&Number.isFinite(Number(r.score))&&Number(r.total)>0;
 function latest(rows){const m=new Map();for(const r of [...rows].sort((a,b)=>String(a.submitted_at||'').localeCompare(String(b.submitted_at||''))||String(a.attempt_id).localeCompare(String(b.attempt_id))))m.set(r.user_id+'|'+r.exam_id,r);return [...m.values()];}
 function summarize(students,rows){const ids=new Set(students.map(s=>s.user_id)),r=rows.filter(x=>ids.has(x.user_id)),l=latest(r),valid=l.filter(scored),participants=new Set(r.map(x=>x.user_id));return {rows:r,latest:l,participants:participants.size,missing:students.length-participants.size,graded:valid.length,mean:valid.length?valid.reduce((s,x)=>s+100*Number(x.score)/Number(x.total),0)/valid.length:null,awaiting:l.filter(x=>x.score==null).length};}
 function priorities(students){const m=new Map();for(const s of students){const seen=new Set();for(const l of s.lessons||[]){if(seen.has(l.lesson)||l.classified===false||['Unclassified questions','Mixed / untagged'].includes(l.lesson)||(!Number.isFinite(Number(l.seen))||Number(l.seen)<3)||l.correct==null||!Number.isFinite(Number(l.correct))||Number(l.correct)<0||Number(l.correct)>Number(l.seen)||l.percent==null||!Number.isFinite(Number(l.percent))||Number(l.percent)<0||Number(l.percent)>=80)continue;seen.add(l.lesson);const v=m.get(l.lesson)||{lesson:l.lesson,students:0,seen:0,correct:0};v.students++;v.seen+=Number(l.seen);v.correct+=Number(l.correct);m.set(l.lesson,v);}}return [...m.values()].map(x=>({...x,percent:100*x.correct/x.seen})).sort((a,b)=>b.students-a.students||a.percent-b.percent||a.lesson.localeCompare(b.lesson)).slice(0,2);}
 async function pages(make,current=()=>true){const rows=[];for(let n=0;;n+=500){if(!current())throw Error('Navigation changed');const {data,error}=await make().range(n,n+499);if(error)throw error;if(!Array.isArray(data))throw Error('Incomplete report');rows.push(...data);if(data.length<500)return rows;}}
 const api={day,within,scored,latest,summarize,priorities,pages};if(typeof module==='object'&&module.exports)module.exports=api;root.TeachingDashboard=api;
 if(typeof document==='undefined'||typeof ST==='undefined')return;
 let request=0,filters={track:'',group:'',student:'',exam:'',from:'',to:''};
 const h=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const pct=n=>n==null?'Unavailable':Number(n).toFixed(1)+'%';
 const time=n=>n==null||!Number.isFinite(Number(n))?'Unavailable':Math.floor(Number(n)/60)+'m '+Number(n)%60+'s';
 const table=(heads,rows)=>'<div class="td-scroll"><table><thead><tr>'+heads.map(x=>'<th>'+h(x)+'</th>').join('')+'</tr></thead><tbody>'+rows.join('')+'</tbody></table></div>';
 const tr=items=>'<tr>'+items.map(x=>'<td>'+x+'</td>').join('')+'</tr>';
 const select=(id,label,options,value)=>'<label>'+label+'<select id="td-'+id+'" aria-label="'+h(label)+'">'+options.map(([v,t])=>'<option value="'+h(v)+'" '+(v===value?'selected':'')+'>'+h(t)+'</option>').join('')+'</select></label>';
 const navigate=view=>{ST.view=view;render();};
 async function dashboard(){
  const token=++request,host=document.getElementById('view'),current=()=>request===token&&ST.view==='teachingDashboard'&&document.getElementById('view')===host;
  syncAdminNavigation();host.classList.remove('device-panel');
  if(!ST.me||!['admin','instructor'].includes(ST.me.role)){host.textContent='Staff access required.';return;}
  const tracks=(ST.tracks||[]).filter(t=>['sat','est','est2','act2','sat_eng','est_eng'].includes(t.id));
  const track=tracks.some(t=>t.id===ST.track)?ST.track:tracks[0]?.id;
  if(!track){host.textContent='No teaching access to this course.';return;}
  ST.track=track;if(document.getElementById('trackSel'))document.getElementById('trackSel').value=track;if(filters.track!==track)filters={track,group:'',student:'',exam:'',from:'',to:''};
  host.innerHTML='<p role="status">Loading teaching evidence…</p>';
  try{
   const [diagnosis,groups,members,exams,results,roster]=await Promise.all([
    sb.rpc('staff_diagnosis',{p_track:track}).then(r=>{if(r.error)throw r.error;if(r.data?.track_id!==track||!Array.isArray(r.data.students))throw Error('Incomplete diagnosis');return r.data;}),
    pages(()=>q('groups').eq('track_id',track).order('id'),current),pages(()=>q('group_members').order('group_id').order('user_id'),current),
    pages(()=>q('exams').eq('track_id',track).order('id'),current),pages(()=>q('results_feed').eq('track_id',track).order('submitted_at').order('attempt_id'),current),
    pages(()=>q('roster').eq('role','student').eq('is_test',false).order('user_id'),current)
   ]);if(!current())return;
   const allowed=new Set(roster.map(s=>s.user_id));const students=diagnosis.students.filter(s=>allowed.has(s.user_id)&&!s.is_test);
   let daily=[],dailyError=false;
   try{daily=await pages(()=>sb.from('daily_progress').select('user_id,track_id,day,quiz_group_id,group_scope,quiz_completed_at,quiz_score').eq('track_id',track).order('day').order('user_id').order('group_scope'),current);}catch(e){dailyError=true;}if(!current())return;
   const groupIds=id=>new Set(members.filter(m=>m.group_id===id).map(m=>m.user_id));
   const opts=()=>{const ids=filters.group?groupIds(filters.group):null;return students.filter(s=>!ids||ids.has(s.user_id));};
   function paint(){
    if(!current())return;
    const cohort=opts();if(!cohort.some(s=>s.user_id===filters.student))filters.student='';
    const selected=cohort.filter(s=>!filters.student||s.user_id===filters.student),ids=new Set(selected.map(s=>s.user_id));
    const filtered=results.filter(r=>(!filters.exam||r.exam_id===filters.exam)&&within(r.submitted_at,filters.from,filters.to));const summary=summarize(selected,filtered);
    const d=daily.filter(r=>ids.has(r.user_id)&&(!filters.group||r.quiz_group_id===filters.group)&&(!filters.from||r.day>=filters.from)&&(!filters.to||r.day<=filters.to));
    const done=d.filter(x=>x.quiz_completed_at),completed=new Set(done.map(x=>x.user_id));
    host.innerHTML='<div class="td-dashboard"><div class="head"><div><p class="hint">Instructor workspace · read only</p><h2>Teaching dashboard</h2></div><button class="btn-sm" id="td-refresh">Refresh</button></div><p>Scores, participation and the next lesson — using existing portal records.</p><div class="td-filters">'+
     select('track','Course',tracks.map(t=>[t.id,t.name]),track)+select('group','Group',[['','All permitted students'],...groups.map(g=>[g.id,g.name])],filters.group)+select('student','Student',[['','Whole selection'],...cohort.map(s=>[s.user_id,s.full_name])],filters.student)+select('exam','Examination',[['','All exams'],...exams.map(e=>[e.id,e.title])],filters.exam)+
     '<label>From (Cairo)<input id="td-from" type="date" value="'+h(filters.from)+'"></label><label>Through (Cairo)<input id="td-to" type="date" value="'+h(filters.to)+'"></label></div><p id="td-validation" role="alert"></p><div class="control-actions"><button class="btn-sm" id="td-est">EST I preparation → 11 Dec 2026</button><button class="btn-sm" id="td-alex">Find Alex Tuesday assessments</button><button class="btn-sm" id="td-clear">Clear filters</button></div>'+
     '<p class="hint">Current group membership defines cohorts; historical membership is unavailable. No completed record is not an incorrect answer or proof of absence. Exam filters apply to exam scores and timeline; Daily Quiz uses group, student and date filters independently.</p><div class="td-cards">'+
     [['Students',selected.length],['Completed exam participants',summary.participants+' / '+selected.length],['No completed exam record',summary.missing],['Mean latest score',pct(summary.mean)],['Awaiting grading',summary.awaiting]].map(([l,v])=>'<article class="card"><span>'+h(l)+'</span><strong>'+h(v)+'</strong></article>').join('')+'</div><p class="hint">Mean uses the latest submitted result per student per exam within these dates ('+summary.graded+' scored results). Retakes remain in the timeline. Mixed exams are descriptive, not a fair ranking.</p>'+
     '<section class="card td-section"><h3>Participation by student</h3>'+table(['Student','Completed attempts','Latest filtered score','Recorded exam time','Status'],selected.map(s=>{const r=summary.rows.filter(x=>x.user_id===s.user_id).sort((a,b)=>String(b.submitted_at).localeCompare(String(a.submitted_at))),a=r[0],known=r.filter(x=>x.time_used!=null);return tr([h(s.full_name),r.length,a?(scored(a)?h(a.score+'/'+a.total):'Awaiting grading'):'—',known.length?time(known.reduce((n,x)=>n+Number(x.time_used),0))+(known.length<r.length?' (partial)':''):'Unavailable',a?h(a.status):'No completed record']);}))+ '<p class="hint">Whole-attempt time only. Per-question time and Daily Quiz duration are unavailable; timestamps are not time-on-task.</p></section>'+
     '<section class="card td-section"><h3>Group comparisons</h3><p class="hint">Select one examination for comparable scores. Small samples and overlapping memberships can distort comparisons. Student selection does not restrict this comparison.</p>'+table(['Group','Current members','Participants','Mean latest score'],groups.map(g=>{const gi=groupIds(g.id),ss=students.filter(s=>gi.has(s.user_id)),v=summarize(ss,filtered);return tr([h(g.name),ss.length,v.participants,pct(v.mean)+(v.graded<5?' · small sample':'')]);}))+'</section>'+
     '<section class="card td-section"><h3>Daily Quiz participation</h3>'+ (dailyError?'<p role="alert">Daily Quiz history unavailable. Open Daily quizzes to use the existing report.</p>':'<p>'+completed.size+' / '+selected.length+' students have a completed quiz in this date range; '+done.length+' completed quiz records. '+(selected.length-completed.size)+' have no completed record. Missing days are not zero scores.</p>'+table(['Student','Date (Cairo)','Group','Score','State'],d.sort((a,b)=>b.day.localeCompare(a.day)).map(r=>tr([h(students.find(s=>s.user_id===r.user_id)?.full_name),h(r.day),h(groups.find(g=>g.id===r.quiz_group_id)?.name||'Earlier course quiz'),r.quiz_completed_at&&r.quiz_score!=null?h(r.quiz_score+'/5'):'—',r.quiz_completed_at?'Completed':'Opened / incomplete']))))+'<button class="btn-sm" data-td-nav="quizAdmin">Open Daily quizzes and wrong-answer reporting</button></section>'+
     '<section class="card td-section"><h3>Topic accuracy & next lesson</h3><div id="td-evidence"><p role="status">Loading topic evidence…</p></div><p><b>Calculator allowed:</b> all suggested SAT Math and EST I practice and retests.</p><div class="control-actions"><button class="btn-sm" data-td-nav="formulasAdmin">Reference lessons</button><button class="btn-sm" data-td-nav="revisionAdmin">Final Revision practice</button><button class="btn-sm" data-td-nav="finalsDiagnosisAdmin">Diagnosis & group planning</button><button class="btn-sm" data-td-nav="exams">Exams & assignments</button><a class="btn-sm" href="/study-plan.html?'+h(new URLSearchParams({track,group:filters.group,student:filters.student}).toString())+'">Assign daily objectives</a></div></section>'+
     '<section class="card td-section"><h3>Progress timeline</h3><p class="hint">Every completed attempt is preserved. Compare repeated attempts on the same examination; changing exam difficulty can change scores.</p>'+table(['Date (Cairo)','Student','Examination','Score','Time','Review'],[...summary.rows].sort((a,b)=>String(b.submitted_at).localeCompare(String(a.submitted_at))).map(r=>tr([h(day(r.submitted_at)),h(r.full_name),h(r.exam),scored(r)?h(r.score+'/'+r.total)+' · '+pct(100*r.score/r.total):'Awaiting grading',time(r.time_used),'<button class="btn-sm" data-td-review="'+h(r.attempt_id)+'">Wrong / unanswered</button>'])))+'<div id="td-review" aria-live="polite"></div></section></div>';
    const weekly=document.createElement('section');weekly.className='card td-section';host.querySelector('.td-filters').after(weekly);window.WeeklyReport?.mount({host:weekly,track,groups:filters.group?groups.filter(g=>g.id===filters.group):groups,members,students,exams,results,daily});
    document.getElementById('td-refresh').onclick=()=>render();
    for(const k of ['group','student','exam','from','to'])document.getElementById('td-'+k).onchange=e=>{const next={...filters,[k]:e.target.value};if(next.from&&next.to&&next.from>next.to){document.getElementById('td-validation').textContent='The start date must be before the end date.';return;}filters=next;paint();};
    document.getElementById('td-track').onchange=e=>{ST.track=e.target.value;render();};
    document.getElementById('td-clear').onclick=()=>{filters={track,group:'',student:'',exam:'',from:'',to:''};paint();};
    document.getElementById('td-est').onclick=()=>{if(track!=='est'){ST.track='est';filters={track:'est',group:'',student:'',exam:'',from:'2026-11-01',to:'2026-12-11'};render();}else{filters.from='2026-11-01';filters.to='2026-12-11';paint();}};
    document.getElementById('td-alex').onclick=()=>{const gs=groups.filter(g=>/alex/i.test(g.name));if(track!=='est'||gs.length!==1){document.getElementById('td-validation').textContent='Choose EST I and the Alex group from the group selector.';return;}filters.group=gs[0].id;filters.student='';const es=exams.filter(e=>/alex.*tuesday.*algebra/i.test(e.title)).sort((a,b)=>String(b.opens_at||b.created_at||'').localeCompare(String(a.opens_at||a.created_at||'')));filters.exam=es[0]?.id||'';paint();document.getElementById('td-validation').textContent='Alex Tuesday algebra: 10 questions, 20 minutes; regular new-start window 1:10–1:30 PM Cairo. Check the selected exam’s actual assignment window in Exams.';};
    host.querySelectorAll('[data-td-nav]').forEach(b=>b.onclick=()=>navigate(b.dataset.tdNav));
    const evidence=document.getElementById('td-evidence');loadEvidence(selected,evidence);
    host.querySelectorAll('[data-td-review]').forEach(b=>b.onclick=()=>review(b.dataset.tdReview,document.getElementById('td-review')));
   }
   async function loadEvidence(selected,target){
    const scope={...filters};let evidence=selected,note='Overall diagnosis: latest reviewed result per distinct question. This section is all-history; exam/date filters do not relabel overall evidence.';
    try{if(scope.exam&&selected.length){
      const active=selected.filter(s=>s.practice_open!==false);const {data,error}=active.length?await sb.rpc('staff_group_exam_evidence',{p_exam:scope.exam,p_students:active.map(s=>s.user_id)}):{data:{exam_id:scope.exam,track_id:track,students:[]}};if(error)throw error;
      if(data?.exam_id!==scope.exam||data.track_id!==track||!Array.isArray(data.students))throw Error('Incomplete exam evidence');
      evidence=selected.map(s=>{const row=data.students.find(r=>r.user_id===s.user_id);return {...s,lessons:row?.state==='available'&&within(row.attempt?.submitted_at,scope.from,scope.to)?row.lessons:[],evidenceState:s.practice_open===false?'History-only account: exam diagnosis unavailable':!row?'Missing evidence':row.state==='available'&&!within(row.attempt?.submitted_at,scope.from,scope.to)?'Latest attempt outside date range':row.state};});
      note='Selected examination: existing diagnosis uses the latest scored attempt overall, included only if within your dates. Older filtered attempts remain in the timeline; locked, unavailable and ungraded evidence never becomes zero accuracy.';
     }
     if(!current()||!target.isConnected)return;
     const pp=priorities(evidence);
     target.innerHTML='<p class="hint">'+note+'</p>'+table(['Student','Topic','Correct / seen','Accuracy','Evidence'],evidence.flatMap(s=>(s.lessons?.length?s.lessons:[{}]).map(l=>tr([h(s.full_name),h(l.lesson||'—'),l.seen!=null?h(l.correct+'/'+l.seen):'—',pct(l.percent),h(s.evidenceState||((l.seen||0)<3?'Insufficient evidence':'Reviewed distinct questions'))]))))+
      '<h4>Two practice priorities</h4>'+(pp.length?'<ol>'+pp.map(p=>'<li><b>'+h(p.lesson)+'</b> — '+pct(p.percent)+' across '+p.seen+' scored questions from '+p.students+' student(s). Review one worked example, then 6–8 varied questions; inspect the missed steps.</li>').join('')+'</ol>':'<p>Insufficient weak-topic evidence. Run a short diagnostic before prescribing a topic.</p>')+(pp.length===1?'<p>Second priority: gather more evidence; no second weakness is supported.</p>':'')+
      '<h4>Targeted retest suggestion</h4><p>'+(pp.length?'Use 3 fresh questions per evidenced priority ('+pp.length*3+' total), 10–15 minutes, calculator allowed. Review incorrect and unanswered responses separately, then revisit the topic if fewer than 2 of 3 are correct. Choose or build the matching retest in Exams & assignments.':'Use a short mixed diagnostic, calculator allowed, then revisit this view.')+'</p><p class="hint">Suggestions only; no assessment is created, assigned or changed.</p>'+
      '<h4>Recurring mistakes · overall evidence</h4>'+table(['Student','Active repeat-error questions'],selected.map(s=>tr([h(s.full_name),h(s.repeat_questions??'Unavailable')])) )+'<p class="hint">Repeat-error counts come from the existing Mistake Notebook and are not date-filtered. Concept, calculation, reading and calculator causes need teacher review; the dashboard does not guess them.</p>';
    }catch(e){if(current()&&target.isConnected)target.innerHTML='<p role="alert">Topic evidence unavailable. No fallback evidence has been substituted. Refresh to retry.</p>';}
   }
   async function review(id,target){
    const r=results.find(x=>x.attempt_id===id);if(!r)return;
    target.innerHTML='<p role="status">Loading recorded answers…</p>';const marker=target.dataset.attempt=id;
    const valid=()=>current()&&target.isConnected&&target.dataset.attempt===marker;
    try{
     const attempts=await pages(()=>sb.from('attempts').select('id,review_unlocks_at').eq('id',id).order('id'),valid),a=attempts[0],exam=exams.find(e=>e.id===r.exam_id);
     if(!a||!exam||exam.review_policy!=='full_review'||!a.review_unlocks_at||new Date(a.review_unlocks_at)>new Date())throw Error('Review is locked or unavailable.');
     const [rr,aa]=await Promise.all([pages(()=>q('attempt_results').eq('attempt_id',id).order('question_id'),valid),pages(()=>q('attempt_answers').eq('attempt_id',id).order('question_id'),valid)]);
     const missed=rr.filter(x=>x.is_correct===false&&(exam.question_ids||[]).includes(x.question_id));const qs=[],keys=[];
     for(let i=0;i<missed.length;i+=50){const ids=missed.slice(i,i+50).map(x=>x.question_id);const [qq,kk]=await Promise.all([pages(()=>q('questions').in('id',ids).eq('track_id',track).order('id'),valid),pages(()=>q('question_keys').in('question_id',ids).order('question_id'),valid)]);qs.push(...qq);keys.push(...kk);}
     if(!valid())return;target.innerHTML='<h4>'+h(r.full_name)+' · '+h(r.exam)+'</h4>'+table(['Topic / question','Recorded response','Outcome'],missed.filter(x=>keys.some(k=>k.question_id===x.question_id&&!k.correct?.void)).map(x=>{const question=qs.find(q=>q.id===x.question_id),answer=aa.find(a=>a.question_id===x.question_id)?.response;return tr([h(question?.assets?.curriculum_lesson||question?.topic||'Unclassified')+'<p>'+h(question?.stem||x.question_id)+'</p>'+(question&&typeof figure==='function'?figure(question.assets):''),h(answer==null||answer===''?'No saved answer':typeof answer==='string'?answer:JSON.stringify(answer)),answer==null||answer===''?'Unanswered':'Incorrect']);}))+'<p class="hint">Stored correctness only; excluded questions omitted. No per-question timing is recorded.</p>';if(typeof math==='function')math(target);
    }catch(e){if(valid())target.innerHTML='<p role="alert">'+h(e.message||'Review unavailable. Refresh to retry.')+'</p>';}
   }
   paint();
  }catch(e){if(current())host.innerHTML='<p role="alert">Teaching dashboard could not load. '+h(e.message||'Please retry.')+'</p><button class="btn-sm" id="td-retry">Retry</button>';document.getElementById('td-retry')?.addEventListener('click',()=>render());}
 }
 const previous=render;render=async function(){if(ST.view==='teachingDashboard')return dashboard();request++;return previous.apply(this,arguments);};
 const nav=document.querySelector('#tabs .wrap');if(nav){const b=document.createElement('button');b.className='tab';b.dataset.v='teachingDashboard';b.textContent='Teaching dashboard';b.onclick=()=>navigate('teachingDashboard');nav.prepend(b);}
 const menu=document.getElementById('adminSection');if(menu){const o=document.createElement('option');o.value='teachingDashboard';o.textContent='Teaching dashboard';menu.prepend(o);}
})(typeof globalThis!=='undefined'?globalThis:this);
