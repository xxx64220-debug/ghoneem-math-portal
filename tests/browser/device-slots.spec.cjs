const {test,expect}=require('@playwright/test');

test('student and administrator see capacity and different approval controls',async({page})=>{
  await page.route('**/device-fixture',route=>route.fulfill({contentType:'text/html',body:'<main id="view"></main>'}));
  await page.route('**/portal-devices',route=>route.fulfill({json:{
    approved:true,devices:[{id:'abcdef1234',user_id:'student',label:'Phone',status:'pending',approved_count:2,max_browsers:2,last_seen:'2026-11-03'}]
  }}));
  await page.goto('/device-fixture');
  await page.addScriptTag({url:'/portal-devices.js'});
  await page.evaluate(async()=>{
    PortalDevices.configure({sb:{auth:{getSession:async()=>({data:{session:{access_token:'fixture'}}})}},fnBase:location.origin,key:'fixture'});
    await PortalDevices.open();
  });
  await expect(page.getByText('0 of 2 browser slots available')).toBeVisible();
  await expect(page.locator('[data-approve]')).toHaveCount(0);
  await page.evaluate(async()=>{document.querySelector('dialog').close();await PortalDevices.renderAdmin(document.querySelector('main'));});
  await expect(page.locator('main [data-approve]')).toBeVisible();
  await expect(page.locator('main').getByText('0 of 2 browser slots available')).toBeVisible();
});
