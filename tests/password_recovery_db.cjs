const {PGlite}=require('./june-review-runtime/node_modules/@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict');
const id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
(async()=>{
 const db=new PGlite();let checks=0;const ok=(v,m)=>{assert(v,m);checks++;},reject=async(q,p,re)=>{await assert.rejects(()=>db.query(q,p),re);checks++;},one=async(q,p=[])=>Object.values((await db.query(q,p)).rows[0])[0];
 for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql'])await db.exec(fs.readFileSync(f,'utf8').replace('create extension if not exists pgcrypto;',''));
 await db.exec('alter table profiles add column email text;');
 await db.exec(fs.readFileSync('supabase/migrations/20261119122819_student_password_recovery.sql','utf8'));
 for(const [n,role,status] of [[1,'admin','active'],[2,'instructor','active'],[3,'student','active'],[4,'student','suspended'],[5,'admin','suspended']]){
  await db.query('insert into auth.users(id,email) values($1,$2)',[id(n),'user'+n+'@students.ghoneem-math.com']);
  await db.query('insert into profiles(id,email,role,status,full_name) values($1,$2,$3,$4,$5)',[id(n),'user'+n+'@students.ghoneem-math.com',role,status,'Synthetic '+n]);
 }
 const before=JSON.stringify((await db.query('select * from profiles order by id')).rows);
 const submit=async(n,login)=>db.query('select password_recovery_submit($1,$2,$3,$4,$5,$6)',[id(n),login,login+'@students.ghoneem-math.com','Request name','', 'Test group']);
 await submit(100,'user3');await submit(101,'user3');await submit(100,'user3');
 ok(await one('select count(*)::int from password_recovery_requests')===1,'Duplicate requests collapse');
 for(const [n,login] of [[102,'missing'],[103,'user1'],[104,'user4']])await submit(n,login);
 ok(await one('select count(*)::int from password_recovery_requests where user_id is null')===3,'Unknown, staff and suspended do not match');
 for(const actor of [2,3,5])await reject('select password_recovery_review($1,$2,$3)',[id(actor),id(100),'approved'],/admin_required/);
 await reject('select password_recovery_issue_claim($1,$2,$3)',[id(1),id(100),id(900)],/approval_required/);
 for(const n of [102,103,104])await reject('select password_recovery_review($1,$2,$3)',[id(1),id(n),'approved'],/account_unavailable/);
 await db.query('select password_recovery_review($1,$2,$3)',[id(1),id(102),'rejected']);
 await reject('select password_recovery_review($1,$2,$3)',[id(1),id(102),'approved'],/already_reviewed/);
 await reject('select password_recovery_issue_claim($1,$2,$3)',[id(1),id(102),id(901)],/approval_required/);
 await db.query('select password_recovery_review($1,$2,$3)',[id(1),id(100),'approved']);
 await db.query('select password_recovery_review($1,$2,$3)',[id(1),id(100),'approved']);
 ok(await one("select count(*)::int from audit_log where action='password_recovery.approved'")===1,'Idempotent approval audit');
 const account=await one('select password_recovery_issue_claim($1,$2,$3)',[id(1),id(100),id(900)]);ok(account.user_id===id(3),'Claim targets existing account');
 await reject('select password_recovery_issue_claim($1,$2,$3)',[id(1),id(100),id(901)],/link_busy/);
 await reject('select password_recovery_issue_finish($1,$2,$3,true)',[id(1),id(100),id(901)],/link_busy/);
 await db.query('select password_recovery_issue_finish($1,$2,$3,false)',[id(1),id(100),id(900)]);
 ok(await one('select link_issued_at is null from password_recovery_requests where id=$1',[id(100)]),'Failed link records no success');
 await db.query('select password_recovery_issue_claim($1,$2,$3)',[id(1),id(100),id(901)]);
 await db.query('select password_recovery_issue_finish($1,$2,$3,true)',[id(1),id(100),id(901)]);
 ok(await one('select link_issued_at is not null from password_recovery_requests where id=$1',[id(100)]),'Successful link audit');
 await db.query("update profiles set status='suspended' where id=$1",[id(3)]);
 await reject('select password_recovery_issue_claim($1,$2,$3)',[id(1),id(100),id(902)],/account_unavailable/);
 await db.query("update profiles set status='active',email='changed@example.invalid' where id=$1",[id(3)]);
 await reject('select password_recovery_issue_claim($1,$2,$3)',[id(1),id(100),id(902)],/account_unavailable/);
 await db.query("update profiles set email='user3@students.ghoneem-math.com' where id=$1",[id(3)]);
 await db.query("update password_recovery_requests set reviewed_at=now()-interval '8 days' where id=$1",[id(100)]);
 await reject('select password_recovery_issue_claim($1,$2,$3)',[id(1),id(100),id(902)],/request_expired/);
 await submit(105,'user3');await db.query("update password_recovery_requests set created_at=now()-interval '8 days' where id=$1",[id(105)]);
 await reject('select password_recovery_review($1,$2,$3)',[id(1),id(105),'approved'],/request_expired/);
 for(const role of ['anon','authenticated']){
  await db.exec('set role '+role);
  for(const q of ['select * from password_recovery_requests','select * from portal_private.password_recovery_limits',"select password_recovery_rate_limit(repeat('a',64))",`select password_recovery_submit('${id(500)}','xxy','xxy@example.invalid','Test','','')`,`select password_recovery_review('${id(1)}','${id(105)}','approved')`,`select password_recovery_issue_claim('${id(1)}','${id(100)}','${id(902)}')`,`select password_recovery_issue_finish('${id(1)}','${id(100)}','${id(902)}',true)`])await reject(q,[],/permission denied/);
  await db.exec('reset role');
 }
 for(let n=0;n<10;n++)ok(await one("select password_recovery_rate_limit(repeat('a',64))"),'Rate quota accepts');
 ok(!await one("select password_recovery_rate_limit(repeat('a',64))"),'Rate quota blocks');
 ok(JSON.stringify((await db.query('select * from profiles order by id')).rows)===before,'Account identities and status preserved');
 ok(await one('select count(*)::int from enrollments')===0,'No enrollment changes');
 ok(await one("select count(*)::int from information_schema.columns where table_name='password_recovery_requests' and column_name in ('password','token','token_hash','access_token')")===0,'No passwords or tokens in request storage');
 console.log(checks+' password recovery database checks passed');await db.close();
})().catch(e=>{console.error(e);process.exitCode=1;});
