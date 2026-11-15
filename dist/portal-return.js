/* Same-origin sign-in continuation; no session or permission changes. */
window.PortalReturn=(()=>{
 'use strict';
 const pages=new Set(['/study-plan.html','/practice-bundles.html','/checkpoint.html','/sat-revision.html','/est-revision.html']);
 function target(){
  const value=new URLSearchParams(location.search).get('return_to');
  if(!value||!value.startsWith('/')||value.startsWith('//')||value.includes('\\'))return null;
  try{const url=new URL(value,location.origin);if(url.origin!==location.origin||!pages.has(url.pathname))return null;return url.pathname+url.search;}catch{return null;}
 }
 function offer(host){
  if(!host||!pages.has(location.pathname))return;
  document.getElementById('portalSignIn')?.remove();
  const a=document.createElement('a');a.id='portalSignIn';a.className='portal-shortcut';
  a.href='/?'+new URLSearchParams({return_to:location.pathname+location.search});
  a.textContent='Sign in & return here';host.after(a);
 }
 return {target,offer};
})();
