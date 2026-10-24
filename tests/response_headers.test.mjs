import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {createPortalHandler,securityHeaders} from '../hosting/portal-response.mjs';
const source=fs.existsSync('portal-static')?'portal-static':'dist';
const types={'.html':'text/html; charset=utf-8','.js':'application/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.webmanifest':'application/manifest+json','.json':'application/json'};
const assets={};
function load(dir){for(const name of fs.readdirSync(dir)){const p=path.join(dir,name);if(fs.statSync(p).isDirectory()){if(!name.startsWith('.'))load(p);continue;}const type=types[path.extname(p)];if(!type)continue;const raw=fs.readFileSync(p);assets['/'+path.relative(source,p).split(path.sep).join('/')]={body:raw.toString('utf8'),type,etag:'\"'+crypto.createHash('sha256').update(raw).digest('hex')+'\"'};}}
load(source);
const handlePortalRequest=createPortalHandler(assets);
function secure(response){for(const [k,v]of Object.entries(securityHeaders))assert.equal(response.headers.get(k),v,k);}
test('all text routes preserve deployed bytes, MIME types, HEAD and five response protections',async()=>{
 for(const [path,asset]of Object.entries(assets)){
  const expected=fs.readFileSync(source+path);
  const r=await handlePortalRequest(new Request('https://portal.example'+path));secure(r);assert.equal(r.status,200,path);assert.deepEqual(Buffer.from(await r.arrayBuffer()),expected,path);assert.equal(r.headers.get('Content-Type'),asset.type);
  const head=await handlePortalRequest(new Request('https://portal.example'+path,{method:'HEAD'}));secure(head);assert.equal(await head.text(),'');assert.equal(head.headers.get('etag'),asset.etag);
 }
});
test('root/admin aliases and conditional responses keep protections',async()=>{
 for(const path of ['/','/admin','/admin/']){const r=await handlePortalRequest(new Request('https://portal.example'+path));secure(r);assert.equal(r.status,200);}
 for(const tag of [assets['/index.html'].etag,'W/'+assets['/index.html'].etag,'*']){const r=await handlePortalRequest(new Request('https://portal.example/',{headers:{'If-None-Match':tag}}));secure(r);assert.equal(r.status,304);assert.equal(await r.text(),'');}
});
test('invalid paths, private paths and write methods fail closed',async()=>{
 for(const [url,status]of [['/%ZZ',400],['/.env',404],['/.git/config',404],['/constructor',404],['/toString',404],['/__proto__',404]]){const r=await handlePortalRequest(new Request('https://portal.example'+url));secure(r);assert.equal(r.status,status);}
 const r=await handlePortalRequest(new Request('https://portal.example/',{method:'POST',body:'ignored'}));secure(r);assert.equal(r.status,405);assert.equal(r.headers.get('Allow'),'GET, HEAD');
});
test('binary asset forwarding preserves bytes, MIME, status and cache metadata',async()=>{
 for(const method of ['GET','HEAD']){
  const r=await handlePortalRequest(new Request('https://portal.example/assets/test.png',{method}),{ASSETS:{fetch:async()=>new Response(new Uint8Array([1,2,3]),{headers:{'Content-Type':'image/png','Cache-Control':'public, max-age=3600',ETag:'"binary"'}})}});
  secure(r);assert.equal(r.headers.get('Content-Type'),'image/png');assert.equal(r.headers.get('ETag'),'"binary"');assert.deepEqual([...new Uint8Array(await r.arrayBuffer())],method==='HEAD'?[]:[1,2,3]);
 }
});
