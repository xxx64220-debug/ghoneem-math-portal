const { test, expect } = require('@playwright/test');
const tracks = [{ id:'sat', name:'SAT Math', exams_available:1, attempts_done:0 }, { id:'est', name:'EST Math', exams_available:0, attempts_done:0 }];
const exam = { id:'smoke-exam', title:'Synthetic SAT smoke exam', track_id:'sat', assessment_type:'full_exam', questions:2, duration_seconds:2100, open:true };
const graph = 'https://fixtures.invalid/sat-line.svg';
const graphSvg = '<svg xmlns="http://www.w3.org/2000/svg" width="240" height="160"><path d="M20 140V20M20 140H220M20 140L180 20" stroke="blue" fill="none"/><text x="80" y="140">y = x</text></svg>';
const questions = [
 { id:'smoke-q1', topic:'Linear functions', stem:'For the graph shown, what is the slope?', type:'mcq', choices:[{key:'A',text:'1'},{key:'B',text:'2'},{key:'C',text:'3'},{key:'D',text:'4'}], assets:{image:graph,image_alt:'Synthetic line graph'} },
 { id:'smoke-q2', topic:'Linear equations', stem:'Solve 2x = 8.', type:'grid_in', assets:{html:'<table><tr><th>x</th><th>2x</th></tr><tr><td>4</td><td>8</td></tr></table>'} }
];
// Replace only the SDK boundary; execute the checked-in portal scripts unchanged.
const sdk = `window.supabase={createClient(){const session={access_token:'synthetic-local-only',user:{id:'smoke-user'}};return {auth:{getSession:async()=>({data:{session}}),getUser:async()=>({data:{user:session.user}})},from:()=>({upsert:async rows=>{window.__savedAnswers=(window.__savedAnswers||[]).concat(rows);return {error:null}}})}}};`;
test('SAT portal, exam navigation/timer/figures and Final Revision', async ({page,context}) => {
 const errors=[], unexpected=[]; let revisionRequested=false;
 page.on('pageerror', e=>errors.push(e.message));
 await context.route('**/*', async route=>{
  const url=new URL(route.request().url());
  if(url.origin==='http://127.0.0.1:4173')return route.continue();
  if(url.href===graph)return route.fulfill({contentType:'image/svg+xml',body:graphSvg});
  if(url.href==='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.0/dist/umd/supabase.js')return route.fulfill({contentType:'application/javascript',body:sdk});
  // Optional CDN styling/fonts/math are offline in this smoke test.
  if(url.hostname==='fonts.googleapis.com' || (url.hostname==='cdn.jsdelivr.net' && url.pathname.startsWith('/npm/katex@0.16.9/dist/')))return route.fulfill({body:'',contentType:route.request().resourceType()==='script'?'application/javascript':'text/css'});
  if(url.hostname==='wfhurjyouemahvkcfkdz.supabase.co' && url.pathname.startsWith('/functions/v1/')){
   const name=url.pathname.split('/').pop();let data;
   if(name==='me-tracks')data=url.search?{exams:[exam],dashboard:{}}:{role:'student',tracks};
   else if(name==='portal-controls')data={revision_visible:true};
   else if(name==='daily-challenge')data={date:'2026-10-02',reset_at:'2026-10-03T00:00:00Z',checklist:{quiz:false,focus:false,review:false},quiz:[],points_total:0};
   else if(name==='start-attempt'){const now=Date.now();data={exam:{...exam},attempt:{id:'smoke-attempt',server_now:new Date(now).toISOString(),deadline_at:new Date(now+2100000).toISOString()},questions};}
   else if(name==='exam-activity')data={accepted:JSON.parse(route.request().postData()).data.events.map(e=>e.id)};
   else if(name==='final-revision'){revisionRequested=true;data={items:[{id:'smoke-q1',lesson:'Linear functions',idea:'Slope',source:'sat',programmes:['sat'],difficulty:'easy',focus:{collections:['must_know']}}]};}
   else {unexpected.push(url.href);return route.abort();}
   return route.fulfill({json:data});
  }
  unexpected.push(url.href);return route.abort();
 });
 await page.goto('/');
 await expect(page.locator('#vTracks')).toBeVisible();
 await page.getByRole('button',{name:/SAT Math/}).click();
 await expect(page.locator('#listTitle')).toHaveText('SAT Math');
 await page.locator('[data-view="revision"]').click();
 await expect(page.locator('.revision-lesson')).toContainText('Linear functions');
 expect(revisionRequested).toBe(true);
 await expect(page.locator('[data-revision-start="10"]')).toBeEnabled();
 await page.locator('[data-view="full_exam"]').click();
 await page.locator('[data-start="smoke-exam"]').click();
 await expect(page.locator('#vRun')).toBeVisible();
 await expect(page.locator('#qcard .stem')).toHaveText(questions[0].stem);
 await expect(page.locator('#qcard .choice')).toHaveCount(4);
 await expect(page.locator('#qcard .choice-text')).toHaveText(['1','2','3','4']);
 const image=page.locator('#qcard img');await expect(image).toHaveAttribute('alt','Synthetic line graph');
 await expect.poll(()=>image.evaluate(i=>i.complete&&i.naturalWidth>0)).toBe(true);
 await expect(page.locator('#prevBtn')).toBeDisabled();
 await expect(page.locator('#clock')).toHaveText(/34:5\d|35:00/);
 const seconds = text => text.split(':').reduce((n,v)=>n*60+Number(v),0);
 const before=await page.locator('#clock').textContent();
 await expect(page.locator('#clock')).not.toHaveText(before,{timeout:4000});
 await page.locator('.choice[data-k="A"]').click();
 await expect(page.locator('#saving')).toContainText('All answers saved');
 await page.locator('#flagBtn').click();
 await expect(page.locator('#palette .pal').first()).toHaveClass(/flagged/);
 await page.locator('#nextBtn').click();
 await expect(page.locator('#qcard .stem')).toHaveText(questions[1].stem);
 await expect(page.locator('#qcard table')).toContainText('8');
 await page.locator('#gin').fill('4');
 await expect(page.locator('#progress')).toHaveText('2 of 2 answered');
 await expect(page.locator('#nextBtn')).toBeDisabled();
 await page.locator('#prevBtn').click();
 await expect(page.locator('#qcard .stem')).toHaveText(questions[0].stem);
 await page.locator('#palette .pal').nth(1).click();
 await page.locator('#palette .pal').first().click();
 await expect(page.locator('.choice[data-k="A"]')).toHaveClass(/sel/);
 await page.locator('#nextBtn').click();await expect(page.locator('#gin')).toHaveValue('4');
 await expect.poll(()=>page.evaluate(()=>window.__savedAnswers?.length||0)).toBeGreaterThanOrEqual(2);
 expect(seconds(await page.locator('#clock').textContent())).toBeLessThan(seconds(before));
 await expect(page.locator('#satDesmos')).toBeVisible();
 await expect(page.locator('#satDesmos')).toHaveAttribute('href','https://www.desmos.com/testing/collegeboard/graphing');
 await expect(page.locator('#satDesmos')).toHaveAttribute('rel',/noopener/);
 // Also handles a future embed without permitting an external network request.
 for(const frame of await page.locator('#vRun iframe[src*="desmos"]').all())await expect(frame).toBeVisible();
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBe(true);
 expect(errors).toEqual([]);expect(unexpected).toEqual([]);
});
