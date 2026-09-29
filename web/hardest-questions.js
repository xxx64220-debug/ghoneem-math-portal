/* Staff report data stays in memory only; RLS remains authoritative. */
(function(root){
  'use strict';
  function create(client,{pageSize=50,timeoutMs=15000,ttlMs=60000,now=Date.now}={}){
    const cache=new Map();
    let active=null;
    const columns='rank,track_id,lesson,question_id,stem,sources,answered_by,got_it_right,got_it_wrong,percent_correct';
    const abortError=()=>Object.assign(new Error('Request cancelled.'),{name:'AbortError'});
    function cancel(){if(active){active.abort();active=null;}}
    function clear(){cancel();cache.clear();}
    function invalidate(scope){for(const key of cache.keys())if(key.startsWith(JSON.stringify([scope.user,scope.track])+':'))cache.delete(key);}
    async function request(scope,offset,size,signal){
      if(signal.aborted)throw abortError();
      let query=client.from('question_difficulty').select(columns);
      if(scope.track)query=query.eq('track_id',scope.track);
      query=query.order('track_id',{ascending:true}).order('rank',{ascending:true}).order('question_id',{ascending:true}).range(offset,offset+size-1).abortSignal(signal);
      let onAbort;
      const cancelled=new Promise((_,reject)=>{onAbort=()=>reject(abortError());signal.addEventListener('abort',onAbort,{once:true});});
      try{
        const {data,error}=await Promise.race([query,cancelled]);
        if(error)throw error;
        if(signal.aborted)throw abortError();
        return data||[];
      }finally{signal.removeEventListener('abort',onAbort);}
    }
    async function run(work){
      cancel();const controller=new AbortController();active=controller;
      let timedOut=false;
      const timer=setTimeout(()=>{timedOut=true;controller.abort();},timeoutMs);
      try{return await work(controller.signal);}
      catch(error){if(timedOut)throw new Error('Loading took too long. Please try again.');throw error;}
      finally{clearTimeout(timer);if(active===controller)active=null;}
    }
    async function page(scope,offset=0,{refresh=false}={}){
      cancel();if(refresh)invalidate(scope);
      const key=JSON.stringify([scope.user,scope.track])+':'+offset;
      const hit=cache.get(key);
      if(hit&&now()-hit.at<ttlMs)return hit.value;
      return run(async signal=>{
        const data=await request(scope,offset,pageSize+1,signal);
        const value={rows:data.slice(0,pageSize),hasMore:data.length>pageSize,offset};
        cache.set(key,{at:now(),value});
        if(cache.size>20)cache.delete(cache.keys().next().value);
        return value;
      });
    }
    async function all(scope,onProgress=()=>{}){
      // Fetch every page only when explicitly exporting. Never export a partial failure.
      return run(async signal=>{
        const rows=[],size=500;
        for(let offset=0;;offset+=size){
          const data=await request(scope,offset,size,signal);rows.push(...data);onProgress(rows.length);
          if(data.length<size)return rows;
        }
      });
    }
    return {page,all,cancel,clear,pageSize};
  }
  const api={create};
  if(typeof module==='object'&&module.exports)module.exports=api;
  else root.HardestQuestions=api;
})(typeof globalThis!=='undefined'?globalThis:this);
