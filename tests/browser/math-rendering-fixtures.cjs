const source = require('./math-source-fixtures.json');
const currency = 'A math book costs $75. An English book costs 40% less. One math book, one English book, and 3 copybooks cost $153. What is the combined cost of the 3 copybooks?';
const choices = texts => texts.map((text,i)=>({key:'ABCD'[i],text}));
const cases = [
 {id:'currency',topic:'Percentages',stem:currency,choices:choices(['$11','$33','$4','$66']),mathCount:0},
 {id:'mixed',topic:'Mixed notation',stem:String.raw`Pay $75 and $153. A 40% discount leaves 60%. Solve $2x+3=11$ and \(\frac{x^2+1}{\sqrt{5}}=\sqrt{5}\). The final sentence must remain visible.`,choices:choices([String.raw`\(x=2\)`,String.raw`$x=4$`,'$33 and $66','40% less than $153']),mathCount:2},
 {...source[0],id:'matrix',mathCount:2},
 {id:'wide-inline',topic:'Synthetic width stress',stem:String.raw`The complete expression is \(123456789+234567890+345678901+456789012+567890123+678901234\). Read the final term before choosing.`,choices:choices([String.raw`\(123456789+234567890+345678901+456789012+567890123+678901234\)`,'10% of $75','$33','$153']),mathCount:1},
 {id:'wide-display',topic:'Synthetic matrix stress',stem:String.raw`Read every column: \[A=\begin{pmatrix}123456&234567&345678&456789&567890&678901\\234567&345678&456789&567890&678901&789012\end{pmatrix}\] The final entry is visible by scrolling the expression.`,choices:choices(['789012','123456','40%','$153']),mathCount:1},
 {id:'table',topic:'Synthetic table stress',stem:'The table contains dollar amounts and percentages. Read the final column.',choices:choices(['$75','$153','40%','60%']),assets:{html:'<table><caption>Costs and discounts</caption><tr><th>Item</th><th>January</th><th>February</th><th>March</th><th>April</th><th>May</th><th>June</th></tr><tr><td>Copybooks</td><td>$75</td><td>$153</td><td>40%</td><td>$230.75</td><td>$1,250.50</td><td>$33</td></tr></table>'},mathCount:0},
 {...source[1],id:'diagram',mathCount:0},
 {id:'grid-in',topic:'Fractions',type:'grid_in',stem:String.raw`Enter the value of \(\frac{\frac{3}{4}}{\sqrt{\frac{9}{16}}}\). Keep the final sentence visible.`,mathCount:1}
].map(q=>({type:'mcq',assets:{},...q}));
function fixtureSDK(){
 const session={access_token:'synthetic-local-only',user:{id:'math-layout-fixture'}};
 window.__savedAnswers=[];
 if(!crypto.randomUUID){let n=0;crypto.randomUUID=()=> '00000000-0000-4000-8000-'+String(++n).padStart(12,'0');}
 window.supabase={createClient(){return {
  auth:{onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),getSession:async()=>({data:{session}}),getUser:async()=>({data:{user:session.user}})},
  rpc:async name=>{if(name!=='my_course_access')throw Error('Unexpected fixture RPC '+name);return {data:['sat','est','est2'].map(track_id=>({track_id,status:'active',practice_open:true,can_finish:false})),error:null};},
  from:()=>({upsert:async rows=>{window.__savedAnswers.push(...(Array.isArray(rows)?rows:[rows]));return {error:null};}})
 };}};
}
function fixtureFetch(cases){
 const nativeFetch=window.fetch.bind(window);
 window.__unexpectedRequests=[];
 window.fetch=async(input,init)=>{
  const url=new URL(typeof input==='string'?input:input.url,location.href);
  if(url.origin===location.origin)return nativeFetch(input,init);
  if(url.hostname!=='wfhurjyouemahvkcfkdz.supabase.co')throw Error('External fixture request blocked');
  const track=new URLSearchParams(location.search).get('track')||'sat';
  const exam={id:'math-audit',title:'Isolated mathematics layout audit',track_id:track,assessment_type:'full_exam',questions:cases.length,duration_seconds:2100,open:true};
  const name=url.pathname.split('/').pop();let data;
  if(name==='me-tracks')data=url.search?{exams:[exam],dashboard:{}}:{role:'student',tracks:[{id:track,name:{sat:'SAT Math',est:'EST I Math',est2:'EST II Math'}[track],exams_available:1,attempts_done:0}]};
  else if(name==='portal-controls')data={revision_visible:true};
  else if(name==='daily-challenge')data={date:'2026-10-24',quiz:[],checklist:{},leaderboard:[]};
  else if(name==='start-attempt'){const now=Date.now();data={exam,attempt:{id:'math-audit-local-only',server_now:new Date(now).toISOString(),deadline_at:new Date(now+2100000).toISOString()},questions:structuredClone(cases)};}
  else if(name==='exam-activity')data={accepted:JSON.parse(init.body).data.events.map(e=>e.id)};
  else {window.__unexpectedRequests.push(url.href);throw Error('Unexpected fixture function '+name);}
  return new Response(JSON.stringify(data),{status:200,headers:{'Content-Type':'application/json'}});
 };
}
module.exports={cases,fixtureSDK,fixtureFetch};
