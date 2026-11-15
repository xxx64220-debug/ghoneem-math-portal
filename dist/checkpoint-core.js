/* Read-only checkpoint calculations. Never grade or mutate an attempt here. */
(function (root) {
 'use strict';
 const answered = value => value !== null && value !== undefined && String(value).trim() !== '';
 function summary(attempt, answers, questionIds) {
  const ids = new Set(questionIds || []);
  const count = new Set((answers || []).filter(a => ids.has(a.question_id) && answered(a.response)).map(a => a.question_id)).size;
  const complete = ['submitted','graded','expired'].includes(attempt?.status);
  const reliable = complete && Number.isInteger(attempt.score) && attempt.total === ids.size && attempt.score >= 0 && attempt.score <= count;
  return {answered:count, unanswered:ids.size-count, correct:reliable?attempt.score:null,
   incorrect:reliable?count-attempt.score:null, total:ids.size, reliable, complete};
 }
 function selectModule(review, attemptId) {
  if (review?.full_exam) return (review.modules || []).find(m => m.attempt?.id === attemptId) || null;
  return review?.attempt?.id === attemptId ? review : null;
 }
 function priorities(items) {
  const topics = new Map();
  for (const q of items || []) {
   if (q.diagnosis_eligible !== true || q.correct?.void || !answered(q.response) || typeof q.is_correct !== 'boolean' || !q.topic) continue;
   const t = topics.get(q.topic) || {topic:q.topic, answered:0, incorrect:0};
   t.answered++; if (!q.is_correct) t.incorrect++; topics.set(q.topic,t);
  }
  return [...topics.values()].filter(t => t.incorrect > 0).sort((a,b) => b.incorrect-a.incorrect || b.incorrect/b.answered-a.incorrect/a.answered || a.topic.localeCompare(b.topic)).slice(0,2);
 }
 function workload(otherMinutes, moduleMinutes, correctionMinutes=25, limit=120) {
  const valid = String(otherMinutes).trim() !== '' && Number.isFinite(Number(otherMinutes)) && Number(otherMinutes)>=0
   && Number.isFinite(moduleMinutes) && moduleMinutes>0 && Number.isInteger(correctionMinutes) && correctionMinutes>=5 && correctionMinutes<=60
   && Number.isInteger(limit) && limit>=30 && limit<=120;
  const total = valid ? Number(otherMinutes)+moduleMinutes+correctionMinutes : null;
  return {valid,total,limit,remaining:valid?Math.max(0,limit-total):null,allowed:valid&&total<=limit};
 }
 function validDate(date) {
  return /^\d{4}-\d{2}-\d{2}$/.test(date||'') && !Number.isNaN(Date.parse(date+'T12:00:00Z')) && new Date(date+'T12:00:00Z').toISOString().slice(0,10)===date;
 }
 function addDays(date, days) { const d=new Date(date+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+days);return d.toISOString().slice(0,10); }
 function cairoDate(value=Date.now()) {
  const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date(value));
  const part=name=>parts.find(p=>p.type===name).value;return part('year')+'-'+part('month')+'-'+part('day');
 }
 function linkedAssessments(plan) {
  const links=new Map();
  for(const activity of ['practice','lesson','retest']) {
   if(activity==='practice'&&plan.practice_source==='daily_quiz')continue;
   const id=plan[activity+'_exam_id'];if(!id)continue;
   const link=links.get(id)||{id,activities:[]};link.activities.push(activity);links.set(id,link);
  }
  return [...links.values()];
 }
 function assessmentOptions(plans,attempts,assignments,exams,user,groupIds) {
  const links=new Map(),add=(id,source)=>{if(!id)return;const l=links.get(id)||{id,activities:[],sources:[]};if(!l.sources.includes(source))l.sources.push(source);links.set(id,l);};
  for(const p of plans)for(const l of linkedAssessments(p)){add(l.id,'Study plan');for(const a of l.activities)if(!links.get(l.id).activities.includes(a))links.get(l.id).activities.push(a);}
  for(const a of attempts)if(a.user_id===user)add(a.exam_id,'Recorded attempt');
  for(const a of assignments)if(a.user_id===user||groupIds.includes(a.group_id))add(a.exam_id,'Assigned');
  const known=new Map(exams.map(e=>[e.id,e]));
  return [...links.values()].map(l=>({...l,title:known.get(l.id)?.title||'Assessment metadata unavailable'})).sort((a,b)=>a.title.localeCompare(b.title));
 }
 function dailyQuestionUse(records) {
  const answeredIds=new Set(),exposedIds=new Set();
  for(const row of records||[])for(const [id,response] of Object.entries(row.answers||{})){
   exposedIds.add(id);if(row.quiz_completed_at&&answered(response))answeredIds.add(id);
  }
  return {answeredIds:[...answeredIds],exposedIds:[...exposedIds]};
 }
 // Case-sensitive: x and X, and choice/figure changes, can change the mathematics.
 function stemKey(stem){return String(stem||'').normalize('NFKC').replace(/\s+/g,' ').trim();}
 function bankMatches(selected,bank){const chosen=new Set(selected.map(q=>q.id)),keys=new Set(selected.map(q=>stemKey(q.stem)).filter(Boolean));return bank.filter(q=>!chosen.has(q.id)&&keys.has(stemKey(q.stem))).map(q=>q.id);}
 function audit(ids, questions, recentAnswers, earlierExams) {
  const chosen = new Set(ids), seen = new Set(), duplicates = new Set();
  for (const q of questions) {
   const stem = stemKey(q.stem);
   if (!stem) continue; if (seen.has(stem)) duplicates.add(stem); seen.add(stem);
  }
  return {duplicateIds:ids.length-chosen.size, duplicateStems:duplicates.size,
   recentlyAnswered:new Set(recentAnswers.filter(a=>chosen.has(a.question_id)&&answered(a.response)).map(a=>a.question_id)).size,
   earlierPlanOverlap:new Set(earlierExams.flatMap(e=>e.question_ids||[]).filter(id=>chosen.has(id))).size};
 }
 const api = {answered,summary,selectModule,priorities,workload,audit,validDate,addDays,cairoDate,linkedAssessments,assessmentOptions,dailyQuestionUse,bankMatches};
 if (typeof module === 'object' && module.exports) module.exports=api;
 else root.CheckpointCore=api;
})(typeof window==='undefined'?globalThis:window);
