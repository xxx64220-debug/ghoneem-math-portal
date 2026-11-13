// Synthetic browser/DOM fixture. Never included in product pages or deployment assets.
(()=>{
 if(location.href==='about:srcdoc')history.replaceState=()=>{};
 const id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
 const tracks=['sat','est','est2','act2','est_eng','sat_eng'].map((id,i)=>({id,name:['SAT Math','EST I Math','EST II Math','ACT II Math','EST English','SAT English'][i]}));
 const choices=['A','B','C','D'].map((key,i)=>({key,text:String(i+1)}));
 const qs=[{id:id(1),topic:'Triangles and similarity',difficulty:'medium',type:'mcq',stem:'A right triangle has legs 3 and 4. Which choice is its area divided by 2?',choices,assets:{figspec:{h:210,lines:[[40,170,240,170],[40,170,40,30],[40,30,240,170],[40,160,50,160],[50,160,50,170]],extra:'<text x="120" y="195">4</text><text x="20" y="110">3</text>'}}},{id:id(2),topic:'Triangles and similarity',difficulty:'hard',type:'grid_in',stem:'The table shows a linear relationship. Find the value of \\(y\\) when \\(x=3\\).',choices:[],assets:{html:'<table><caption>Linear relationship</caption><thead><tr><th>x</th><th>y</th></tr></thead><tbody><tr><td>1</td><td>3</td></tr><tr><td>2</td><td>5</td></tr></tbody></table>'}}];
 let bundles=[];try{bundles=JSON.parse(sessionStorage.getItem('bundle-preview-data')||'[]');}catch{}
 const persist=()=>sessionStorage.setItem('bundle-preview-data',JSON.stringify(bundles));
 const copy=x=>JSON.parse(JSON.stringify(x));
 const fixture={failNextSave:false,delaySave:0,requests:[],bundles,conflictNextSave:false,failCatalog:false};window.BundleFixture=fixture;
 window.supabase={createClient:()=>({auth:{getUser:async()=>({data:{user:{id:id(50)}}}),getSession:async()=>({data:{session:{access_token:'synthetic-test-session'}}})}})};
 window.PortalDevices={configure(){},ensure:async()=>true};
 window.fetch=async(input,opts={})=>{
  const url=new URL(input),p=opts.body?JSON.parse(opts.body):Object.fromEntries(url.searchParams);fixture.requests.push(copy(p));
  const reply=(data,status=200)=>({ok:status===200,status,json:async()=>copy(data)});
  if(url.pathname.endsWith('/me-tracks'))return reply({role:'student',tracks});
  if(p.action==='save'||p.action==='submit'){
   if(fixture.delaySave)await new Promise(r=>setTimeout(r,fixture.delaySave));
   if(fixture.failNextSave){fixture.failNextSave=false;throw Error('Synthetic connection interrupted');}
   if(fixture.conflictNextSave){fixture.conflictNextSave=false;return reply({error:'bundle_changed_elsewhere'},409);}
   const b=bundles.find(x=>x.id===p.id);if(!b)return reply({error:'bundle_not_found'},404);
   if(b.revision!==p.revision)return reply({error:'bundle_changed_elsewhere'},409);
   b.answers=p.answers;b.position=p.position;b.revision++;
   if(p.action==='submit'){b.completed_at=new Date().toISOString();b.score=0;b.questions.forEach((q,i)=>{q.correct=i?'7':'C';q.explanation=i?'The slope is 2. The rule is y = 2x + 1, so y = 7.':'Area = ½ × 3 × 4 = 6. Half the area is 3 (choice C).';q.is_correct=b.answers[q.id]===q.correct;if(q.is_correct)b.score++;});}
   persist();return reply(p.action==='submit'?b:{revision:b.revision});
  }
  if(p.action==='create'||p.action==='retake'){
   const existing=bundles.find(x=>x.request_id===p.request_id);if(existing)return reply(existing);
   const b={id:id(100+bundles.length),request_id:p.request_id,track_id:p.track,parent_id:p.parent_id||null,created_at:new Date().toISOString(),settings:p.parent_id?copy(bundles.find(x=>x.id===p.parent_id).settings):p.settings,questions:copy(qs),question_ids:qs.map(q=>q.id),revision:0,answers:{},position:0,completed_at:null,score:null};bundles.unshift(b);persist();return reply(b);
  }
  if(p.view==='catalog'&&fixture.failCatalog)return reply({error:'catalog_failed'},503);
  if(p.view==='bundle')return reply(bundles.find(x=>x.id===p.id));
  if(p.view==='history')return reply({items:bundles.filter(x=>x.track_id===p.track).map(x=>({...x,total:2,answered:Object.values(x.answers).filter(Boolean).length}))});
  return reply({track:p.track,subtopics_supported:p.track==='sat',topics:[{section:p.track==='sat'?'Geometry and Trigonometry':'Geometry',topic:'Triangles and similarity',subtopic:'Right triangles',difficulty:'medium',total:12,unseen:8},{section:p.track==='sat'?'Geometry and Trigonometry':'Geometry',topic:'Triangles and similarity',subtopic:'Similarity',difficulty:'hard',total:10,unseen:7},{section:p.track==='sat'?'Geometry and Trigonometry':'Geometry',topic:'Circles',subtopic:'General lesson practice',difficulty:'hard',total:8,unseen:4},{section:'Algebra',topic:'Systems of equations',subtopic:'Two linear equations',difficulty:'easy',total:10,unseen:5}]});
 };
})();
