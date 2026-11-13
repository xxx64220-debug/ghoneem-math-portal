import { admin, ApiError, json, requireUser, serve, sqlError } from './http.ts';
const uuid = (v: unknown) => typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
Deno.serve(serve(async req => {
 if (!['GET','POST'].includes(req.method)) throw new ApiError('method_not_allowed',405);
 const me=await requireUser(req);
 if(me.role!=='student')throw new ApiError('student_account_required',403);
 const url=new URL(req.url),p=req.method==='POST'?await req.json().catch(()=>null):Object.fromEntries(url.searchParams);
 if(!p||typeof p.track!=='string'||!['sat','est','est2','act2','est_eng','sat_eng'].includes(p.track))throw new ApiError('invalid_track',400);
 const args={p_user:me.id,p_track:p.track};let result;
 if(req.method==='GET'){
  if(p.view==='history') {const offset=Number(p.offset||0);if(!Number.isSafeInteger(offset)||offset<0||offset>10000)throw new ApiError('invalid_page',400);result=await admin().rpc('practice_bundle_history',{...args,p_offset:offset});}
  else if(p.view==='bundle'){if(!uuid(p.id))throw new ApiError('invalid_bundle',400);result=await admin().rpc('practice_bundle_state',{...args,p_bundle:p.id});}
  else if(!p.view||p.view==='catalog')result=await admin().rpc('practice_bundle_catalog',args);
  else throw new ApiError('invalid_view',400);
 }else if(p.action==='create'||p.action==='retake'){
  if(!uuid(p.request_id)||(p.action==='retake'&&!uuid(p.parent_id)))throw new ApiError('invalid_request',400);
  result=await admin().rpc('practice_bundle_create',{...args,p_request:p.request_id,p_settings:p.settings||{},p_parent:p.action==='retake'?p.parent_id:null});
 }else if(p.action==='save'||p.action==='submit'){
  if(!uuid(p.id)||!Number.isSafeInteger(p.revision)||!Number.isSafeInteger(p.position)||!p.answers||Array.isArray(p.answers)||typeof p.answers!=='object'||JSON.stringify(p.answers).length>40000)throw new ApiError('invalid_answers',400);
  result=await admin().rpc('practice_bundle_save',{...args,p_bundle:p.id,p_revision:p.revision,p_answers:p.answers,p_position:p.position,p_submit:p.action==='submit'});
 }else throw new ApiError('invalid_action',400);
 if(result.error){const tag=result.error.message;if(tag==='bundle_changed_elsewhere')throw new ApiError(tag,409);if(tag==='bundle_not_found')throw new ApiError(tag,404);throw sqlError(result.error);}
 return json(result.data);
}));
