// Synthetic SDK boundary only. The actual portal code still calls its course RPC.
// Unknown RPC names fail closed; this helper never reaches a real backend.
function withCourseAccess(sdk){
 const marker='return {auth:';
 if(!sdk.includes(marker))throw new Error('Synthetic SDK return boundary missing');
 return sdk.replace(marker,`return {rpc:async(name)=>{
  if(name!=='my_course_access')throw new Error('Unexpected fixture RPC: '+name);
  window.fixtureAccessReads=(window.fixtureAccessReads||0)+1;
  return {error:null,data:['sat','est','est2','est_eng'].map(track_id=>({track_id,status:'active',practice_open:true,can_finish:false,starts_at:null,ends_at:null,course_label:'Synthetic '+track_id}))};
 },auth:`)+`\n(${approvedBrowserFixture})();`;
}
function approvedBrowserFixture(){
 if(location.origin!=='http://127.0.0.1:4173')throw Error('Browser fixture must stay local');
 const nativeFetch=window.fetch.bind(window);
 window.fetch=async(input,init)=>{
  const url=new URL(typeof input==='string'?input:input.url,location.href);
  if(url.origin==='https://wfhurjyouemahvkcfkdz.supabase.co'&&url.pathname==='/functions/v1/portal-devices'){
   const body=JSON.parse(init.body);
   if(body.action!=='register'||!/^[a-f0-9]{64}$/.test(body.data.token))throw Error('Unexpected device fixture request');
   window.fixtureDeviceRegistrations=(window.fixtureDeviceRegistrations||0)+1;
   return new Response(JSON.stringify({status:'approved',browser_id:'local-browser-fixture',label:'Fixture browser'}),{status:200,headers:{'Content-Type':'application/json'}});
  }
  return nativeFetch(input,init);
 };
}
module.exports={withCourseAccess};
