// Called by test_accounts_db.cjs using its disposable PostgreSQL fixture.
const fs=require('node:fs'),assert=require('node:assert/strict');
module.exports=async function({db,scalar,login,ok,admin,teacher,otherTeacher,student,outsider,tracks,qs,groups}){
 const sql=fs.readFileSync('supabase/sql/bank_usage_timeout.sql','utf8');
 await db.exec('begin');
 const cycles={};
 for(const track of tracks){
  await db.query("update questions set assets=assets||'{\"release_hold_reason\":\"Synthetic hold\"}' where id=$1",[qs[track][2]]);
  await db.query("update questions set assets=assets||'{\"bank_removed\":true}' where id=$1",[qs[track][3]]);
  await db.query("update question_keys set correct='{\"void\":true}' where question_id=$1",[qs[track][4]]);
  await db.query("insert into question_catalogue(question_id,reserve,reason,updated_by) values($1,true,'Synthetic reserve',$2)",[qs[track][5],admin]);
  await db.query("insert into daily_progress(user_id,track_id,day,quiz_completed_at,quiz_score,answers) values($1,$2,current_date-1,now()-interval '1 day',1,$3)",[student,track,JSON.stringify({[qs[track][0]]:'A'})]);
  await db.query("insert into daily_progress(user_id,track_id,day,quiz_completed_at,quiz_score,answers) values($1,$2,current_date-1,now()-interval '1 day',0,$3)",[outsider,track,JSON.stringify({[qs[track][0]]:'B'})]);
  cycles[track]=await scalar("insert into hardest_cycles(track_id,title,starts_at,ends_at) values($1,'Synthetic closed period',now()-interval '3 days',now()-interval '36 hours') returning id",[track]);
 }
 await db.query('update profiles set is_test=true where id=$1',[outsider]);
 const wrapper=await scalar("select pg_get_functiondef('public.staff_bank_operations(text,uuid,uuid,text,integer)'::regprocedure)");
 const acl=await scalar("select proacl::text from pg_proc where oid='portal_private.staff_bank_operations(text,uuid,uuid,text,integer)'::regprocedure");
 const filters=['all','unused','underused','hardest','held','pending','reserve'];
 const before=[];
 for(const user of [admin,teacher,otherTeacher]){
  await login(user);await db.exec('set local role authenticated');
  for(const track of tracks)for(const filter of filters){
   const args=[track,user===teacher?groups[track]:null,null,filter,0];
   before.push({user,args,result:await scalar('select public.staff_bank_operations($1,$2,$3,$4,$5)',args)});
  }
  await db.exec('reset role');
 }
 await login(admin);await db.exec('set local role authenticated');
 for(const track of tracks){
  for(const [cycle,page] of [[cycles[track],0],[null,1]]){
   const args=[track,null,cycle,'all',page];
   before.push({user:admin,args,result:await scalar('select public.staff_bank_operations($1,$2,$3,$4,$5)',args)});
  }
 }
 await db.exec('reset role');await db.exec(sql);
 // A pooled connection may already prefer generic plans. The function must
 // use its own custom plan and restore the caller's setting afterwards.
 await db.exec("set local plan_cache_mode='force_generic_plan'");
 for(const test of before){
  await login(test.user);await db.exec('set local role authenticated');
  assert.deepEqual(await scalar('select public.staff_bank_operations($1,$2,$3,$4,$5)',test.args),test.result);
  ok(true,'Bank report equality: '+test.args.join('/'));
  await db.exec('reset role');
 }
 ok(await scalar("select current_setting('plan_cache_mode')")==='force_generic_plan','Caller plan mode restored');
 ok((await scalar("select proconfig from pg_proc where oid='portal_private.staff_bank_operations(text,uuid,uuid,text,integer)'::regprocedure")).includes('plan_cache_mode=force_custom_plan'),'Function has scoped custom planning');
 ok(await scalar("select pg_get_functiondef('public.staff_bank_operations(text,uuid,uuid,text,integer)'::regprocedure)")===wrapper,'Public wrapper preserved');
 ok(await scalar("select proacl::text from pg_proc where oid='portal_private.staff_bank_operations(text,uuid,uuid,text,integer)'::regprocedure")===acl,'Execute permissions preserved');
 const scored=before.find(t=>t.user===admin&&t.args[0]==='sat'&&t.args[3]==='all').result;
 const question=scored.items.find(q=>q.id===qs.sat[0]);
 ok(question.unique_students===1&&question.responses===2&&question.first_success===0&&question.latest_success===100&&question.improved===1,'Real repeat improvement and test-account exclusion');
 await login(teacher);await db.exec('set local role authenticated');
 for(const args of [['sat',groups.est,null,'all',0],['sat',null,cycles.est,'all',0],['sat',null,null,'bad',0],['sat',null,null,'all',-1]]){
  await db.exec('savepoint denial');
  await assert.rejects(()=>db.query('select public.staff_bank_operations($1,$2,$3,$4,$5)',args),/group_scope_denied|cycle_track_mismatch|invalid_filter/);
  await db.exec('rollback to savepoint denial');ok(true,'Invalid scope/filter rejected');
 }
 await db.exec('reset role');await login(student);await db.exec('set local role authenticated;savepoint denial');
 await assert.rejects(()=>db.query("select public.staff_bank_operations('sat')"),/staff_required/);
 await db.exec('rollback to savepoint denial;reset role');ok(true,'Student report denied');
 await db.exec('rollback');
 // Run the rest of the established test-account suite against the new helper.
 await db.exec(sql);
 console.log(`PASS: ${before.length} complete bank reports identical before/after tuning.`);
};
