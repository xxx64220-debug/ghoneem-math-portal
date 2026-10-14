import {serve,json,requireStaff,admin,ApiError} from '../_shared/http.ts';
Deno.serve(serve(async req=>{
 if(req.method!=='POST') throw new ApiError('method_not_allowed',405);
 const me=await requireStaff(req),b=await req.json();
 // Legacy roster replacement omitted paused students; use the guarded group editor.
 if(b.action==='group.save')throw new ApiError('group_editor_update_required_refresh_page',409);
 const {data,error}=await admin().rpc('portal_admin',{p_actor:me.id,p_action:b.action,p_data:b.data||{}});
 if(error) throw new ApiError(error.message,400);
 return json(data);
}));
