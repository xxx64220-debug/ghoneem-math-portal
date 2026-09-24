import {serve,json,requireAdmin,admin,ApiError} from '../_shared/http.ts';
Deno.serve(serve(async req=>{
 if(req.method!=='POST')throw new ApiError('method_not_allowed',405);
 const me=await requireAdmin(req);
 let body: {user_id?:unknown;confirmation?:unknown};
 try{body=await req.json();}catch{throw new ApiError('invalid_request',400);}
 if(!body || typeof body.user_id!=='string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.user_id) || typeof body.confirmation!=='string')throw new ApiError('invalid_request',400);
 const {data,error}=await admin().rpc('portal_delete_user',{p_actor:me.id,p_target:body.user_id,p_confirmation:body.confirmation});
 if(error){const allowed=['admin_required','protected_account','confirmation_mismatch','user_not_found'];throw new ApiError(allowed.includes(error.message)?error.message:'delete_failed',400);}
 return json(data);
}));
