const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {PGlite}=require('./device-runtime/node_modules/@electric-sql/pglite');
const root=path.resolve(__dirname,'..');
const release=path.join(root,'database-releases/20261115_outage_prevention');
const manifest=JSON.parse(fs.readFileSync(path.join(release,'before.json'),'utf8'));
const jobs=JSON.parse(fs.readFileSync(path.join(release,'jobs-before.json'),'utf8'));
const upgrade=fs.readFileSync(path.join(release,'upgrade.sql'),'utf8');
const rollback=fs.readFileSync(path.join(release,'rollback.sql'),'utf8');
test('recorded production migration matches the tested release',()=>{
 assert.equal(fs.readFileSync(path.join(root,'supabase/migrations/20261115175643_portal_outage_prevention.sql'),'utf8'),upgrade);
});
const tables=[...new Set(manifest.policies.map(p=>p.tablename))].sort();
const id=n=>'10000000-0000-0000-0000-'+String(n).padStart(12,'0');
const qi=s=>'"'+s.replaceAll('"','""')+'"';
const policySQL=p=>`create policy ${qi(p.policyname)} on ${qi(p.tablename)} as ${p.permissive} for ${p.cmd} to authenticated${p.qual?' using ('+p.qual+')':''}${p.with_check?' with check ('+p.with_check+')':''};`;
const scalar=async(db,sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function policies(db){return (await db.query("select schemaname,tablename,policyname,permissive,roles::text as roles,cmd,qual,with_check from pg_policies where policyname=any($1::text[]) order by tablename,policyname",[manifest.policies.map(p=>p.policyname)])).rows;}
async function login(db,user,allowed=true){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('test.session_allowed',$2,false)",[user==null?'':id(user),String(allowed)]);await db.exec('set role authenticated');}
async function seed(db){
 await db.exec(fs.readFileSync(path.join(__dirname,'outage-prevention-fixture.sql'),'utf8'));
 for(const [n,role,status] of [[1,'student','active'],[2,'student','active'],[3,'student','active'],[4,'student','suspended'],[5,'instructor','active'],[6,'instructor','active'],[7,'admin','active']])await db.query('insert into profiles values($1,$2,$3)',[id(n),role,status]);
 await db.exec("insert into tracks values('sat'),('est1'),('est2')");
 for(const [u,t,s] of [[1,'sat','active'],[2,'est1','active'],[3,'sat','expired'],[4,'sat','active']])await db.query('insert into enrollments values($1,$2,$3)',[id(u),t,s]);
 for(const [u,t] of [[5,'sat'],[6,'est1']])await db.query('insert into instructor_tracks values($1,$2)',[id(u),t]);
 await db.query("insert into groups values($1,'sat',$2),($3,'est1',$4)",[id(101),id(5),id(102),id(6)]);
 for(const [g,u] of [[101,1],[101,3],[102,2]])await db.query('insert into group_members values($1,$2)',[id(g),id(u)]);
 for(const [e,t,p] of [[201,'sat',true],[202,'est1',true],[203,'sat',false],[204,'sat',true]])await db.query('insert into exams values($1,$2,$3)',[id(e),t,p]);
 await db.query('insert into assignments values($1,$2,$3,null),($4,$5,$6,null),($7,$8,null,$9)',[id(301),id(201),id(101),id(302),id(202),id(102),id(303),id(203),id(1)]);
 for(const [a,u,e,status,deadline,review] of [[401,1,201,'in_progress','1 hour',null],[402,2,202,'in_progress','1 hour',null],[403,1,201,'in_progress','-1 hour',null],[404,1,201,'graded','-1 hour','-1 hour'],[405,1,201,'graded','-1 hour','1 hour'],[406,3,201,'graded','-1 hour',null]]){
  await db.query("insert into attempts values($1,$2,$3,$4,now()+$5::interval,case when $6::text is null then null else now()+$6::interval end)",[id(a),id(u),id(e),status,deadline,review]);
  await db.query('insert into attempt_answers values($1,$2,$3)',[id(a),id(501),'original']);
  await db.query('insert into attempt_results values($1,$2,true)',[id(a),id(501)]);
 }
 for(const [n,u,e] of [[601,1,201],[602,2,202]])await db.query('insert into retake_grants values($1,$2,$3)',[id(n),id(u),id(e)]);
 for(const [n,u] of [[701,1],[702,2]])await db.query('insert into device_sessions values($1,$2,$3)',[id(n),id(u),'saved']);
 for(const [n,u,t,g] of [[801,1,'sat',101],[802,2,'est1',102],[803,3,'sat',null]])await db.query('insert into daily_progress values($1,$2,$3,$4)',[id(n),id(u),t,g?id(g):null]);
 for(const t of tables){await db.exec(`alter table ${qi(t)} enable row level security; create policy session_gate on ${qi(t)} as restrictive for all to authenticated using(portal_private.current_session_allowed()) with check(portal_private.current_session_allowed());`);}
 for(const p of manifest.policies)await db.exec(policySQL(p));
 for(const j of jobs)await db.query('insert into cron.job values($1,$2,$3,$4,$5,$6,$7)',[j.jobid,j.jobname,j.schedule,j.command,j.database,j.username,j.active]);
}
async function readMatrix(db){
 const out={};
 for(const user of [null,1,2,3,4,5,6,7])for(const allowed of [true,false]){
  await login(db,user,allowed);
  for(const table of tables){const rows=(await db.query('select * from '+qi(table))).rows;out[`${user}:${allowed}:${table}`]=rows.map(r=>JSON.stringify(r)).sort();}
 }
 await db.exec('reset role');return out;
}
async function writes(db){
 const cases=[
  ['own live insert',true,'insert into attempt_answers values($1,$2,$3)',[id(401),id(502),'new']],
  ['foreign insert',false,'insert into attempt_answers values($1,$2,$3)',[id(402),id(502),'new']],
  ['expired insert',false,'insert into attempt_answers values($1,$2,$3)',[id(403),id(502),'new']],
  ['own live update',true,'update attempt_answers set response=$1 where attempt_id=$2 and question_id=$3',['changed',id(401),id(501)]],
  ['move answer to foreign attempt',false,'update attempt_answers set attempt_id=$1 where attempt_id=$2 and question_id=$3',[id(402),id(401),id(501)]],
  ['own device',true,'insert into device_sessions values($1,$2,$3)',[id(703),id(1),'new']],
  ['foreign device',false,'insert into device_sessions values($1,$2,$3)',[id(703),id(2),'new']]
 ];
 const out={};
 for(const [name,expected,sql,args] of cases){
  await login(db,1);await db.exec('begin');let ok=true;
  try{const result=await db.query(sql,args);if(name==='own live update')assert.equal(result.affectedRows,1);}catch(e){ok=false;assert.match(String(e),/row-level security/);}
  await db.exec('rollback');assert.equal(ok,expected,name);out[name]=ok;
 }
 await login(db,1,false);await assert.rejects(db.query('insert into attempt_answers values($1,$2,$3)',[id(401),id(502),'blocked']),/row-level security/);
 await db.exec('reset role;set role anon');await assert.rejects(db.query('select * from attempts'),/permission denied/);await db.exec('reset role');
 return out;
}
async function allRows(db){await db.exec('reset role');const out={};for(const table of tables)out[table]=(await db.query('select * from '+qi(table))).rows.map(JSON.stringify).sort();return out;}
test('outage prevention preserves authorization, business rows, job behavior and atomic drift guards',async t=>{
 const db=new PGlite();
 try{
  await seed(db);
  const initialPolicies=await policies(db),initialRows=await allRows(db);
  assert.equal(initialPolicies.length,16);
  const beforeReads=await readMatrix(db),beforeWrites=await writes(db);
  await t.test('existing ownership, course, instructor and review restrictions have distinct results',()=>{
   assert.equal(beforeReads['1:true:profiles'].length,1);
   assert.equal(beforeReads['7:true:profiles'].length,7);
   assert.notDeepEqual(beforeReads['5:true:attempts'],beforeReads['6:true:attempts']);
   assert.equal(beforeReads['1:false:attempts'].length,0);
   assert.equal(beforeReads['1:true:attempt_results'].length,1);
  });
  await t.test('policy drift fails before deployment',async()=>{
   await db.exec('begin;alter policy profiles_self_read on profiles using(true)');
   await assert.rejects(db.exec(upgrade),/Policy changed since audit/);await db.exec('rollback');
   assert.deepEqual(await policies(db),initialPolicies);
  });
  await t.test('cron drift rolls back the preceding policy edits',async()=>{
   await db.exec("begin;update cron.job set schedule='*/2 * * * *' where jobid=2");
   await assert.rejects(db.exec(upgrade),/Cron job changed since audit/);await db.exec('rollback');
   assert.deepEqual(await policies(db),initialPolicies);
  });
  await db.exec(upgrade);
  await t.test('all 224 read combinations and insert/update denials remain equivalent',async()=>{
   assert.deepEqual(await readMatrix(db),beforeReads);assert.deepEqual(await writes(db),beforeWrites);
  });
  await t.test('all policy roles, commands and permissive flags remain unchanged',async()=>{
   const after=await policies(db);for(let i=0;i<after.length;i++){for(const k of ['schemaname','tablename','policyname','permissive','roles','cmd'])assert.deepEqual(after[i][k],initialPolicies[i][k]);}
  });
  await t.test('the planner caches the identity lookup in an InitPlan',async()=>{
   await login(db,1);const plan=await db.query('explain select * from profiles');assert.match(JSON.stringify(plan.rows),/InitPlan/);await db.exec('reset role');
  });
  await t.test('each job keeps its schedule and command with limits active before execution',async()=>{
   const after=(await db.query('select * from cron.job order by jobid')).rows;
   for(let i=0;i<jobs.length;i++){
    const a=after[i],b=jobs[i];for(const k of ['jobname','schedule','database','username','active'])assert.equal(a[k],b[k]);
    assert.ok(a.command.endsWith(b.command));await db.exec(a.command);
   }
   assert.deepEqual((await db.query('select * from test_job_settings order by name')).rows,[
    {name:'push',statement_timeout:'10s',lock_timeout:'3s',idle_timeout:'30s'},
    {name:'sweep',statement_timeout:'30s',lock_timeout:'3s',idle_timeout:'30s'},
    {name:'weekly',statement_timeout:'30s',lock_timeout:'3s',idle_timeout:'30s'}]);
  });
  await t.test('no profiles, scores, answers, assignments or progress rows changed',async()=>assert.deepEqual(await allRows(db),initialRows));
  await t.test('duplicate application is rejected without partial edits',async()=>{
   const saved=await policies(db);await assert.rejects(db.exec(upgrade),/Policy changed since audit/);assert.deepEqual(await policies(db),saved);
  });
  await t.test('rollback restores exact policies, commands and authorization',async()=>{
   await db.exec(rollback);
   assert.deepEqual(await policies(db),initialPolicies);
   assert.deepEqual((await db.query('select * from cron.job order by jobid')).rows,jobs);
   assert.deepEqual(await readMatrix(db),beforeReads);
   assert.deepEqual(await writes(db),beforeWrites);
   await db.exec(upgrade);
  });
  await t.test('rollback refuses policy drift without partial edits',async()=>{
   const saved=await policies(db);
   await db.exec('begin;alter policy profiles_self_read on profiles using(true)');
   await assert.rejects(db.exec(rollback),/Policy changed since audit/);await db.exec('rollback');
   assert.deepEqual(await policies(db),saved);
  });
 }finally{await db.close();}
});
