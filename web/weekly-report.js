/* On-demand last-seven-days report. Read-only and scoped by the existing instructor policies. */
(function(root){
 'use strict';
 const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 function summarize({students,members,group,attempts,results,assignments,exams,questions,answers,daily,from,to}){
  const ids=new Set(members.filter(m=>m.group_id===group.id).map(m=>m.user_id)),cohort=students.filter(s=>ids.has(s.user_id)&&!s.is_test);
  const recent=attempts.filter(a=>cohort.some(s=>s.user_id===a.user_id)&&a.started_at>=from&&a.started_at<=to),active=new Set(recent.map(a=>a.user_id));
  daily.filter(d=>ids.has(d.user_id)&&d.quiz_completed_at>=from&&d.quiz_completed_at<=to).forEach(d=>active.add(d.user_id));
  const inactive=cohort.filter(s=>!active.has(s.user_id)),behind=[];
  for(const s of cohort){const missing=assignments.filter(a=>(a.group_id===group.id||a.user_id===s.user_id)&&a.close_at>=from&&a.close_at<=to&&exams.some(e=>e.id===a.exam_id&&e.is_published)&&!results.some(r=>r.user_id===s.user_id&&r.exam_id===a.exam_id&&r.submitted_at>=(a.open_at||from)&&r.submitted_at<=to));if(missing.length)behind.push({name:s.full_name,count:missing.length});}
  const recentIds=new Set(recent.filter(a=>a.status!=='in_progress'&&a.review_unlocks_at&&a.review_unlocks_at<=to&&exams.some(e=>e.id===a.exam_id&&e.review_policy==='full_review')).map(a=>a.id));
  const topics=new Map();for(const result of answers.filter(a=>recentIds.has(a.attempt_id)&&a.is_correct===false)){const q=questions.find(q=>q.id===result.question_id);if(!q||q.assets?.release_hold_reason)continue;const topic=q.assets?.curriculum_lesson||q.topic||'Unclassified';topics.set(topic,(topics.get(topic)||0)+1);}
  return {group:group.name,students:cohort.length,active:cohort.length-inactive.length,inactive:inactive.map(s=>s.full_name),behind,topics:[...topics].sort((a,b)=>b[1]-a[1]).slice(0,3)};
 }
 function text(report,from,to){return `${report.group} · ${new Intl.DateTimeFormat('en-GB',{timeZone:'Africa/Cairo',day:'numeric',month:'short'}).format(new Date(from))} to ${new Intl.DateTimeFormat('en-GB',{timeZone:'Africa/Cairo',day:'numeric',month:'short'}).format(new Date(to))}\n${report.active}/${report.students} students recorded exam or Daily Quiz activity.\nNo exam / Daily Quiz activity: ${report.inactive.join(', ')||'None'}.\nPast-due assessments without a submitted result: ${report.behind.map(x=>x.name+' ('+x.count+')').join(', ')||'None'}.\nMost-missed released exam topics: ${report.topics.map(([t,n])=>t+' ('+n+' incorrect or unanswered)').join('; ')||'No released evidence'}.\nBundle and offline study activity is not included. Current group membership is used. Missing work is not a zero score.`;}
 root.WeeklyReport={summarize,text};if(typeof module==='object'&&module.exports)module.exports=root.WeeklyReport;
 if(typeof document==='undefined')return;
 root.WeeklyReport.mount=function(context){
  const {host,track,groups,members,students,exams,results,daily}=context;if(!host)return;
  host.innerHTML='<h3>Weekly group reports</h3><p class="hint">The last 7 days: exam and Daily Quiz activity, past-due work and missed topics from released exams. Bundle and offline practice are not included.</p><button class="btn-sm" id="weeklyLoad">Prepare group reports</button><div id="weeklyOutput" aria-live="polite"></div>';
  const button=host.querySelector('button');button.onclick=async()=>{
   const output=host.querySelector('#weeklyOutput'),to=new Date().toISOString(),from=new Date(Date.now()-7*86400000).toISOString();button.disabled=true;output.textContent='Loading weekly evidence…';
   const current=()=>host.isConnected&&ST.track===track;
   const pages=async make=>{const all=[];for(let n=0;;n+=500){if(!current())throw Error('Course changed');const {data,error}=await make().range(n,n+499);if(error)throw error;all.push(...(data||[]));if(!data||data.length<500)return all;}};
   try{
    const [attempts,assignments]=await Promise.all([pages(()=>sb.from('attempts').select('id,user_id,exam_id,status,started_at,review_unlocks_at').gte('started_at',from).order('id')),pages(()=>sb.from('assignments').select('id,exam_id,group_id,user_id,open_at,close_at').gte('close_at',from).lte('close_at',to).order('id'))]);
    const own=attempts.filter(a=>exams.some(e=>e.id===a.exam_id)),released=own.filter(a=>a.status!=='in_progress'&&a.review_unlocks_at&&a.review_unlocks_at<=to&&exams.some(e=>e.id===a.exam_id&&e.review_policy==='full_review')),answers=[],questions=[];
    for(let i=0;i<released.length;i+=50)answers.push(...await pages(()=>sb.from('attempt_results').select('attempt_id,question_id,is_correct').in('attempt_id',released.slice(i,i+50).map(a=>a.id)).eq('is_correct',false).order('attempt_id').order('question_id')));
    const qids=[...new Set(answers.map(a=>a.question_id))];for(let i=0;i<qids.length;i+=100)questions.push(...await pages(()=>sb.from('questions').select('id,topic,assets').eq('track_id',track).in('id',qids.slice(i,i+100)).order('id')));
    if(!current())return;
    output.innerHTML=groups.length?groups.map((group,i)=>{const report=summarize({students,members,group,attempts:own,results,assignments,exams,questions,answers,daily,from,to});return `<article class="card"><h4>${escape(group.name)}</h4><pre style="white-space:pre-wrap;font:inherit;line-height:1.7" id="weeklyText${i}">${escape(text(report,from,to))}</pre><button class="btn-sm" data-weekly-copy="${i}">Copy for WhatsApp</button></article>`;}).join(''):'<p>No permitted groups for this course.</p>';
    output.querySelectorAll('[data-weekly-copy]').forEach(b=>b.onclick=async()=>{const value=output.querySelector('#weeklyText'+b.dataset.weeklyCopy).textContent;try{await navigator.clipboard.writeText(value);b.textContent='Copied';}catch{const box=document.createElement('textarea');box.value=value;box.setAttribute('aria-label','Weekly report to copy');b.after(box);box.focus();box.select();b.textContent='Select and copy the report';}});
   }catch(error){if(current())output.textContent='Weekly report unavailable. '+(error.message||'Try again.');}finally{button.disabled=false;}
  };
 };
})(typeof globalThis!=='undefined'?globalThis:this);
