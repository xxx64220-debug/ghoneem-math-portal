// Read-only availability probes. No sign-in, student records or submissions.
import {pathToFileURL} from 'node:url';
export async function checkAvailability({fetchImpl=fetch,timeoutMs=8000}={}){
 const api='https://wfhurjyouemahvkcfkdz.supabase.co';
 const key='sb_publishable_FIUSELOTsAQaH8dQ6oF-ow_CcISJV5-';
 const probes=[
  ['portal','https://math.portal.ghoneem.com/'],
  ['auth',api+'/auth/v1/health'],
  // limit=0 asks PostgREST to plan/execute without returning any track rows.
  ['database',api+'/rest/v1/tracks?select=id&limit=0'],
 ];
 const results=await Promise.all(probes.map(async([name,url])=>{
  const controller=new AbortController(),started=Date.now(),timer=setTimeout(()=>controller.abort(),timeoutMs);
  try{
   const response=await fetchImpl(url,{headers:{...(name==='portal'?{}:{apikey:key}),'Cache-Control':'no-cache'},signal:controller.signal,cache:'no-store',redirect:'error'});
   // Consume the small response inside the deadline; never log its contents.
   const body=await response.arrayBuffer();let expectedDenial=false;
   if(name==='database'&&[401,403].includes(response.status)){
    try{const value=JSON.parse(new TextDecoder().decode(body));expectedDenial=value.code==='42501'&&value.message==='permission denied for table tracks';}catch{}
   }
   // This exact PostgreSQL permission response proves the database answered
   // while preserving its existing anonymous-access restrictions.
   return {name,ok:response.ok||expectedDenial,status:response.status,...(expectedDenial?{expected_access_denied:true}:{}),elapsed_ms:Date.now()-started};
  }catch(error){return {name,ok:false,error:controller.signal.aborted?'timeout':'connection_error',elapsed_ms:Date.now()-started};}
  finally{clearTimeout(timer);}
 }));
 return {checked_at:new Date().toISOString(),ok:results.every(r=>r.ok),checks:results};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 const first=await checkAvailability();console.log(JSON.stringify(first));
 if(!first.ok){
  // One bounded confirmation filters short network blips; no retry loop.
  await new Promise(resolve=>setTimeout(resolve,5000));
  const second=await checkAvailability();console.log(JSON.stringify(second));
  if(!second.ok)process.exitCode=1;
 }
}
