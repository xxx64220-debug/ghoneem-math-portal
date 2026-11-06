// Isolated browser coverage: production checklist code and styles, synthetic API.
// No authentication, real student, or production API is used by this fixture.
const {test,expect}=require('@playwright/test');
const fs=require('node:fs'),path=require('node:path');
const web=path.resolve(__dirname,'../../web');
const source=fs.readFileSync(path.join(web,'daily-challenge.js'),'utf8');
const styles=fs.readFileSync(path.join(web,'daily-challenge.css'),'utf8');
const index=fs.readFileSync(path.join(web,'index.html'),'utf8');
const baseStyles=[...index.matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map(m=>m[1]).join('\n');
const group='00000000-0000-4000-8000-000000000001';
function state(){return {track:'sat',group_id:group,scope_id:group,group_name:'Assigned SAT group',groups:[{id:group,name:'Assigned SAT group'}],date:'2026-11-06',server_now:'2026-11-06T10:00:00Z',reset_at:'2026-11-06T22:00:00Z',receivedAt:Date.now(),completed:false,points_total:90,points_today:0,rank:1,leaderboard:[],checklist:{quiz:false,focus:false,review:false},activity_status:{quiz:'pending',focus:'pending',review:'pending'},quiz:Array.from({length:5},(_,i)=>({id:'q'+i,stem:'Synthetic practice question '+(i+1),choices:[{key:'A',text:'4'},{key:'B',text:'8'}]}))};}
async function fixture(page,{failFirst=false}={}){
 let current=state(),submits=0;const calls=[];
 await page.route('**/__objective_api',async route=>{
  const body=route.request().method()==='POST'?route.request().postDataJSON():null;
  calls.push(body);
  if(body?.action==='quiz_start')current.activity_status.quiz='started';
  if(body?.action==='submit'){
   submits++;
   if(failFirst&&submits===1)return route.fulfill({status:503,json:{error:'Temporary interruption'}});
   current={...current,completed:true,score:5,points_today:60,points_total:150,activity_status:{...current.activity_status,quiz:'completed'},quiz:current.quiz.map(q=>({...q,answer:{submitted:body.answers[q.id],correct:'A',explanation:'Synthetic key.'}}))};
  }
  return route.fulfill({json:current});
 });
 await page.route('**/__objective_fixture',route=>route.fulfill({contentType:'text/html',body:`<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>${baseStyles}\n${styles}</style></head><body><main style="max-width:1100px;margin:auto;padding:12px"><div id="dashboardContent"></div><output id="destination"></output></main><script>
 const ST={track:{id:'sat',theme:{label:'SAT'}}}; const DASH={view:'daily',searchTerm:'',daily:${JSON.stringify(current)}};
 const esc=s=>String(s??'').replace(/[&<>\"]/g,x=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;'}[x])); const figure=()=>'',friendly=x=>x;
 async function fn(name,opts={}){const r=await fetch('/__objective_api',{method:opts.method||'GET',headers:{'Content-Type':'application/json'},...(opts.body?{body:JSON.stringify(opts.body)}:{})});return {ok:r.ok,json:await r.json()};}
 function paintDashboardContent(){document.getElementById('dashboardContent').innerHTML=dailyPanel();wireDaily();}const paintDashboard=paintDashboardContent;
 function setDashboardView(view){document.getElementById('destination').textContent=view;}
 ${source}
 paintDashboardContent();</script></body></html>`}));
 await page.goto('/__objective_fixture');
 return {calls,get submits(){return submits}};
}
test('checklist navigation cannot complete work and controls fit the viewport',async({page},info)=>{
 const f=await fixture(page);
 await expect(page.getByRole('button',{name:'Mark done'})).toHaveCount(0);
 await page.getByRole('button',{name:'Open lesson exams'}).click();
 await expect(page.locator('#destination')).toHaveText('lesson_exam');
 await expect(page.locator('[data-daily-status="focus"]')).toHaveText('Pending');
 await page.getByRole('button',{name:'Open notebook'}).click();
 await expect(page.locator('[data-daily-status="review"]')).toHaveText('Pending');
 expect(f.calls).toEqual([]);
 const viewport=page.viewportSize();
 for(const action of await page.locator('[data-daily-open]').all()){
  const box=await action.boundingBox();expect(box.width).toBeGreaterThan(40);expect(box.height).toBeGreaterThanOrEqual(44);expect(box.x).toBeGreaterThanOrEqual(0);expect(box.x+box.width).toBeLessThanOrEqual(viewport.width);
 }
 await info.attach('daily-checklist',{body:await page.screenshot({fullPage:true}),contentType:'image/png'});
});
test('interrupted quiz keeps answers; retry completes only after server confirmation',async({page})=>{
 const f=await fixture(page,{failFirst:true});
 for(let i=0;i<5;i++)await page.locator(`input[name="daily-q${i}"][value="A"]`).check();
 await expect(page.locator('[data-daily-status="quiz"]')).toHaveText('Started');
 await expect(page.locator('[data-daily-status="focus"]')).toHaveText('Pending');
 await page.getByRole('button',{name:'Submit answers'}).click();
 await expect(page.locator('#daily-message')).toHaveText('Temporary interruption');
 await expect(page.getByRole('button',{name:'Submit answers'})).toBeEnabled();
 await expect(page.locator('input[data-daily-answer]:checked')).toHaveCount(5);
 await page.getByRole('button',{name:'Submit answers'}).click();
 await expect(page.locator('[data-daily-status="quiz"]')).toHaveText('Completed automatically');
 await expect(page.locator('[data-daily-status="focus"]')).toHaveText('Pending');
 await expect(page.getByRole('button',{name:'Submit answers'})).toHaveCount(0);
 expect(f.submits).toBe(2);
 expect(f.calls.filter(Boolean).every(c=>c.group_id===group&&c.day==='2026-11-06')).toBe(true);
 expect(f.calls.some(c=>c?.action==='mark')).toBe(false);
});
