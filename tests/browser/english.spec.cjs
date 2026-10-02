const { test, expect } = require('@playwright/test');
// Synthetic text in the observed import topology: one marked assets.html root,
// metadata divs, source paragraphs, numbered annotations, and an illustration.
// No production content fetch or guessed passage boundary is used.
const passage = '<div class="est-passage"><div>Module 2 · Passage 1</div><div>Fixture passage</div><div>by Fixture author</div><p>First source paragraph.</p><p><b>[2]</b> <u>Underlined source text</u> <mark>[3]</mark><br>Next source line.</p><figure><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg==" alt="Fixture illustration"><figcaption>Source caption</figcaption></figure></div>';
const sdk = `window.supabase={createClient(){const session={access_token:'synthetic-local-only',user:{id:'smoke-user'}};return {auth:{onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}}),getSession:async()=>({data:{session}}),getUser:async()=>({data:{user:session.user}})},from:()=>({upsert:async rows=>{window.__savedAnswers=(window.__savedAnswers||[]).concat(rows);return {error:null}}})}}};`;

for (const track of ['est_eng','sat','est','est2']) {
 test(`${track}: passage layout, interaction and review`, async ({page,context}, testInfo) => {
 const tracks=[{id:track,name:track,exams_available:1,attempts_done:0}];
 const exam={id:'smoke-exam',title:'Local reading fixture',track_id:track,assessment_type:'full_exam',questions:2,duration_seconds:2100,open:true};
 const questions=[1,2].map(n=>({id:`reading-${n}`,type:'mcq',topic:'Reading fixture',stem:`Question ${n}: Which statement is supported?`,choices:[{key:'A',text:'First answer'},{key:'B',text:'Second answer'}],assets:{html:passage,passage_title:'Fixture passage',passage_number:1,module:2}}));
 const errors=[],unexpected=[];let revisionRequested=false;
 page.on('pageerror',e=>errors.push(e.message));
 await context.route('**/*', async route=>{
  const url=new URL(route.request().url());
  if(url.origin==='http://127.0.0.1:4173')return route.continue();
  
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
   else if(name==='submit-attempt')data={exam,attempt:{score:1,total:2},review_open:true,items:questions.map(q=>({...q,response:'A',correct:'A',is_correct:true,explanation:'Fixture explanation'}))};
   else if(name==='final-revision'){revisionRequested=true;data={items:[{id:'smoke-q1',lesson:'Linear functions',idea:'Slope',source:'sat',programmes:['sat'],difficulty:'easy',focus:{collections:['must_know']}}]};}
   else {unexpected.push(url.href);return route.abort();}
   return route.fulfill({json:data});
  }
  unexpected.push(url.href);return route.abort();
 });

 await page.goto('/');
 await page.getByRole('button',{name:track,exact:false}).click();
 await page.locator('[data-start="smoke-exam"]').click();
 await expect(page.locator('#qcard .stem')).toHaveText(questions[0].stem);
 if(track==='est_eng') {
  const pane=page.locator('#qcard .english-passage-pane');
  const body=page.locator('#qcard .english-passage-body');
  await expect(pane).toHaveAttribute('open','');
  await expect(page.locator('#qcard .est-passage')).toHaveCount(1);
  await expect(page.locator('#qcard .est-passage p')).toHaveText(['First source paragraph.','[2] Underlined source text [3]Next source line.']);
  await expect(page.locator('#qcard u')).toHaveText('Underlined source text');
  expect(await page.locator('#qcard u').evaluate(e=>getComputedStyle(e).textDecorationLine)).toContain('underline');
  await expect(page.locator('#qcard mark')).toHaveText('[3]');
  await expect(page.locator('#qcard br')).toHaveCount(1);
  await expect(page.locator('#qcard figcaption')).toHaveText('Source caption');
  await expect.poll(()=>page.locator('#qcard img').evaluate(e=>e.complete&&e.naturalWidth>0)).toBe(true);
  const geometry=await page.locator('#qcard .english-reading').evaluate(e=>{
   const p=e.querySelector('details').getBoundingClientRect(),q=e.querySelector('section').getBoundingClientRect();
   const ps=e.querySelectorAll('p');return {p:{x:p.x,y:p.y,right:p.right,bottom:p.bottom},q:{x:q.x,y:q.y},paragraphGap:ps[1].getBoundingClientRect().top-ps[0].getBoundingClientRect().bottom,lineHeight:parseFloat(getComputedStyle(ps[0]).lineHeight)};
  });
  expect(geometry.paragraphGap).toBeGreaterThan(10);expect(geometry.lineHeight).toBeGreaterThan(30);
  if(testInfo.project.name==='desktop')expect(geometry.q.x).toBeGreaterThanOrEqual(geometry.p.right);
  else {expect(geometry.q.y).toBeGreaterThanOrEqual(geometry.p.bottom);expect(await body.evaluate(e=>getComputedStyle(e).maxHeight)).toBe('none');}
  await pane.locator('summary').click();await expect(body).not.toBeVisible();
  await expect(page.locator('#qcard .choice')).toHaveCount(2);
  await pane.locator('summary').focus();await page.keyboard.press('Enter');await expect(body).toBeVisible();
  await page.screenshot({path:testInfo.outputPath('passage.png'),fullPage:true});
 } else {
  await expect(page.locator('#qcard .english-reading')).toHaveCount(0);
  // Even marked HTML remains a generic figure for each math track.
  await expect(page.locator('#qcard .fig')).toContainText('First source paragraph.');
  await expect(page.locator('#qcard .english-passage-pane')).toHaveCount(0);
 }
 await page.locator('#qcard .choice[data-k="A"]').click();
 await expect(page.locator('#saving')).toContainText('All answers saved');
 await page.locator('#nextBtn').click();await expect(page.locator('#qcard .stem')).toHaveText(questions[1].stem);
 await page.locator('#prevBtn').click();await expect(page.locator('#qcard .choice[data-k="A"]')).toHaveClass(/sel/);
 page.once('dialog',d=>d.accept());await page.locator('#finishBtn').click();
 await expect(page.locator('#vReview')).toBeVisible();
 await expect(page.locator('#vReview .review-choices')).toHaveCount(2);
 await expect(page.locator('#vReview .english-reading')).toHaveCount(track==='est_eng'?2:0);
 if(track==='est_eng') {await expect(page.locator('#vReview .est-passage p')).toHaveCount(4);await expect(page.locator('#vReview .exp').first()).toHaveText('Fixture explanation');}
 expect(await page.evaluate(()=>document.documentElement.scrollWidth)).toBeLessThanOrEqual(page.viewportSize().width+1);
 expect(errors).toEqual([]);expect(unexpected).toEqual([]);
 });
}
