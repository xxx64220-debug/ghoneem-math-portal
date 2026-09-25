import webpush from 'npm:web-push@3.6.7';
import {admin, requireUser, ApiError, serve, json} from '../_shared/http.ts';
import {origins,validEndpoint,validKeys} from './policy.ts';
const db=admin();
function check(result:any){if(result.error)throw new ApiError('notification_service_error',500);return result.data;}
async function work(config:any){
 check(await db.rpc('portal_push_collect'));
 const jobs=check(await db.rpc('portal_push_claim'))||[];
 let sent=0;
 for(const j of jobs){
  const s=check(await db.from('portal_push_subscriptions').select('*').eq('id',j.subscription_id).maybeSingle());
  if(!s)continue;
  const p=check(await db.from('profiles').select('status').eq('id',s.user_id).maybeSingle());
  let allowed=p?.status==='active' && validEndpoint(s.endpoint) && origins.has(s.origin);
  if(j.kind==='exam')allowed=allowed&&s.exams&&!!check(await db.rpc('student_assignment_for',{p_exam:j.exam_id,p_user:s.user_id}));
  if(j.kind==='result')allowed=allowed&&s.results;
  if(j.kind==='reminder')allowed=allowed&&s.reminders;
  if(j.kind==='announcement'){
   const c=check(await db.from('portal_push_campaigns').select('track_id').eq('id',j.campaign_id).single());
   let q=db.from('enrollments').select('track_id').eq('user_id',s.user_id).eq('status','active'); if(c.track_id)q=q.eq('track_id',c.track_id);
   const en=check(await q);allowed=allowed&&en.length>0;
  }
  if(!allowed){check(await db.from('portal_push_queue').update({status:'skipped'}).eq('id',j.id));continue;}
  try {
   await webpush.sendNotification({endpoint:s.endpoint,keys:{p256dh:s.p256dh,auth:s.auth}},JSON.stringify({title:j.title,body:j.body,tag:j.event_key,url:'/',userId:s.user_id}),{TTL:3600,timeout:8000,vapidDetails:{subject:'https://math.portal.ghoneem.com',publicKey:config.public_key,privateKey:config.private_key}});
   check(await db.from('portal_push_queue').update({status:'sent',sent_at:new Date().toISOString(),error:null}).eq('id',j.id));sent++;
  }catch(e:any){
   if(e.statusCode===404||e.statusCode===410){check(await db.from('portal_push_subscriptions').delete().eq('id',s.id));}
   else check(await db.from('portal_push_queue').update({status:j.attempts>=3?'failed':'pending',error:'push_delivery_failed',next_attempt:new Date(Date.now()+300000).toISOString()}).eq('id',j.id));
  }
 }
 return {processed:jobs.length,sent};
}
Deno.serve(serve(async(req:Request)=>{
 if(req.method!=='POST')throw new ApiError('method_not_allowed',405);
 if(Number(req.headers.get('content-length')||0)>10000)throw new ApiError('request_too_large',413);
 const raw=await req.text();if(raw.length>10000)throw new ApiError('request_too_large',413);
 let body:any;try{body=JSON.parse(raw);}catch{throw new ApiError('invalid_json');}
 if(!body||typeof body!=='object')throw new ApiError('invalid_request');
 const config=check(await db.from('portal_push_config').select('*').eq('id',true).single());
 if(body.action==='dispatch'||body.action==='worker-check'){
  // Dedicated unpredictable worker credential, never exposed to browsers.
  const supplied=req.headers.get('x-portal-worker')||'';
  const digest=async(s:string)=>new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)));
  const a=await digest(supplied),b=await digest(config.worker_secret);let diff=0;for(let i=0;i<a.length;i++)diff|=a[i]^b[i];
  if(!supplied||diff)throw new ApiError('forbidden',403);
  if(body.action==='worker-check'){
   const request=webpush.generateRequestDetails({endpoint:'https://fcm.googleapis.com/fcm/send/self-check',keys:{p256dh:config.public_key,auth:'AAAAAAAAAAAAAAAAAAAAAA'}},'encryption check',{vapidDetails:{subject:'https://math.portal.ghoneem.com',publicKey:config.public_key,privateKey:config.private_key}});
   return json({encryption_ready:request.body?.length>0});
  }
  return json(await work(config));
 }
 const user=await requireUser(req);
 const origin=req.headers.get('origin')||'';if(!origins.has(origin))throw new ApiError('invalid_origin',403);
 if(body.action==='config')return json({publicKey:config.public_key});
 if(body.action==='status'){
  const s=check(await db.from('portal_push_subscriptions').select('exams,results,reminders').eq('user_id',user.id).eq('endpoint',String(body.endpoint||'')).maybeSingle());
  return json({subscription:s});
 }
 if(body.action==='subscribe'){
  const s=body.subscription;
  if(!s||!validEndpoint(s.endpoint)||!validKeys(s.keys))throw new ApiError('invalid_subscription');
  const old=check(await db.from('portal_push_subscriptions').select('user_id').eq('endpoint',s.endpoint).maybeSingle());
  if(old&&old.user_id!==user.id)throw new ApiError('device_linked_to_another_account',409);
  if(!old){const {count,error}=await db.from('portal_push_subscriptions').select('id',{count:'exact',head:true}).eq('user_id',user.id);if(error)throw error;if((count||0)>=10)throw new ApiError('device_limit_reached');}
  const prefs=body.preferences||{};
  const values={user_id:user.id,endpoint:s.endpoint,p256dh:s.keys.p256dh,auth:s.keys.auth,origin,exams:prefs.exams!==false,results:prefs.results!==false,reminders:prefs.reminders===true};
  if(old)check(await db.from('portal_push_subscriptions').update(values).eq('endpoint',s.endpoint).eq('user_id',user.id));
  else check(await db.from('portal_push_subscriptions').insert(values));
  return json({ok:true});
 }
 if(body.action==='unsubscribe'){
  check(await db.from('portal_push_subscriptions').delete().eq('endpoint',String(body.endpoint||'')).eq('user_id',user.id));return json({ok:true});
 }
 if(body.action==='test'){
  const s=check(await db.from('portal_push_subscriptions').select('id').eq('user_id',user.id).eq('endpoint',String(body.endpoint||'')).single());
  check(await db.from('portal_push_queue').upsert({subscription_id:s.id,event_key:'test:'+Math.floor(Date.now()/60000),kind:'test',title:'Notifications are ready',body:'This phone can receive Ghoneem Math notifications.'},{onConflict:'subscription_id,event_key',ignoreDuplicates:true}));return json({ok:true});
 }
 if(user.role!=='admin')throw new ApiError('forbidden',403);
 if(body.action==='announce'){
  if(!/^[0-9a-f-]{36}$/i.test(body.id||'')||typeof body.title!=='string'||typeof body.body!=='string'||!body.title.trim()||!body.body.trim()||body.title.length>80||body.body.length>240)throw new ApiError('invalid_message');
  const r=await db.rpc('portal_push_announce',{p_actor:user.id,p_id:body.id,p_title:body.title.trim(),p_body:body.body.trim(),p_track:body.track||null});
  if(r.error)throw new ApiError(r.error.message.includes('30 seconds')?'Please wait 30 seconds before another announcement':'notification_service_error');
  return json({queued:r.data});
 }
 if(body.action==='admin-status'){
  const campaigns=check(await db.from('portal_push_campaigns').select('id,title,created_at,track_id').order('created_at',{ascending:false}).limit(15));
  for(const c of campaigns){const rows=check(await db.from('portal_push_queue').select('status').eq('campaign_id',c.id));c.counts={};for(const r of rows)c.counts[r.status]=(c.counts[r.status]||0)+1;}
  const {count,error}=await db.from('portal_push_subscriptions').select('id',{count:'exact',head:true});if(error)throw error;
  return json({devices:count,campaigns});
 }
 throw new ApiError('unknown_action');
}));
