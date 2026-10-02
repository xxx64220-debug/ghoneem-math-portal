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
  const api={create};
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
 async function finalsDiagnosisAdmin(){
   if(typeof q!=='function')return;
   const [{data:results,error:rErr},{data:lessons,error:lErr},{data:roster,error:sErr}]=await Promise.all([
     q('results_feed').eq('track_id','est').order('submitted_at',{ascending:false}),
     q('student_by_lesson').eq('track_id','est').order('percent',{ascending:true}),
     q('roster').eq('role','student').order('full_name')
   ]);
   if(rErr||lErr||sErr)throw (rErr||lErr||sErr);
   const enrolled=(roster||[]).filter(s=>String(s.tracks||'').split(', ').includes('est'));
   const latest=new Map();
   for(const x of (results||[])){if(!latest.has(x.user_id))latest.set(x.user_id,x);}
   const byStudent=new Map();
   for(const x of (lessons||[])){if(Number(x.questions_seen)<3)continue;const a=byStudent.get(x.user_id)||[];a.push(x);byStudent.set(x.user_id,a);}
   const rows=enrolled.map(s=>{
     const result=latest.get(s.user_id),skills=(byStudent.get(s.user_id)||[]).sort((a,b)=>Number(a.percent)-Number(b.percent)||Number(b.questions_seen)-Number(a.questions_seen)).slice(0,3);
     const skillText=skills.length?skills.map(x=>escFinal(x.lesson)+' <b>'+x.percent+'%</b>').join('<br>'):'More evidence needed';
     const score=result?(result.score==null?'Awaiting grading':result.score+'/'+result.total+' · '+result.percent+'%'):'No completed EST attempt';
     const pace=result&&result.time_used!=null?Math.floor(result.time_used/60)+'m '+(result.time_used%60)+'s total':'—';
     return '<tr><td><b>'+escFinal(s.full_name)+'</b></td><td>'+score+'</td><td>'+skillText+'</td><td><span class="pill warn">Classify</span><br><span class="hint">C/A/R/D/T/X</span></td><td><span class="hint">Individual question time not reliably tracked</span><br>'+pace+'</td><td><span class="pill">RPT review</span><br><span class="hint">Check Mistake Notebook / repeated patterns</span></td></tr>';
   }).join('');
   document.getElementById('view').innerHTML='<div class="head"><h2>Finals diagnosis</h2><div class="sp"></div><span class="pill">EST I</span></div>'+
    '<div class="msg ok"><b>Final-week workflow:</b> Score → topic accuracy → classify the cause → identify the bottom 2–3 skills → repair → retest. Do not immediately reteach everything missed.</div>'+
    '<div class="card"><h2 style="font-size:18px;margin-bottom:10px">Error-code key</h2><p><b>C</b> — Concept &nbsp; <b>A</b> — Algebra/calculation &nbsp; <b>R</b> — Reading &nbsp; <b>D</b> — Calculator &nbsp; <b>T</b> — Timing &nbsp; <b>X</b> — Careless &nbsp; <b>RPT</b> — Repeat mistake</p><p class="hint" style="margin-top:10px">C/A/R/D/T/X are not guessed automatically. Review the student work and classify the actual cause. Per-question “slow” flags are also not invented because the portal currently stores reliable whole-attempt time, not time-on-question.</p></div>'+
    '<div class="table-wrap"><table><thead><tr><th>Student</th><th>Score</th><th>Bottom 2–3 skills / topic accuracy</th><th>Error type</th><th>Slow questions / pacing</th><th>Repeat errors</th></tr></thead><tbody>'+rows+'</tbody></table></div>'+
    (!rows?'<div class="empty">No EST I students are currently enrolled.</div>':'');
 }
 function install(){
   if(typeof render!=='function'||typeof ST==='undefined')return;
   const oldRender=render;
   render=async function(){if(ST.view==='finalsDiagnosisAdmin'){syncAdminNavigation?.();document.getElementById('view').innerHTML='<p class="hint">Loading finals diagnosis…</p>';try{await finalsDiagnosisAdmin();}catch(e){document.getElementById('view').innerHTML='<div class="msg bad">Could not load finals diagnosis: '+escFinal(e.message||e)+'</div>';}return;}return oldRender();};
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
