const {test,expect}=require('@playwright/test');
const {fixtureDocument}=require('./fixture-document.cjs');

test('administrator page works directly and is blocked inside an iframe',async({page,context})=>{
 const messages=[];
 page.on('console',message=>messages.push(message.text()));
 await context.route('**/*',async route=>{
  const url=new URL(route.request().url());
  if(url.origin==='http://127.0.0.1:4173')return fixtureDocument(route);
  if(url.hostname==='cdn.jsdelivr.net'&&url.pathname.includes('/@supabase/supabase-js@'))return route.fulfill({contentType:'application/javascript',body:'window.supabase={createClient(){return {auth:{getSession:async()=>({data:{session:null}}),getUser:async()=>({data:{user:null}}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})}}}};'});
  if(['cdn.jsdelivr.net','fonts.googleapis.com'].includes(url.hostname))return route.fulfill({contentType:route.request().resourceType()==='script'?'application/javascript':'text/css',body:''});
  return route.abort();
 });
 const response=await page.goto('/admin.html');
 expect(response.status()).toBe(200);
 expect(response.headers()['x-frame-options']).toBe('DENY');
 expect(response.headers()['content-security-policy']).toContain("frame-ancestors 'none'");
 await expect(page.locator('#vLogin')).toBeVisible();
 await page.goto('about:blank');
 messages.length=0;
 const framedResponse=page.waitForResponse(response=>response.url()==='http://127.0.0.1:4173/admin.html');
 await page.setContent('<iframe src="http://127.0.0.1:4173/admin.html" title="Untrusted frame"></iframe>');
 await framedResponse;
 await expect.poll(()=>messages.some(message=>/frame-ancestors|X-Frame-Options/i.test(message))).toBe(true);
 expect(await page.locator('iframe').evaluate(frame=>{try{return !frame.contentDocument?.getElementById('vLogin');}catch{return true;}})).toBe(true);
});
