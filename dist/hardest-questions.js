/* Staff report data stays in memory only; RLS remains authoritative. */
(function(root){
  'use strict';
  function create(client,{pageSize=50,timeoutMs=15000,ttlMs=60000,now=Date.now}={}){
    const cache=new Map();
    let active=null;
    const columns='rank,track_id,lesson,question_id,stem,sources,answered_by,got_it_right,got_it_wrong,percent_correct';
    const abortError=()=>Object.assign(new Error('Request cancelled.'),{name:'AbortError'});
    function cancel(){if(active){active.abort();active=null;}}
    function clear(){cancel();cache.clear();}
    function invalidate(scope){for(const key of cache.keys())if(key.startsWith(JSON.stringify([scope.user,scope.track])+':'))cache.delete(key);}
    async function request(scope,offset,size,signal){
      if(signal.aborted)throw abortError();
      let query=client.from('question_difficulty').select(columns);
      if(scope.track)query=query.eq('track_id',scope.track);
      query=query.order('track_id',{ascending:true}).order('rank',{ascending:true}).order('question_id',{ascending:true}).range(offset,offset+size-1).abortSignal(signal);
      let onAbort;
      const cancelled=new Promise((_,reject)=>{onAbort=()=>reject(abortError());signal.addEventListener('abort',onAbort,{once:true});});
      try{
        const {data,error}=await Promise.race([query,cancelled]);
        if(error)throw error;
        if(signal.aborted)throw abortError();
        return data||[];
      }finally{signal.removeEventListener('abort',onAbort);}
    }
    async function run(work){
      cancel();const controller=new AbortController();active=controller;
      let timedOut=false;
      const timer=setTimeout(()=>{timedOut=true;controller.abort();},timeoutMs);
      try{return await work(controller.signal);}
      catch(error){if(timedOut)throw new Error('Loading took too long. Please try again.');throw error;}
      finally{clearTimeout(timer);if(active===controller)active=null;}
    }
    async function page(scope,offset=0,{refresh=false}={}){
      cancel();if(refresh)invalidate(scope);
      const key=JSON.stringify([scope.user,scope.track])+':'+offset;
      const hit=cache.get(key);
      if(hit&&now()-hit.at<ttlMs)return hit.value;
      return run(async signal=>{
        const data=await request(scope,offset,pageSize+1,signal);
        const value={rows:data.slice(0,pageSize),hasMore:data.length>pageSize,offset};
        cache.set(key,{at:now(),value});
        if(cache.size>20)cache.delete(cache.keys().next().value);
        return value;
      });
    }
    async function all(scope,onProgress=()=>{}){
      // Fetch every page only when explicitly exporting. Never export a partial failure.
      return run(async signal=>{
        const rows=[],size=500;
        for(let offset=0;;offset+=size){
          const data=await request(scope,offset,size,signal);rows.push(...data);onProgress(rows.length);
          if(data.length<size)return rows;
        }
      });
    }
    return {page,all,cancel,clear,pageSize};
  }
  const compare=(a,b)=>String(a)<String(b)?-1:String(a)>String(b)?1:0;
  function weakSkills(rows){
    const lessons=new Map();
    for(const row of rows||[]){
      const lesson=String(row.lesson||'').trim(),seen=Number(row.questions_seen),percent=Number(row.percent);
      if((row.track_id&&row.track_id!=='est')||!lesson||['Mixed / untagged','Unclassified questions'].includes(lesson)||row.percent==null||row.percent===''||!Number.isFinite(percent)||percent<0||percent>100||!Number.isFinite(seen)||seen<3)continue;
      const prior=lessons.get(lesson),item={lesson,questions_seen:seen,percent};
      if(!prior||seen>prior.questions_seen||(seen===prior.questions_seen&&percent<prior.percent))lessons.set(lesson,item);
    }
    return [...lessons.values()].sort((a,b)=>a.percent-b.percent||b.questions_seen-a.questions_seen||compare(a.lesson,b.lesson));
  }
  function buildGroupPlan(roster,lessons,selectedIds){
    const selected=new Set(selectedIds||[]),byUser=new Map(),students=new Map();
    for(const row of lessons||[]){const list=byUser.get(row.user_id)||[];list.push(row);byUser.set(row.user_id,list);}
    for(const row of roster||[]){
      if(!selected.has(row.user_id)||(row.role&&row.role!=='student')||!String(row.tracks||'').split(',').map(x=>x.trim()).includes('est'))continue;
      const evidence=weakSkills(byUser.get(row.user_id)),weak=evidence.slice(0,3).filter(x=>x.percent<60);
      students.set(row.user_id,{user_id:row.user_id,name:row.full_name||row.user_id,evidence,weak});
    }
    const ordered=[...students.values()].sort((a,b)=>compare(a.name,b.name)||compare(a.user_id,b.user_id));
    const insufficient=ordered.filter(x=>x.evidence.length<2),reliable=ordered.filter(x=>x.evidence.length>=2);
    function rankLessons(rows){
      const counts=new Map();
      for(const s of rows)for(const x of s.weak){const c=counts.get(x.lesson)||{lesson:x.lesson,students:[],sum:0};c.students.push(s);c.sum+=x.percent;counts.set(x.lesson,c);}
      return [...counts.values()].map(x=>({...x,count:x.students.length,mean:x.sum/x.students.length})).sort((a,b)=>b.count-a.count||a.mean-b.mean||compare(a.lesson,b.lesson));
    }
    let remaining=reliable.filter(x=>x.weak.length);const clusters=[];
    while(clusters.length<3){
      const anchor=rankLessons(remaining).find(x=>x.count>=2);if(!anchor)break;
      const members=anchor.students,ids=new Set(members.map(x=>x.user_id));
      // Every member must share the anchor; a chain of pairwise overlaps is insufficient.
      const shared=rankLessons(members).filter(x=>x.count===members.length).map(x=>x.lesson);
      clusters.push({anchor:anchor.lesson,students:members,shared});remaining=remaining.filter(x=>!ids.has(x.user_id));
    }
    return {students:ordered,common:rankLessons(reliable),clusters,insufficient,individual:remaining,maintenance:reliable.filter(x=>!x.weak.length)};
  }
  const api={create,weakSkills,buildGroupPlan};
  if(typeof module==='object'&&module.exports)module.exports=api;
  else root.HardestQuestions=api;
})(typeof globalThis!=='undefined'?globalThis:this);


/* ================= EST FINALS DIAGNOSIS: ADMIN REPORT =================
   Read-only, additive report built from existing results_feed and
   student_by_lesson views. No grading or exam workflow is changed.
   Error causes remain teacher-classified; per-question duration is not inferred.
====================================================================== */
(function(){
 if(typeof document==='undefined')return;
 function escFinal(v){return String(v??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));}
 async function finalRead(makeQuery){
   const rows=[],size=500;
   for(let offset=0;;offset+=size){
     const {data,error}=await makeQuery().range(offset,offset+size-1);if(error)throw error;
     rows.push(...(data||[]));if(!data||data.length<size)return {data:rows};
   }
 }
 async function installGroupPlanning(enrolled,lessons){
   const panel=document.getElementById('finalsGroup');
   const settled=await Promise.allSettled([
     finalRead(()=>q('groups').eq('track_id','est').order('name').order('id')),
     finalRead(()=>q('group_members').order('group_id').order('user_id')),
     finalRead(()=>q('exams').eq('track_id','est').eq('title','EST I Final Weakness Retest — Oct 2026').order('id')),
     typeof portalControl==='function'?portalControl('revision.list',{track:'est'}):Promise.reject(new Error('Unavailable'))
   ]);
   if(ST.view!=='finalsDiagnosisAdmin'||document.getElementById('finalsGroup')!==panel)return;
   const result=i=>settled[i].status==='fulfilled'&&!settled[i].value?.error?settled[i].value:null;
   const groupData=result(0),memberData=result(1),examData=result(2),revision=result(3);
   const groups=(memberData?groupData?.data||[]:[]).filter(x=>x.track_id==='est'),members=memberData?.data||[];
   const rosterIds=new Set(enrolled.map(x=>x.user_id));
   const groupIds=id=>[...new Set(members.filter(x=>x.group_id===id&&rosterIds.has(x.user_id)).map(x=>x.user_id))];
   const seven=groups.filter(g=>groupIds(g.id).length===7);
   const defaultGroup=seven.length===1?seven[0].id:'';
   let selected=new Set(defaultGroup?groupIds(defaultGroup):enrolled.length===7?enrolled.map(x=>x.user_id):[]);
   const retest=(examData?.data||[]).find(x=>x.track_id==='est'&&x.title==='EST I Final Weakness Retest — Oct 2026'&&x.is_published);
   panel.innerHTML='<div class="head"><h2>Group planning</h2><span class="pill">Read only</span></div>'+
     '<div class="control-bar"><div class="field"><label for="finalsClass">Class</label><select id="finalsClass"><option value="">Choose students below</option>'+groups.map(g=>'<option value="'+escFinal(g.id)+'" '+(g.id===defaultGroup?'selected':'')+'>'+escFinal(g.name)+' · '+groupIds(g.id).length+' enrolled students</option>').join('')+'</select></div></div>'+
     (!groupData||!memberData?'<p class="msg">Saved class membership could not be loaded. Choose students below.</p>':'')+
     '<details '+(!selected.size?'open':'')+'><summary>Choose students for this plan</summary><div class="finals-members">'+enrolled.map(s=>'<label><input type="checkbox" data-finals-student="'+escFinal(s.user_id)+'" '+(selected.has(s.user_id)?'checked':'')+'> '+escFinal(s.full_name||s.user_id)+'</label>').join('')+'</div></details>'+
     '<p class="hint">Uses up to three bottom lessons below 60% (the portal’s focus threshold), with at least three scored responses per lesson and two evidenced lessons per student. Historical responses can include retakes; these are not necessarily distinct questions. Shared-lesson clusters are suggestions, not ability labels.</p><div id="finalsGroupPlan" aria-live="polite"></div>';
   const target=document.getElementById('finalsGroupPlan');
   function revisionLink(lesson){
     if(!revision)return '<span class="hint">Final Revision availability could not be checked.</span>';
     if(revision.visible!==true)return '<span class="hint">Final Revision is hidden from students.</span>';
     const count=(revision.items||[]).filter(x=>x.lesson===lesson&&x.active===true&&x.ready===true).length;
     return count?'<button type="button" class="btn-sm" data-finals-revision="'+escFinal(lesson)+'">Final Revision: '+escFinal(lesson)+' ('+count+')</button>':'<span class="hint">No released, ready Final Revision items for '+escFinal(lesson)+'.</span>';
   }
   function retestLink(){
     if(!examData)return '<p class="hint">Weakness retest availability could not be checked.</p>';
     if(!retest)return '<p class="hint">The October weakness retest is not currently published.</p>';
     const count=Array.isArray(retest.question_ids)?retest.question_ids.length:null,minutes=Number(retest.duration_seconds)/60;
     return '<p><button type="button" class="btn-sm" data-finals-retest>View '+escFinal(retest.title)+'</button>'+ (count!=null?' · '+count+' questions':'')+(Number.isFinite(minutes)&&minutes>0?' · '+minutes+' minutes':'')+'</p><p class="hint">After lesson repair, use this mixed retest to check progress. Check existing assignments before asking students to open it.</p>';
   }
   const names=rows=>rows.map(x=>escFinal(x.name)).join(', ');
   const personal=rows=>rows.map(s=>'<li><b>'+escFinal(s.name)+'</b> — '+s.weak.map(x=>escFinal(x.lesson)+' '+x.percent+'%').join('; ')+'</li>').join('');
   function paint(){
     const plan=HardestQuestions.buildGroupPlan(enrolled,lessons,[...selected]);
     if(!plan.students.length){target.innerHTML='<p class="empty">Choose the students in your class to build a plan.</p>';return;}
     target.innerHTML='<p class="msg ok"><b>'+plan.students.length+' students selected</b> · '+plan.clusters.length+' shared-lesson clusters · '+plan.insufficient.length+' need more evidence</p>'+
       '<h3>Most common weak lessons</h3>'+(plan.common.length?'<ol class="finals-common">'+plan.common.map(x=>'<li><b>'+escFinal(x.lesson)+'</b> · '+x.count+'/'+plan.students.length+' selected students · '+Math.round(x.mean)+'% mean accuracy among those students<br><span class="hint">'+names(x.students)+'</span></li>').join('')+'</ol>':'<p class="hint">No reliable focus lessons identified in the selected evidence.</p>')+
       '<h3>Shared-lesson clusters</h3><p class="hint">Highest student count first, then lowest mean accuracy, then lesson name. Each student appears once; every member shares the cluster’s focus lesson. Up to three clusters; fewer when overlap is limited.</p>'+
       '<div class="finals-clusters">'+plan.clusters.map((c,i)=>'<article class="card finals-cluster"><h3>Cluster '+(i+1)+' · '+escFinal(c.anchor)+'</h3><p><b>'+names(c.students)+'</b></p><p>Shared focus: '+c.shared.map(escFinal).join('; ')+'.</p><ul>'+personal(c.students)+'</ul><div class="control-actions">'+c.shared.map(revisionLink).join('')+'</div><p class="hint">Students: Finals diagnosis → Final Revision → choose the named lesson.</p>'+retestLink()+'</article>').join('')+'</div>'+
       (!plan.clusters.length?'<p class="hint">No shared weakness supports a cluster yet. Use individual lesson practice.</p>':'')+
       (plan.individual.length?'<section class="card"><h3>Individual lesson practice</h3><p class="hint">No shared cluster available within the three-cluster limit.</p><ul>'+plan.individual.map(s=>'<li><b>'+escFinal(s.name)+'</b><div class="control-actions">'+s.weak.map(x=>revisionLink(x.lesson)).join('')+'</div></li>').join('')+'</ul>'+retestLink()+'</section>':'')+
       (plan.maintenance.length?'<section class="card"><h3>Maintain and retest</h3><p>'+names(plan.maintenance)+'</p><p class="hint">No evidenced bottom lesson is below 60%. Continue mixed practice.</p>'+retestLink()+'</section>':'')+
       (plan.insufficient.length?'<section class="card finals-insufficient"><h3>More evidence needed</h3><ul>'+plan.insufficient.map(s=>'<li><b>'+escFinal(s.name)+'</b> · '+s.evidence.length+' lessons with enough scored responses'+(s.evidence.length?' · observed: '+s.evidence.map(x=>escFinal(x.lesson)+' '+x.percent+'%').join('; '):'')+'</li>').join('')+'</ul><p class="hint">Keep these students out of weakness clusters until at least two lessons have three scored responses each. Use the existing retest for baseline evidence, then refresh this report.</p>'+retestLink()+'</section>':'');
     target.querySelectorAll('[data-finals-revision]').forEach(b=>b.onclick=async()=>{
       ST.track='est';const track=document.getElementById('trackSel');if(track)track.value='est';ST.view='revisionAdmin';await render();
       const filter=document.getElementById('revisionAdminLesson');if(ST.view==='revisionAdmin'&&filter&&[...filter.options].some(x=>x.value===b.dataset.finalsRevision)){filter.value=b.dataset.finalsRevision;filter.dispatchEvent(new Event('change',{bubbles:true}));}
     });
     target.querySelectorAll('[data-finals-retest]').forEach(b=>b.onclick=async()=>{
       ST.track='est';const track=document.getElementById('trackSel');if(track)track.value='est';ST.view='exams';await render();
       const search=document.getElementById('examSearch');if(ST.view==='exams'&&search){search.value=retest.title;search.dispatchEvent(new Event('input',{bubbles:true}));}
     });
   }
   document.getElementById('finalsClass').onchange=event=>{selected=new Set(groupIds(event.target.value));panel.querySelectorAll('[data-finals-student]').forEach(b=>b.checked=selected.has(b.dataset.finalsStudent));paint();};
   panel.querySelectorAll('[data-finals-student]').forEach(b=>b.onchange=()=>{if(b.checked)selected.add(b.dataset.finalsStudent);else selected.delete(b.dataset.finalsStudent);document.getElementById('finalsClass').value='';paint();});
   paint();
 }
 async function finalsDiagnosisAdmin(){
   if(typeof q!=='function')return;
   const [{data:results,error:rErr},{data:lessons,error:lErr},{data:roster,error:sErr}]=await Promise.all([
     finalRead(()=>q('results_feed').eq('track_id','est').order('submitted_at',{ascending:false}).order('attempt_id')),
     finalRead(()=>q('student_by_lesson').eq('track_id','est').order('percent',{ascending:true}).order('user_id').order('lesson')),
     finalRead(()=>q('roster').eq('role','student').order('full_name').order('user_id'))
   ]);
   if(rErr||lErr||sErr)throw (rErr||lErr||sErr);
   if(ST.view!=='finalsDiagnosisAdmin')return;
   const enrolled=(roster||[]).filter(s=>String(s.tracks||'').split(',').map(x=>x.trim()).includes('est'));
   const latest=new Map();
   for(const x of (results||[])){if(!latest.has(x.user_id))latest.set(x.user_id,x);}
   const byStudent=new Map();
   for(const x of (lessons||[])){const a=byStudent.get(x.user_id)||[];a.push(x);byStudent.set(x.user_id,a);}
   for(const [id,items] of byStudent)byStudent.set(id,HardestQuestions.weakSkills(items));
   const rows=enrolled.map(s=>{
     const result=latest.get(s.user_id),skills=(byStudent.get(s.user_id)||[]).sort((a,b)=>Number(a.percent)-Number(b.percent)||Number(b.questions_seen)-Number(a.questions_seen)).slice(0,3);
     const skillText=skills.length?skills.map(x=>escFinal(x.lesson)+' <b>'+x.percent+'%</b>').join('<br>'):'More evidence needed';
     const score=result?(result.score==null?'Awaiting grading':result.score+'/'+result.total+' · '+result.percent+'%'):'No completed EST attempt';
     const pace=result&&result.time_used!=null?Math.floor(result.time_used/60)+'m '+(result.time_used%60)+'s total':'—';
     return '<tr><td><b>'+escFinal(s.full_name)+'</b></td><td>'+score+'</td><td>'+skillText+'</td><td><span class="pill warn">Classify</span><br><span class="hint">C/A/R/D/T/X</span></td><td><span class="hint">Individual question time not reliably tracked</span><br>'+pace+'</td><td><span class="pill">RPT review</span><br><span class="hint">Check Mistake Notebook / repeated patterns</span></td></tr>';
   }).join('');
   document.getElementById('view').innerHTML='<div class="head"><h2>Finals diagnosis</h2><div class="sp"></div><span class="pill">EST I</span><button class="btn-sm" id="finalsDiagnosisCsv">Export CSV</button></div><div class="control-actions"><button type="button" class="btn-sm" id="finalsStudentsView" aria-pressed="true">Student reports</button><button type="button" class="btn-sm" id="finalsGroupView" aria-pressed="false">Group planning</button></div><section id="finalsGroup" class="finals-group" hidden></section><section id="finalsIndividual">'+
    '<div class="msg ok"><b>Final-week workflow:</b> Score → topic accuracy → classify the cause → identify the bottom 2–3 skills → repair → retest. Do not immediately reteach everything missed.</div>'+
    '<div class="card"><h2 style="font-size:18px;margin-bottom:10px">Error-code key</h2><p><b>C</b> — Concept &nbsp; <b>A</b> — Algebra/calculation &nbsp; <b>R</b> — Reading &nbsp; <b>D</b> — Calculator &nbsp; <b>T</b> — Timing &nbsp; <b>X</b> — Careless &nbsp; <b>RPT</b> — Repeat mistake</p><p class="hint" style="margin-top:10px">C/A/R/D/T/X are not guessed automatically. Review the student work and classify the actual cause. Per-question “slow” flags are also not invented because the portal currently stores reliable whole-attempt time, not time-on-question.</p></div>'+
    '<div class="table-wrap"><table><thead><tr><th>Student</th><th>Score</th><th>Bottom 2–3 skills / topic accuracy</th><th>Error type</th><th>Slow questions / pacing</th><th>Repeat errors</th></tr></thead><tbody>'+rows+'</tbody></table></div>'+
    (!rows?'<div class="empty">No EST I students are currently enrolled.</div>':'')+'</section>';
   const groupButton=document.getElementById('finalsGroupView'),studentButton=document.getElementById('finalsStudentsView'),groupPanel=document.getElementById('finalsGroup'),studentPanel=document.getElementById('finalsIndividual');
   let groupLoaded=false;
   if(groupButton&&studentButton&&groupPanel&&studentPanel){
     const toggle=group=>{groupPanel.hidden=!group;studentPanel.hidden=group;groupButton.setAttribute('aria-pressed',String(group));studentButton.setAttribute('aria-pressed',String(!group));};
     studentButton.onclick=()=>toggle(false);
     groupButton.onclick=async()=>{toggle(true);if(groupLoaded)return;groupLoaded=true;groupPanel.innerHTML='<p role="status">Loading group plan…</p>';try{await installGroupPlanning(enrolled,lessons);}catch(_){groupLoaded=false;if(ST.view==='finalsDiagnosisAdmin'&&document.getElementById('finalsGroup')===groupPanel)groupPanel.innerHTML='<p class="msg bad">Could not load group planning. Choose Group planning to retry.</p>';}};
   }
   const exportButton=document.getElementById('finalsDiagnosisCsv');
   exportButton.disabled=!enrolled.length;
   exportButton.onclick=()=>csv(enrolled.map(s=>{
     const result=latest.get(s.user_id);
     const skills=(byStudent.get(s.user_id)||[]).slice(0,3);
     return {
       student:s.full_name,
       latest_score:result?(result.score==null?'Awaiting grading':result.score+'/'+result.total):'No completed EST attempt',
       percent:result?.score!=null?(result.percent??''):'',
       time_seconds:result?.time_used??'',
       bottom_skills:skills.length?skills.map(x=>x.lesson+' '+x.percent+'%').join(' | '):'More evidence needed',
       error_type:'Teacher review: C/A/R/D/T/X',
       pacing:'Individual question time not reliably tracked',
       repeat_errors:'Check Mistake Notebook / repeated patterns'
     };
   }),'est-finals-diagnosis');
 }
 function install(){
   if(typeof render!=='function'||typeof ST==='undefined')return;
   const oldRender=render;
   render=async function(){if(ST.view==='finalsDiagnosisAdmin'){syncAdminNavigation?.();document.getElementById('view').innerHTML='<p class="hint">Loading finals diagnosis…</p>';try{await finalsDiagnosisAdmin();}catch(e){if(ST.view==='finalsDiagnosisAdmin')document.getElementById('view').innerHTML='<div class="msg bad">Could not load finals diagnosis: '+escFinal(e.message||e)+'</div>';}return;}return oldRender();};
   const nav=document.querySelector('nav.tabs .wrap:not(.admin-section-nav)');
   if(nav&&!nav.querySelector('[data-v="finalsDiagnosisAdmin"]')){
     const b=document.createElement('button');b.className='tab';b.dataset.v='finalsDiagnosisAdmin';b.textContent='Finals diagnosis';
     b.onclick=()=>{ST.view='finalsDiagnosisAdmin';document.querySelectorAll('.tab').forEach(x=>x.classList.toggle('on',x===b));const sel=document.getElementById('adminSection');if(sel)sel.value='finalsDiagnosisAdmin';render();};
     const results=nav.querySelector('[data-v="results"]');nav.insertBefore(b,results||null);
   }
   const sel=document.getElementById('adminSection');
   if(sel&&!sel.querySelector('option[value="finalsDiagnosisAdmin"]')){
     const group=[...sel.querySelectorAll('optgroup')].find(x=>x.label==='Students')||sel;
     const o=document.createElement('option');o.value='finalsDiagnosisAdmin';o.textContent='Finals diagnosis';group.appendChild(o);
     sel.addEventListener('change',()=>{if(sel.value==='finalsDiagnosisAdmin'){ST.view='finalsDiagnosisAdmin';document.querySelectorAll('.tab').forEach(x=>x.classList.toggle('on',x.dataset.v==='finalsDiagnosisAdmin'));render();}});
   }
 }
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(install,0));else setTimeout(install,0);
})();
