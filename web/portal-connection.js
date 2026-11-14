/* Authentication transport only. Never replay requests or touch saved answers. */
globalThis.PortalConnection = (() => {
 const TIMEOUT=15000,MAX_WAIT=300000;
 function options(api){
  const origin=new URL(api).origin,key='ghoneem-auth-recovery:'+origin;
  let memory={failures:0,until:0};
  function read(){try{const v=JSON.parse(sessionStorage.getItem(key));if(v&&Number.isInteger(v.failures)&&v.failures>=0&&v.failures<=3&&Number.isFinite(v.until)&&v.until<=Date.now()+MAX_WAIT)memory=v;}catch{}return memory;}
  function save(v){memory=v;try{if(v.failures)sessionStorage.setItem(key,JSON.stringify(v));else sessionStorage.removeItem(key);}catch{}}
  function failed(response){const failures=Math.min(3,read().failures+1),raw=Number(response?.headers?.get('Retry-After')),server=Number.isFinite(raw)?raw*1000:0;save({failures,until:Date.now()+Math.min(MAX_WAIT,Math.max(15000*2**(failures-1),server))});}
  const temporary=()=>{const error=new Error('Sign-in is temporarily unavailable. Wait a moment before trying again.');error.name='AuthRetryableFetchError';error.status=503;return error;};
  const transport=globalThis.fetch.bind(globalThis);
  return {global:{fetch:async(input,init={})=>{
   const url=new URL(typeof input==='string'||input instanceof URL?input:input.url);
   if(url.origin!==origin||!url.pathname.startsWith('/auth/v1/'))return transport(input,init);
   const limited=/\/auth\/v1\/(?:token|user)\/?$/.test(url.pathname);
   if(limited&&read().until>Date.now())throw temporary();
   const caller=init.signal||input?.signal,controller=new AbortController();let timedOut=false;
   const cancel=()=>controller.abort(caller.reason);if(caller?.aborted)cancel();else caller?.addEventListener('abort',cancel,{once:true});
   const timer=setTimeout(()=>{timedOut=true;controller.abort();},TIMEOUT);
   try{
    const response=await transport(input,{...init,signal:controller.signal});
    // Include response-body stalls in the deadline. Leave the original response
    // untouched for the SDK; Auth payloads are small JSON, never exam content.
    await response.clone().arrayBuffer();
    if(limited){if(response.status>=500||response.status===429)failed(response);else save({failures:0,until:0});}
    return response;
   }catch(error){
    if(limited&&!caller?.aborted)failed();
    if(timedOut)throw temporary();
    throw error;
   }finally{clearTimeout(timer);caller?.removeEventListener('abort',cancel);}
  }}};
 }
 return {options};
})();
