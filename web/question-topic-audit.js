/* Import hints are review gates, not an automated mathematical classifier. */
(function(root){
 'use strict';
 const normalized=v=>String(v||'').trim().toLowerCase();
 function audit(questions,bundle={},canonical){
  const label=value=>{const mapped=canonical?.(value);return normalized(mapped&&!/untagged|unclassified/i.test(mapped)?mapped:value);};
  const findings=[];
  questions.forEach((q,i)=>{
   const expected=q.source_bundle_lesson||q.assets?.source_bundle_lesson||bundle.source_bundle_lesson;
   const allowed=q.assets?.source_bundle_lessons||bundle.source_bundle_lessons;
   const topic=q.assets?.curriculum_lesson||q.topic,stem=String(q.stem||'').toLowerCase();
   if(expected&&label(expected)!==label(topic))findings.push({question:i+1,reason:`Topic “${topic||'missing'}” differs from source bundle “${expected}”.`});
   if(Array.isArray(allowed)&&allowed.length&&!allowed.some(x=>label(x)===label(topic)))findings.push({question:i+1,reason:`Topic “${topic||'missing'}” is outside the source bundle lessons.`});
   if(/systems? of/.test(normalized(topic))&&/perpendicular/.test(stem)&&/what is the slope/.test(stem)&&!/(system|intersection|intersect)/.test(stem))findings.push({question:i+1,reason:'Perpendicular-slope question is labelled as a system. Review its lesson.'});
   if(/systems? of/.test(normalized(topic))&&/(sqrt|√)/.test(stem)&&!/(system|intersection|intersect|\by\b)/.test(stem))findings.push({question:i+1,reason:'Single radical equation is labelled as a system. Review its lesson.'});
  });return findings;
 }
 root.QuestionTopicAudit={audit};if(typeof module==='object'&&module.exports)module.exports={audit};
})(typeof globalThis!=='undefined'?globalThis:this);
