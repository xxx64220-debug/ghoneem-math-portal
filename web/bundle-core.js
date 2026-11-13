(function(root){
 'use strict';
 const countAnswers=b=>b.questions.filter(q=>String(b.answers[q.id]??'').trim()).length;
 function available(rows,settings){return rows.filter(r=>(!settings.section||r.section===settings.section)&&(!settings.topics.length||settings.topics.includes(r.topic))&&(settings.difficulty==='mixed'||r.difficulty===settings.difficulty)).reduce((n,r)=>n+Number(settings.exclude_answered?r.unseen:r.total),0);}
 function recovery(server,local){
  if(!local||server.completed_at)return {kind:'server'};
  const valid=Number.isSafeInteger(local.revision)&&local.revision>=0&&Number.isSafeInteger(local.position)&&local.position>=0&&local.position<server.questions.length&&local.answers&&typeof local.answers==='object'&&!Array.isArray(local.answers)&&Object.entries(local.answers).every(([id,value])=>server.questions.some(q=>q.id===id)&&typeof value==='string'&&value.length<=250);
  if(!valid)return {kind:'invalid'};
  if(local.revision===server.revision)return {kind:'restore',answers:local.answers,position:local.position};
  if(JSON.stringify(local.answers)===JSON.stringify(server.answers)&&local.position===server.position)return {kind:'server'};
  return {kind:'conflict'};
 }
 // Single writer: every request uses the revision returned by the preceding save.
 function writer(send){let pending=Promise.resolve();return job=>{const next=pending.then(()=>send(job));pending=next.catch(()=>{});return next;};}
 const api={countAnswers,available,recovery,writer};
 if(typeof module!=='undefined')module.exports=api;else root.BundleCore=api;
})(typeof window!=='undefined'?window:globalThis);
