import { admin, ApiError, json, requireUser, serve, sqlError } from '../_shared/http.ts';
Deno.serve(serve(async req => {
 if(req.method!=='POST')throw new ApiError('method_not_allowed',405);
 const me=await requireUser(req),body=await req.json().catch(()=>null);
 if(!body||!['events','summary','details'].includes(body.action)||!body.data||typeof body.data!=='object'||Array.isArray(body.data))throw new ApiError('invalid_request',400);
 if(body.action!=='events'&&!['admin','instructor'].includes(me.role))throw new ApiError('staff_required',403);
 const {data,error}=await admin().rpc('exam_activity',{p_actor:me.id,p_action:body.action,p_data:body.data});
 if(error)throw sqlError(error);return json(data);
}));
