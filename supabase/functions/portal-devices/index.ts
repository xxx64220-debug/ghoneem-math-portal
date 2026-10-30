import {admin,ApiError,json,requireIdentity,serve,sqlError} from '../_shared/http.ts';

// Recovery must verify identity without requiring prior device approval.
// The service-only SQL function limits pending sessions to their own device screen.
Deno.serve(serve(async req=>{
 if(req.method!=='POST') throw new ApiError('method_not_allowed',405);
 if(Number(req.headers.get('content-length')||0)>8192) throw new ApiError('request_too_large',413);
 const raw=await req.text();
 if(raw.length>8192) throw new ApiError('request_too_large',413);
 let body; try {body=JSON.parse(raw);} catch {throw new ApiError('invalid_request',400);}
 if(!body || !['register','list','approve','revoke','limit'].includes(body.action) || !body.data || typeof body.data!=='object' || Array.isArray(body.data)) throw new ApiError('invalid_request',400);
 const me=await requireIdentity(req);
 const {data,error}=await admin().rpc('portal_device_action',{p_user:me.id,p_session:me.sessionId,p_action:body.action,p_data:body.data,p_agent:req.headers.get('user-agent')||''});
 if(error) throw sqlError(error);
 return json(data,200,{'Cache-Control':'no-store'});
}));
