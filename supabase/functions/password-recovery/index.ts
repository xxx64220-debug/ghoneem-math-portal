import {admin,ApiError,requireAdmin} from './auth.ts';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const origins=new Set(['https://math.portal.ghoneem.com','https://ghoneem-exam-portal.xxx64220.chatgpt.site',...(Deno.env.get('ALLOWED_ORIGIN')||'').split(',').map(x=>x.trim()).filter(Boolean)]);
const tags=['admin_required','request_not_found','invalid_decision','already_reviewed','request_expired','account_unavailable','approval_required','link_busy'];
function checked(result:any){if(result.error)throw new ApiError(tags.find(t=>result.error.message?.includes(t))||'recovery_unavailable',result.error.message&&tags.some(t=>result.error.message.includes(t))?409:503);return result.data;}
async function bodyOf(req:Request){
 const reader=req.body?.getReader();if(!reader)throw new ApiError('invalid_request');
 const chunks:Uint8Array[]=[];let size=0;
 while(true){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>4096){await reader.cancel();throw new ApiError('invalid_request',413);}chunks.push(value);}
 const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length;}
 let b;try{b=JSON.parse(new TextDecoder().decode(bytes));}catch{throw new ApiError('invalid_request');}
 if(!b||typeof b!=='object'||Array.isArray(b))throw new ApiError('invalid_request');return b;
}
export async function handle(req:Request){
 if(req.method!=='POST')throw new ApiError('method_not_allowed',405);
 const b=await bodyOf(req),db=admin();
 if(b.action==='submit'){
  for(const k of ['login','full_name','phone','group_note','request_id'])if(typeof b[k]!=='string')throw new ApiError('invalid_details');
  const login=b.login.trim().toLowerCase(),name=b.full_name.trim(),phone=b.phone.trim(),group=b.group_note.trim();
  if(!uuid.test(b.request_id)||login.length>254||!(login.includes('@')?/^[^\s@]+@[^\s@]+\.[^\s@]+$/:/^[a-z0-9._-]{3,32}$/).test(login)||name.length<2||name.length>100||phone.length>30||phone&&!/^\+?[0-9 ()-]{7,30}$/.test(phone)||group.length>120||/[\x00-\x1f\x7f]/.test(name+group+login)||b.website)throw new ApiError('invalid_details');
  const ip=req.headers.get('x-forwarded-for')?.split(',')[0].trim()||'unknown';
  const bytes=await crypto.subtle.digest('SHA-256',new TextEncoder().encode('password-recovery:'+ip));
  const key=Array.from(new Uint8Array(bytes),v=>v.toString(16).padStart(2,'0')).join('');
  if(!checked(await db.rpc('password_recovery_rate_limit',{p_key:key})))throw new ApiError('recovery_limit',429);
  const email=login.includes('@')?login:login+'@'+(Deno.env.get('STUDENT_EMAIL_DOMAIN')||'students.ghoneem-math.com');
  checked(await db.rpc('password_recovery_submit',{p_id:b.request_id,p_login:login,p_email:email,p_name:name,p_phone:phone,p_group:group}));
  return {submitted:true};
 }
 if(!['list','count','review','issue'].includes(b.action))throw new ApiError('invalid_request');
 const me=await requireAdmin(req);
 if(b.action==='count'){
  const r=await db.from('password_recovery_requests').select('id',{count:'exact',head:true}).eq('status','pending');checked(r);return {pending:r.count||0};
 }
 if(b.action==='list'){
  const status=['pending','approved','rejected'].includes(b.status)?b.status:'pending';
  const offset=Number.isInteger(b.offset)&&b.offset>=0?Math.min(b.offset,10000):0;
  const r=await db.from('password_recovery_requests').select('id,user_id,login,full_name,phone,group_note,status,created_at,reviewed_at,link_issued_at,profile:profiles!password_recovery_requests_user_id_fkey(full_name,email,status,role)',{count:'exact'}).eq('status',status).order('created_at',{ascending:false}).order('id').range(offset,offset+24);
  checked(r);
  const ids=(r.data||[]).map((x:any)=>x.user_id).filter(Boolean);
  const contacts=ids.length?await db.from('student_registration_requests').select('user_id,phone').in('user_id',ids):{data:[],error:null};checked(contacts);
  const phones=new Map((contacts.data||[]).map((x:any)=>[x.user_id,x.phone]));
  return {items:(r.data||[]).map((x:any)=>({...x,registered_phone:phones.get(x.user_id)||''})),total:r.count||0};
 }
 if(!uuid.test(b.id||''))throw new ApiError('invalid_request');
 if(b.action==='review'){
  if(!['approved','rejected'].includes(b.decision)||b.decision==='approved'&&b.identity_confirmed!==true)throw new ApiError('identity_required');
  return checked(await db.rpc('password_recovery_review',{p_actor:me.id,p_id:b.id,p_decision:b.decision}));
 }
 if(b.identity_confirmed!==true)throw new ApiError('identity_required');
 const nonce=crypto.randomUUID();
 const account=checked(await db.rpc('password_recovery_issue_claim',{p_actor:me.id,p_id:b.id,p_nonce:nonce}));
 try{
  const {data,error}=await db.auth.admin.generateLink({type:'recovery',email:account.email});
  const hash=data?.properties?.hashed_token;
  if(error||!hash||data?.user?.id!==account.user_id)throw new ApiError('link_failed',503);
  checked(await db.rpc('password_recovery_issue_finish',{p_actor:me.id,p_id:b.id,p_nonce:nonce,p_success:true}));
  // Fragment never goes to the web server, referrer, audit log or request table.
  return {reset_url:'https://math.portal.ghoneem.com/password-reset.html#token_hash='+encodeURIComponent(hash)};
 }catch{
  await db.rpc('password_recovery_issue_finish',{p_actor:me.id,p_id:b.id,p_nonce:nonce,p_success:false}).catch(()=>{});
  throw new ApiError('link_failed',503);
 }
}
Deno.serve(async req=>{
 const origin=req.headers.get('origin');
 const headers:Record<string,string>={'Content-Type':'application/json','Cache-Control':'no-store','Vary':'Origin','Access-Control-Allow-Methods':'POST, OPTIONS','Access-Control-Allow-Headers':'authorization, apikey, content-type'};
 if(origin&&origins.has(origin))headers['Access-Control-Allow-Origin']=origin;
 if(origin&&!origins.has(origin))return new Response(JSON.stringify({error:'origin_not_allowed'}),{status:403,headers});
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 try{return new Response(JSON.stringify(await handle(req)),{headers});}
 catch(e){return new Response(JSON.stringify({error:e instanceof ApiError?e.message:'recovery_unavailable'}),{status:e instanceof ApiError?e.status:503,headers});}
});
