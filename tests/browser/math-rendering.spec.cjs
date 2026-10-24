const {test,expect}=require('@playwright/test');
const path=require('node:path');
const {fixtureDocument}=require('./fixture-document.cjs');
const {cases,fixtureSDK,fixtureFetch}=require('./math-rendering-fixtures.cjs');
const katexDist=path.resolve(__dirname,'../english-runtime/node_modules/katex/dist');

for(const track of ['sat','est','est2'])for(const narrow of [false,true]){
 test(`${track} real KaTeX exam/review layouts${narrow?' at 320px':''}`,async({page,context},testInfo)=>{
  test.skip(narrow&&testInfo.project.name!=='mobile','Extra narrow layout runs in the mobile project');
  if(narrow)await page.setViewportSize({width:320,height:844});
  const errors=[],unexpected=[];page.on('pageerror',e=>errors.push(e.message));
  await context.route('**/*',async route=>{
   const url=new URL(route.request().url());
   if(url.hostname==='cdn.jsdelivr.net'&&url.pathname.startsWith('/npm/katex@0.18.2/dist/')){
    const relative=url.pathname.split('/dist/')[1];
    if(relative.includes('..'))throw Error('Invalid KaTeX fixture path');
    return route.fulfill({path:path.join(katexDist,relative),headers:{'access-control-allow-origin':'*'}});
   }
   if(url.hostname==='cdn.jsdelivr.net'&&url.pathname.includes('/@supabase/'))return route.fulfill({contentType:'application/javascript',headers:{'access-control-allow-origin':'*'},body:`(${fixtureSDK})();(${fixtureFetch})(${JSON.stringify(cases)});window.mathAuditCases=${JSON.stringify(cases)};`});
   if(url.hostname==='fonts.googleapis.com')return route.fulfill({body:'',contentType:'text/css'});
   if(url.origin==='http://127.0.0.1:4173')return fixtureDocument(route);
   unexpected.push(url.href);return route.abort();
  });
  await page.goto('/?track='+track);
  await page.addScriptTag({path:path.join(__dirname,'math-layout-checks.js')});
  await page.waitForFunction(()=>window.mathAuditReady);
  const results=await page.evaluate(()=>window.mathLayoutChecks.run());
  expect(results.filter(r=>r.issues.length)).toEqual([]);
  expect(errors).toEqual([]);expect(unexpected).toEqual([]);
  for(const index of [0,2,3,4,5,6,7]){
   await page.evaluate(index=>window.mathLayoutChecks.preview(index),index);
   await page.locator('#qcard').screenshot({path:testInfo.outputPath(cases[index].id+'.png')});
  }
  await testInfo.attach('layout-results',{body:Buffer.from(JSON.stringify(results,null,2)),contentType:'application/json'});
 });
}
