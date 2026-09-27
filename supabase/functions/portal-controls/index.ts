import { admin, ApiError, json, requireUser, serve, sqlError } from '../_shared/http.ts';
Deno.serve(serve(async req => {
 if(req.method !== 'POST') throw new ApiError('method_not_allowed',405);
 const me=await requireUser(req), body=await req.json().catch(()=>null);
 if(!body || typeof body.action!=='string' || !body.data || typeof body.data!=='object' || Array.isArray(body.data)) throw new ApiError('invalid_request',400);
 const studentAction=['settings','report'].includes(body.action);
 if(!studentAction && !['admin','instructor'].includes(me.role)) throw new ApiError('staff_required',403);
 const {data,error}=await admin().rpc(studentAction?'portal_student_controls':'portal_manage',studentAction?{p_user:me.id,p_action:body.action,p_data:body.data}:{p_actor:me.id,p_action:body.action,p_data:body.data});
 if(error) throw sqlError(error);
 return json(data);
}));
