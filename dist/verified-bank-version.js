// Staff preview only. Reads use existing RLS; no grades, assignments or content writes.
function verifiedBankVersionMarkup(question){
 const id=question?.assets?.replacement_question_id;
 if(!question?.assets?.release_hold_reason||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id||''))return '';
 return '<p class="hint">This original remains held. A verified practice version is available.</p><button type="button" class="btn-sm" id="openVerifiedBankVersion">Open verified practice version</button><p id="verifiedVersionError" class="err" role="alert"></p>';
}
async function openVerifiedBankVersion(question){
 const id=question?.assets?.replacement_question_id;
 if(!question?.assets?.release_hold_reason||!verifiedBankVersionMarkup(question))throw new Error('No verified version is linked.');
 const {data,error}=await sb.from('questions').select('id,track_id,stem,choices,type,assets').eq('id',id).eq('track_id',question.track_id).single();
 if(error)throw error;
 if(!data||data.track_id!==question.track_id||data.assets?.release_hold_reason||String(data.assets?.bank_removed||'false').toLowerCase()==='true'||!data.assets?.verified_release)throw new Error('This practice version is currently unavailable for review.');
 const {data:key,error:keyError}=await sb.from('question_keys').select('correct,explanation').eq('question_id',id).single();
 if(keyError)throw keyError;
 if(!key?.explanation?.trim()||typeof key.correct!=='string'||data.type!=='mcq'||!data.choices?.some(c=>c.key===key.correct))throw new Error('This practice version needs answer review.');
 if($('editor').open)$('editor').close();
 return openTeachingExam({title:'Verified practice version',question_ids:[id]});
}
