"""Preserve all949 original crops in a staff-only review archive.

Images use AES-256-GCM; only ciphertext is published. Per-image keys and worked
answers live in an RLS-protected table and this PRIVATE source directory.
"""
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import json,os,base64,hashlib,shutil
root=Path(__file__).resolve().parents[1];out=root/'content/est-september-2026'
scratch=Path('/workspace/scratch/861668d2e749')
cat=json.loads((root/'content/est-banks-2026/catalogue.json').read_text())
review={q['code']:q for q in json.loads((out/'source-review.json').read_text())}
questions=json.loads((root/'content/est-banks-2026/reviewed-bank.json').read_text())['questions']+json.loads((out/'release-bank.json').read_text())['questions']
published={q['assets']['source_code']:q for q in questions}
prior=json.loads((out/'review-archive.json').read_text()) if (out/'review-archive.json').exists() else []
old={r['id']:r for r in prior};items=[];canonical={}
public=root/'web/exams/est-review-encrypted';public.mkdir(parents=True,exist_ok=True)
for c in cat:
 code=c['code'];identity=c['source']+':'+code;v=review.get(code,{})
 dup=canonical.setdefault(c['image_sha256'],code)
 duplicate=v.get('semantic_duplicate_of') or (dup if dup!=code else None)
 q=published.get(code)
 status='ready' if q else 'duplicate' if duplicate else 'excluded' if c['review_status']=='excluded' else v.get('status','unreviewed')
 # Existing worked notes are explicitly provisional unless linked to a finished question.
 note=q['explanation'] if q else v.get('release_hold_reason') or v.get('explanation') or c.get('explanation') or ''
 answer=q['correct'] if q else v.get('answer')
 p=scratch/'est-source-crops'/c['image'];original=p.read_bytes()
 assert hashlib.sha256(original).hexdigest()==c['image_sha256']
 previous=old.get(identity)
 if previous and previous['image_sha256']==c['image_sha256']:
  key=base64.b64decode(previous['image_key_base64']);iv=base64.b64decode(previous['image_iv_base64'])
 else:key=AESGCM.generate_key(bit_length=256);iv=os.urandom(12)
 encrypted=AESGCM(key).encrypt(iv,original,identity.encode())
 target=public/(hashlib.sha256(identity.encode()).hexdigest()+'.bin')
 target.write_bytes(encrypted)
 assert AESGCM(key).decrypt(iv,encrypted,identity.encode())==original
 items.append({'id':identity,'track_id':'est','source_document':'EST_I_Math_Questions_by_Topic-2.pdf' if c['source']=='topic' else 'Math_Question_Bank_Ghoneem_Clean.pdf',
 'source_code':code,'source_page':c['page'],'source_section':c['domain'],'review_status':status,
 'source_text':c.get('ocr_review_only') or c.get('text') or '', 'review_note':note,
 'worked_answer':answer or None,'question_id':q['id'] if q else None,'duplicate_of':duplicate,
 'image_path':'/exams/est-review-encrypted/'+target.name,
 'image_key_base64':base64.b64encode(key).decode(),'image_iv_base64':base64.b64encode(iv).decode(),'image_sha256':c['image_sha256']})
assert len(items)==949 and len({r['id'] for r in items})==949
(out/'review-archive.json').write_text(json.dumps(items,ensure_ascii=False,indent=2))
for start in range(0,len(items),100):
 data="'"+json.dumps(items[start:start+100],ensure_ascii=False,separators=(',',':')).replace("'","''")+"'::jsonb"
 sql=f"""insert into public.est_source_review(id,track_id,source_document,source_code,source_page,source_section,review_status,source_text,review_note,worked_answer,question_id,duplicate_of,image_path,image_key_base64,image_iv_base64,image_sha256)
 select * from jsonb_to_recordset({data}) as r(id text,track_id text,source_document text,source_code text,source_page int,source_section text,review_status text,source_text text,review_note text,worked_answer jsonb,question_id uuid,duplicate_of text,image_path text,image_key_base64 text,image_iv_base64 text,image_sha256 text)
 on conflict(id) do nothing;
 select count(*) as archived_entries from public.est_source_review;
"""
 (out/f'import-review-{start//100+1:02}.sql').write_text(sql)
shutil.copytree(public,root/'dist/exams/est-review-encrypted',dirs_exist_ok=True)
print('Prepared949 staff-only source records and authenticated-encryption-verified images. No plaintext keys in public assets.')
