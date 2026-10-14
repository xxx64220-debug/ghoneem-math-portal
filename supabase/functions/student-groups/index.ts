// Bounded membership changes for a single student; supports future/paused subscriptions.
import {serve,json,requireStaff,admin,ApiError} from '../_shared/http.ts';
Deno.serve(serve(async req=>{
 if(req.method!=='POST')throw new ApiError('method_not_allowed',405);
 const me=await requireStaff(req),b=await req.json(),uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
 if(!uuid.test(b.user_id)||!Array.isArray(b.add)||!Array.isArray(b.remove)||b.add.length+b.remove.length>200
 ||[...b.add,...b.remove].some(x=>typeof x!=='string'||!uuid.test(x))||new Set([...b.add,...b.remove]).size!==b.add.length+b.remove.length)throw new ApiError('invalid_group_changes');
 const db=admin(),target=await db.from('profiles').select('id,role').eq('id',b.user_id).single();
 if(target.error||target.data?.role!=='student')throw new ApiError('student_required');
 const preferences=b.daily_groups??[];
 if(!Array.isArray(preferences)||preferences.length>32||preferences.some(p=>!p||typeof p.track_id!=='string'||!(/^[a-z0-9_]{2,16}$/).test(p.track_id)||(p.group_id!==null&&!uuid.test(p.group_id)))||new Set(preferences.map(p=>p.track_id)).size!==preferences.length)throw new ApiError('invalid_daily_groups');
 if(preferences.length&&me.role!=='admin')throw new ApiError('admin_required');
 const ids=[...new Set([...b.add,...b.remove,...preferences.map(p=>p.group_id).filter(Boolean)])];if(!ids.length&&!preferences.length)return json({added:0,removed:0});
 const [groups,courses]=await Promise.all([db.from('groups').select('id,track_id,instructor_id').in('id',ids),db.from('enrollments').select('track_id,daily_group_id,access_version').eq('user_id',b.user_id)]);
 if(groups.error||courses.error)throw new ApiError('could_not_read_group_setup');
 if(me.role==='instructor'&&groups.data.some(g=>g.instructor_id!==me.id))throw new ApiError('forbidden_group');
 if(groups.data.length!==ids.length)throw new ApiError('group_not_found');
 if(groups.data.some(g=>b.add.includes(g.id)&&!courses.data.some(e=>e.track_id===g.track_id)))throw new ApiError('group_course_mismatch');
 for(const g of groups.data.filter(g=>b.remove.includes(g.id))){const r=await db.rpc('default_group',{p_track:g.track_id});if(r.error)throw new ApiError('could_not_read_default_group');if(r.data===g.id)throw new ApiError('default_cohort_retained');}
 if(preferences.length){
  const membership=await db.from('group_members').select('group_id').eq('user_id',b.user_id);if(membership.error)throw new ApiError('could_not_read_group_setup');
  const resulting=new Set([...membership.data.map(m=>m.group_id),...b.add].filter(id=>!b.remove.includes(id)));
  for(const p of preferences){if(!courses.data.some(e=>e.track_id===p.track_id))throw new ApiError('group_course_mismatch');if(p.group_id!==null){if(!resulting.has(p.group_id)||!groups.data.some(g=>g.id===p.group_id&&g.track_id===p.track_id))throw new ApiError('daily_group_membership_or_track_mismatch');const d=await db.rpc('default_group',{p_track:p.track_id});if(d.error)throw new ApiError('could_not_read_default_group');if(d.data===p.group_id)throw new ApiError('default_cohort_retained');}}
 }
 if(b.add.length){const r=await db.from('group_members').upsert(b.add.map(group_id=>({group_id,user_id:b.user_id})),{onConflict:'group_id,user_id',ignoreDuplicates:true});if(r.error)throw new ApiError('could_not_add_groups');}
 if(b.remove.length){const r=await db.from('group_members').delete().eq('user_id',b.user_id).in('group_id',b.remove);if(r.error)throw new ApiError('could_not_remove_groups');}
 for(const p of preferences){if((courses.data.find(e=>e.track_id===p.track_id)?.daily_group_id??null)===p.group_id)continue;const r=await db.from('enrollments').update({daily_group_id:p.group_id}).eq('user_id',b.user_id).eq('track_id',p.track_id).select('track_id,daily_group_id,access_version').single();if(r.error)throw new ApiError('could_not_save_daily_group');}
 const audit=await db.from('audit_log').insert({actor_id:me.id,action:'student.groups_updated',target_type:'user',target_id:b.user_id,meta:{add:b.add,remove:b.remove,daily_groups:preferences}});
 if(audit.error)throw new ApiError('groups_saved_audit_pending');
 return json({added:b.add.length,removed:b.remove.length,daily_groups:preferences});
}));
