const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ctx={console,ST:{track:{id:'est'}},DASH:{view:'revision'},esc:s=>String(s??'').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;'),figure:()=>'',friendly:x=>x,paintDashboardContent(){},document:{querySelector(){return null},querySelectorAll(){return[]},getElementById(){return null}}};
vm.createContext(ctx);vm.runInContext(fs.readFileSync('web/final-revision.js','utf8'),ctx);
const run=s=>vm.runInContext(s,ctx);
run("resetRevision('est');REV.data={items:[{id:'a',lesson:'Linear equations',idea:'Solving',source:'est',programmes:['est','sat'],difficulty:'easy'},{id:'b',lesson:'Statistics',idea:'Sampling',source:'sat',programmes:['sat'],difficulty:'hard'}]}");
assert.equal(run('revisionRows().length'),1);
run("REV.scope='both'");assert.equal(run('revisionRows().length'),2);
run("REV.source='sat'");assert.equal(run('revisionRows()[0].id'),'b');
assert.match(run('revisionPanel()'),/Final revision/);
assert.match(run('revisionText(String.raw`$\\\\frac{1}{2}$`)'),/\\frac/);
assert.match(run("revisionText('Admission costs $8.50 for each student and $12 for each adult.','sat')"),/revision-currency/);
assert.equal(run("revisionText('$9x+4=67$','sat')"),'$9x+4=67$');
run("REV.session={id:'s',questions:[{id:'q',lesson:'Polynomials',idea:'Roots',difficulty:'medium',source:'sat',type:'grid_in',stem:'Solve',response:'16',feedback:{correct:true,answer:['10','16'],explanation:'Either root is valid.'}}]}");
assert.match(run('revisionSessionPanel()'),/Set complete: 1\/1 correct/);
assert.match(run('revisionSessionPanel()'),/10 or 16/);
assert.doesNotMatch(run('revisionSessionPanel()'),/Retry mistakes/);
// A delayed old-track reply cannot contaminate the newly selected track.
(async()=>{
 let release;ctx.fn=()=>new Promise(r=>release=r);
 const promise=run("revisionRequest('catalogue')");
 run("ST.track={id:'sat'};resetRevision('sat')");
 release({ok:true,json:{items:['old-track']}});assert.equal(await promise,null);
 console.log('PASS: revision filters, numeric feedback, rendering and stale-track response isolation.');
})().catch(e=>{console.error(e);process.exitCode=1;});
