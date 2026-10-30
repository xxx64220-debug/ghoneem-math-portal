const {PGlite}=require('./june-review-runtime/node_modules/@electric-sql/pglite');
const fs=require('node:fs'),assert=require('node:assert/strict'),id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
(async()=>{
 const db=new PGlite();let checks=0;const ok=(v,m)=>{assert(v,m);checks++;};
 const read=f=>fs.readFileSync(f,'utf8'),one=async(q,p=[])=>Object.values((await db.query(q,p)).rows[0])[0];
 for(const f of ['tests/00_shim.sql','supabase/migrations/001_schema.sql'])await db.exec(read(f).replace('create extension if not exists pgcrypto;',''));
 await db.exec("alter table profiles add column email text;alter table enrollments add column starts_at timestamptz,add column ends_at timestamptz,add column course_label text default '',add column payment_status text default 'unrecorded';");
 const builder=read('supabase/migrations/007_exam_builder.sql');await db.exec(builder.slice(builder.indexOf('create or replace function public.default_group'),builder.indexOf('--',builder.indexOf('end $$;',builder.indexOf('create or replace function public.enrol_student')))));
 await db.exec(read('supabase/sql/student_registration.sql'));
 await db.exec("insert into tracks(id,name) values('sat','SAT Math'),('est','EST Math');insert into groups(track_id,name) values('sat','SAT Math — all students');");
 for(const [n,role] of [[1,'admin'],[2,'instructor']]){await db.query('insert into auth.users(id,email) values($1,$2)',[id(n),n+'@test.invalid']);await db.query('insert into profiles(id,role) values($1,$2)',[id(n),role]);}
 await db.query("insert into groups(id,track_id,name) values($1,'sat','November'),($2,'est','Alex')",[id(10),id(11)]);
 for(const n of [3,4,5]){await db.query('insert into auth.users(id,email) values($1,$2)',[id(n),n+'@test.invalid']);await db.query('select registration_complete($1,$2,$3)',[id(n+100),id(n),JSON.stringify({username:'test.user'+n,full_name:'Synthetic Student '+n,email:n+'@test.invalid',track_id:'sat'})]);}
 await db.query('insert into auth.users(id,email) values($1,$2)',[id(6),'6@test.invalid']);
 for(const [request,user,username] of [[106,6,'test.user3'],[103,6,'another.name']]){
  await assert.rejects(()=>db.query('select registration_complete($1,$2,$3)',[id(request),id(user),JSON.stringify({username,full_name:'Duplicate Student',email:'duplicate@test.invalid',track_id:'sat'})]),/duplicate key/);checks++;
 }
 ok(await one('select count(*)::int from profiles where id=$1',[id(6)])===0,'Rejected duplicate leaves no new profile');
 ok(await one('select count(*)::int from student_registration_requests')===3,'Duplicate submissions preserve three original requests');
 ok(await one("select count(*)::int from profiles where status='suspended'")===3,'Pending accounts suspended');ok(await one('select count(*)::int from enrollments')===0,'No access before approval');
 const approve={decision:'approved',track_id:'sat',group_id:id(10),starts_at:'2030-01-01T00:00:00Z',ends_at:'2030-11-30T00:00:00Z'};
 await assert.rejects(()=>db.query('select registration_review($1,$2,$3)',[id(2),id(103),JSON.stringify(approve)]),/admin_required/);checks++;
 await assert.rejects(()=>db.query('select registration_review($1,$2,$3)',[id(1),id(103),JSON.stringify({...approve,group_id:id(11)})]),/group_course_mismatch/);checks++;
 ok(await one('select count(*)::int from enrollments')===0,'Invalid group rolled back');
 await assert.rejects(()=>db.query('select registration_review($1,$2,$3)',[id(1),id(103),JSON.stringify({...approve,ends_at:'2020-01-01'})]),/end_must_follow_start/);checks++;
 await db.query('select registration_review($1,$2,$3)',[id(1),id(103),JSON.stringify(approve)]);
 ok(await one('select status from profiles where id=$1',[id(3)])==='active','Approved account active');
 ok(await one('select count(*)::int from group_members where user_id=$1',[id(3)])===2,'Teaching group and default cohort');
 ok(await one('select payment_status from enrollments where user_id=$1',[id(3)])==='unrecorded','No invented payment');
 ok(await one('select ends_at::text from enrollments where user_id=$1',[id(3)])==='2030-11-30 00:00:00+00','Dates applied');
 await db.query("update profiles set status='suspended' where id=$1",[id(3)]);await db.query('select registration_review($1,$2,$3)',[id(1),id(103),JSON.stringify(approve)]);
 ok(await one('select status from profiles where id=$1',[id(3)])==='suspended','Retry preserves later suspension');ok(await one('select count(*)::int from enrollments')===1,'Retry does not duplicate');
 await db.query('select registration_review($1,$2,$3)',[id(1),id(104),JSON.stringify({decision:'rejected'})]);await assert.rejects(()=>db.query('select registration_review($1,$2,$3)',[id(1),id(104),JSON.stringify(approve)]),/request_already_reviewed/);checks++;
 ok(await one('select status from profiles where id=$1',[id(4)])==='suspended','Rejected remains inactive');
 for(const role of ['anon','authenticated']){await db.exec('set role '+role);for(const q of ['select * from student_registration_requests',"select registration_rate_limit(repeat('a',64))",`select registration_review('${id(1)}','${id(105)}','{}')`,`select registration_complete('${id(106)}','${id(5)}','{}')`]){await assert.rejects(()=>db.exec(q),/permission denied/);checks++;}await db.exec('reset role');}
 for(let n=0;n<6;n++)ok(await one("select registration_rate_limit(repeat('a',64))"),'Bounded requests');ok(!(await one("select registration_rate_limit(repeat('a',64))")),'Rate limit');ok(await one('select count(*)::int from enrollments where user_id=$1',[id(5)])===0,'Other student untouched');console.log(checks+' registration database checks passed');await db.close();
})().catch(e=>{console.error(e);process.exit(1);});
