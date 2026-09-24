import {serve,json,requireUser,admin,sqlError,ApiError} from '../_shared/http.ts';
Deno.serve(serve(async req=>{
 if(req.method!=='POST') throw new ApiError('method_not_allowed',405);
 const me=await requireUser(req), b=await req.json();
 if(!b.attempt_id) throw new ApiError('attempt_id_required',400);
 const db=admin();
 const {error:limit}=await db.rpc('portal_rate_limit',{p_user:me.id,p_action:'submit'});
 if(limit) throw new ApiError('rate_limit_exceeded',429);
 const {data,error}=await db.rpc('portal_submit',{p_attempt:b.attempt_id,p_user:me.id,p_key:req.headers.get('Idempotency-Key')});
 if(error) throw sqlError(error);
 return json(data.body,data.status);
}));
