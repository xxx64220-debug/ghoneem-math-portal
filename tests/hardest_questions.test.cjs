const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const {create}=require('../web/hardest-questions.js');
const scope={user:'admin',track:'sat'};
function mock(handler){
  const calls=[];
  return {calls,from(table){const call={table,orders:[]};calls.push(call);return {
    select(columns){call.columns=columns;return this;},eq(k,v){call[k]=v;return this;},
    order(k){call.orders.push(k);return this;},range(a,b){call.range=[a,b];return this;},abortSignal(s){call.signal=s;return this;},
    then(resolve,reject){return Promise.resolve().then(()=>handler(call)).then(resolve,reject);}
  };}};
}
function data(count,offset=0){return Array.from({length:count},(_,i)=>({question_id:'q'+(i+offset),rank:i+offset+1,track_id:'sat'}));}
test('first paint uses 50 rows and a lookahead, stable ordering, and selected track',async()=>{
  for(const track of ['sat','est','est2','']){
    const sb=mock(()=>({data:data(51)})),report=create(sb);
    const page=await report.page({...scope,track});
    assert.equal(page.rows.length,50);assert.equal(page.hasMore,true);
    assert.deepEqual(sb.calls[0].range,[0,50]);
    assert.deepEqual(sb.calls[0].orders,['track_id','rank','question_id']);
    assert.equal(sb.calls[0].track_id,track||undefined);
    assert(!sb.calls[0].columns.includes('assets'));assert.equal(sb.calls.length,1);
    await report.page({...scope,track},50);assert.deepEqual(sb.calls[1].range,[50,100]);
  }
});
test('cache is bounded by user and track, expires, and refresh invalidates all pages',async()=>{
  let time=0;const sb=mock(()=>({data:data(1)})),report=create(sb,{now:()=>time,ttlMs:60});
  await report.page(scope);await report.page(scope);assert.equal(sb.calls.length,1);
  await report.page({...scope,track:'est'});await report.page({...scope,user:'other'});assert.equal(sb.calls.length,3);
  time=61;await report.page(scope);assert.equal(sb.calls.length,4);
  await report.page(scope,50);await report.page(scope,0,{refresh:true});await report.page(scope,50);assert.equal(sb.calls.length,7);
  report.clear();await report.page(scope);assert.equal(sb.calls.length,8);
});
test('slow old requests are cancelled and cannot pollute cache',async()=>{
  let release;const sb=mock(call=>call.track_id==='sat'?new Promise(r=>release=r):({data:data(1)}));
  const report=create(sb),first=report.page(scope);const rejected=assert.rejects(first,{name:'AbortError'});
  await new Promise(r=>setImmediate(r));
  const second=await report.page({...scope,track:'est'});await rejected;
  assert.equal(second.rows.length,1);assert(sb.calls[0].signal.aborted);
  release({data:data(51)});await new Promise(r=>setImmediate(r));report.clear();
});
test('network errors and timeouts remain retryable, never fake an empty success',async()=>{
  let fail=true;const sb=mock(()=>fail?{error:new Error('offline')}:{data:[]}),report=create(sb);
  await assert.rejects(report.page(scope),/offline/);fail=false;
  assert.equal((await report.page(scope)).rows.length,0);assert.equal(sb.calls.length,2);
  const hanging=create(mock(()=>new Promise(()=>{})),{timeoutMs:10});
  await assert.rejects(hanging.page(scope),/took too long/);
});
test('exports include every page past 1000 rows and reject partial results',async()=>{
  const sb=mock(call=>({data:data(Math.min(500,1201-call.range[0]),call.range[0])})),report=create(sb);
  const rows=await report.all(scope);assert.equal(rows.length,1201);assert.equal(new Set(rows.map(x=>x.question_id)).size,1201);
  assert.deepEqual(sb.calls.map(x=>x.range),[[0,499],[500,999],[1000,1499]]);
  const broken=create(mock(call=>call.range[0]?{error:new Error('lost connection')}:{data:data(500)}));
  await assert.rejects(broken.all(scope),/lost connection/);
});
test('late report completion cannot replace another section',async()=>{
  const html=fs.readFileSync('web/admin.html','utf8'),code=html.slice(html.indexOf('async function questions('),html.indexOf('\nasync function exams(){'));
  const nodes=new Map();const node=id=>{if(!nodes.has(id))nodes.set(id,{innerHTML:'',textContent:'',setAttribute(){}});return nodes.get(id);};
  let release;const ctx={ST:{me:{id:'admin'},view:'questions',track:'sat'},hardestRequest:0,hardestReport:{cancel(){},page(){return new Promise(r=>release=r);}},$:node};
  vm.createContext(ctx);vm.runInContext(code,ctx);const task=vm.runInContext('questions()',ctx);
  ctx.ST.view='students';node('view').innerHTML='Students';release({rows:data(1),hasMore:false});await task;
  assert.equal(node('view').innerHTML,'Students');assert.equal(node('hardRows').innerHTML,'');
});
