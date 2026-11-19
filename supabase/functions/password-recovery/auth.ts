// Matches deployed administrator/session checks without enabling the staged MFA pilot.
import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.50.0';
export class ApiError extends Error { status:number;constructor(message:string,status=400){super(message);this.status=status;} }
export const admin=()=>createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
export async function requireAdmin(req:Request){
 const authorization=req.headers.get('authorization')||'';
 if(!authorization.startsWith('Bearer '))throw new ApiError('signed_out',401);
 const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:authorization}},auth:{persistSession:false}});
 const {data,error}=await client.auth.getUser();
 if(error||!data?.user)throw new ApiError('signed_out',401);
 const db=admin(),profile=await db.from('profiles').select('id,role,status').eq('id',data.user.id).single();
 if(profile.error||profile.data?.role!=='admin'||profile.data.status!=='active')throw new ApiError('forbidden',403);
 let session:string;try{session=JSON.parse(atob(authorization.slice(7).split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).session_id;}catch{throw new ApiError('signed_out',401);}
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(session||''))throw new ApiError('signed_out',401);
 const checked=await db.rpc('portal_session',{p_user:data.user.id,p_session:session,p_agent:req.headers.get('user-agent')||''});
 if(checked.error)throw new ApiError('session_unavailable',403);
 return {id:data.user.id};
}
