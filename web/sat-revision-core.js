(function(root){
 'use strict';
 const topics=['Quadratics','Percentages','Linear functions','Systems','Statistics','Circles','Area','Volume','Probability','Functions','Exponents & radicals','Ratios & units','Triangles & trigonometry','Other SAT ideas'];
 const normalize=s=>String(s||'').normalize('NFKC').toLowerCase().replace(/\s+/g,' ').trim();
 function duplicates(items){const groups=new Map();for(const q of items){for(const [type,key] of [['text',normalize(q.stem).length>=30?normalize(q.stem):''],['idea',normalize(q.idea)]]){if(!key)continue;const k=type+':'+key;if(!groups.has(k))groups.set(k,{type,items:[]});groups.get(k).items.push(q);}}return [...groups.values()].filter(g=>g.items.length>1);}
 function validateItems(raw){if(!Array.isArray(raw)||raw.length<1||raw.length>250)throw Error('Use a JSON array with 1–250 question references.');const labels=new Set();return raw.map((q,i)=>{const label=String(q.label||q.number||'').trim(),page=Number(q.page);if(!label||label.length>80||labels.has(label))throw Error('Each question needs a unique label (row '+(i+1)+').');labels.add(label);if(!Number.isInteger(page)||page<1||page>2000)throw Error('Check the PDF page for '+label+'.');const topic=q.topic||'Other SAT ideas',difficulty=q.difficulty||'unclassified';if(!topics.includes(topic)||!['easy','medium','hard','unclassified'].includes(difficulty))throw Error('Check the topic and difficulty for '+label+'.');return {label,page,topic,difficulty,idea:String(q.idea||'').trim(),stem:String(q.stem||''),answer:String(q.answer||''),explanation:String(q.explanation||'')};});}
 function safeURL(value){if(!value)return '';try{const u=new URL(value, 'https://math.portal.ghoneem.com');return u.protocol==='https:'&&!u.username&&!u.password?u.href:'';}catch{return '';}}
 function day(now=new Date()){return new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).format(now);}
 function campaign(date=day()){
  const examDate='2026-12-05',days=Math.round((Date.parse(examDate+'T00:00:00Z')-Date.parse(date+'T00:00:00Z'))/86400000);
  const starts=['2026-11-08','2026-11-16','2026-11-23','2026-11-30'];
  const phase=date<starts[0]||date>=examDate?-1:starts.reduce((index,start,i)=>date>=start?i:index,-1);
  return {examDate,days,phase,state:days<0?'finished':days===0?'exam':date<starts[0]?'upcoming':'preparing'};
 }
 const api={topics,normalize,duplicates,validateItems,safeURL,day,campaign};if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.RevisionCore=api;
})(typeof window==='undefined'?globalThis:window);
