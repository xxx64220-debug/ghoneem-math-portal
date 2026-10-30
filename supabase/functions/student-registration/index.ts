// Public submission. Listing and review require an active administrator session.
import {admin,ApiError,json,requireAdmin,serve} from '../_shared/http.ts';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const reply=(body:unknown,status=200)=>json(body,status,{'Cache-Control':'no-store'});
Deno.serve(serve(async req=>{
 const db=admin();
 if(req.method==='GET'){
  const {data,error}=await db.from('tracks').select('id,name').eq('is_active',true).order('name');
  if(error)throw new ApiError('registration_unavailable',503);return reply({tracks:data});
 }
 if(req.method!=='POST')throw new ApiError('method_not_allowed',405);
 const raw=await req.text();if(raw.length>6000)throw new ApiError('invalid_request',413);
 let b;try{b=JSON.parse(raw);}catch{throw new ApiError('invalid_request',400);}
 if(!b||typeof b!=='object'||Array.isArray(b))throw new ApiError('invalid_request',400);
 if(b.action==='list'||b.action==='review'){
  const me=await requireAdmin(req);
  if(b.action==='review'){
   if(!uuid.test(b.id||'')||!b.data||typeof b.data!=='object'||Array.isArray(b.data))throw new ApiError('invalid_request',400);
   const {data,error}=await db.rpc('registration_review',{p_actor:me.id,p_id:b.id,p_data:b.data||{}});
   if(error){const tag=['invalid_track','group_course_mismatch','end_must_follow_start','request_already_reviewed','account_changed_refresh','request_not_found','invalid_decision'].find(t=>error.message.includes(t));throw new ApiError(tag||'review_failed',409);}return reply(data);
  }
  const status=['pending','approved','rejected'].includes(b.status)?b.status:'pending';const offset=Number.isInteger(b.offset)&&b.offset>=0?Math.min(b.offset,100000):0;
  let q=db.from('student_registration_requests').select('id,user_id,username,full_name,phone,track_id,group_note,status,created_at,reviewed_at',{count:'exact'}).eq('status',status).order('created_at',{ascending:false}).order('id').range(offset,offset+49);
  if(['username','full_name','password','track_id'].some(k=>typeof b[k]!=='string')||['phone','group_note'].some(k=>b[k]!==undefined&&typeof b[k]!=='string'))throw new ApiError('invalid_details',400);
 if(typeof b.track_id==='string'&&b.track_id)q=q.eq('track_id',b.track_id);
  const {data,error,count}=await q;if(error)throw new ApiError('list_failed',503);return reply({items:data,total:count});
 }
 if(b.action!=='submit')throw new ApiError('invalid_request',400);
 const username=typeof b.username==='string'?b.username.trim().toLowerCase():'';const full_name=typeof b.full_name==='string'?b.full_name.trim():'';const password=typeof b.password==='string'?b.password:'';const phone=typeof b.phone==='string'?b.phone.trim():'';const group_note=typeof b.group_note==='string'?b.group_note.trim():'';
 if(['username','full_name','password','track_id'].some(k=>typeof b[k]!=='string')||['phone','group_note'].some(k=>b[k]!==undefined&&typeof b[k]!=='string'))throw new ApiError('invalid_details',400);
 if(typeof b.track_id!=='string'||!b.track_id||b.track_id.length>64||/[\x00-\x1f\x7f]/.test(full_name+group_note)||phone&&!/^\+?[0-9 ()-]{7,30}$/.test(phone)||!uuid.test(b.request_id||'')||!/^[a-z0-9._-]{3,32}$/.test(username)||full_name.length<2||full_name.length>100||phone.length>30||group_note.length>120)throw new ApiError('invalid_details',400);
 if(password.length<8||new TextEncoder().encode(password).length>72)throw new ApiError('weak_password',400);
 if(b.website)throw new ApiError('invalid_details',400);
 // A completed retry does not consume another new-account quota. The opaque receipt is not an access token.
 const prior=await db.from('student_registration_requests').select('username,status').eq('id',b.request_id).maybeSingle();if(prior.error)throw new ApiError('registration_unavailable',503);if(prior.data){if(prior.data.username!==username)throw new ApiError('request_conflict',409);return reply({submitted:true,status:prior.data.status});}
 const ip=req.headers.get('x-forwarded-for')?.split(',')[0].trim()||'unknown';const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode('registration:'+ip));const key=Array.from(new Uint8Array(digest),v=>v.toString(16).padStart(2,'0')).join('');
 const limit=await db.rpc('registration_rate_limit',{p_key:key});if(limit.error)throw new ApiError('registration_unavailable',503);if(!limit.data)throw new ApiError('registration_limit',429);
 const track=await db.from('tracks').select('id').eq('id',b.track_id).eq('is_active',true).maybeSingle();if(track.error||!track.data)throw new ApiError('invalid_track',400);
 const email=`${username}@${Deno.env.get('STUDENT_EMAIL_DOMAIN')||'students.ghoneem-math.com'}`;let created;
 try{created=await db.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{username,full_name}});}catch{throw new ApiError('registration_unavailable',503);}
 if(created.error||!created.data?.user){
  // Another copy of the same submission may have completed while Auth enforced email uniqueness.
  const saved=await db.from('student_registration_requests').select('username,status').eq('id',b.request_id).maybeSingle();
  if(saved.error)throw new ApiError('registration_unavailable',503);
  if(saved.data?.username===username)return reply({submitted:true,status:saved.data.status});
  const code=created.error?.code;
  if(code==='email_exists'||code==='user_already_exists')throw new ApiError('username_unavailable',409);
  if(code==='weak_password')throw new ApiError('weak_password',400);
  throw new ApiError('registration_unavailable',503);
 }
 const uid=created.data.user.id;let completed;
 try{completed=await db.rpc('registration_complete',{p_id:b.request_id,p_user:uid,p_data:{username,full_name,email,phone,group_note,track_id:b.track_id}});}catch{completed={error:{code:''}};}
 if(completed.error){const saved=await db.from('student_registration_requests').select('user_id').eq('id',b.request_id).maybeSingle();if(saved.data?.user_id===uid)return reply({submitted:true},201);if(!saved.error&&/^(22|23|P0)/.test(completed.error.code||''))await db.auth.admin.deleteUser(uid);throw new ApiError('registration_unavailable',503);}
 return reply({submitted:true},201);
}));
