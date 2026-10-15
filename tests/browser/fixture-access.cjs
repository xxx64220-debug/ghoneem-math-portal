// Synthetic SDK boundary only. The actual portal code still calls its course RPC.
// Unknown RPC names fail closed; this helper never reaches a real backend.
function withCourseAccess(sdk){
 const marker='return {auth:';
 if(!sdk.includes(marker))throw new Error('Synthetic SDK return boundary missing');
 return sdk.replace(marker,`return {rpc:async(name)=>{
  if(name!=='my_course_access')throw new Error('Unexpected fixture RPC: '+name);
  window.fixtureAccessReads=(window.fixtureAccessReads||0)+1;
  return {error:null,data:['sat','est','est2','est_eng'].map(track_id=>({track_id,status:'active',practice_open:true,can_finish:false,starts_at:null,ends_at:null,course_label:'Synthetic '+track_id}))};
 },auth:`);
}
module.exports={withCourseAccess};
