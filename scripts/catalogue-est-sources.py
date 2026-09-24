"""Preserve source questions; OCR is a review aid, never an answer key."""
from pathlib import Path
import hashlib, json, re, subprocess
from concurrent.futures import ThreadPoolExecutor
import fitz

ROOT=Path(__file__).resolve().parents[1]
UPLOAD=Path('/workspace/scratch/861668d2e749/upload')
OUT=ROOT/'content/est-banks-2026'
ASSETS=ROOT/'web/exams/est-banks-2026'
OUT.mkdir(parents=True,exist_ok=True)
ASSETS.mkdir(parents=True,exist_ok=True)
SOURCES=[('topic','EST_I_Math_Questions_by_Topic-2.pdf',r'(?:FA|DAP|AAF|GT) \d{3}'),('clean','Math_Question_Bank_Ghoneem_Clean.pdf',r'(?:HOA|PSD|PAM|GTC|MIX) \d{3}')]
records=[]
for source,filename,pattern in SOURCES:
    doc=fitz.open(UPLOAD/filename)
    for page in doc:
        lines=[]
        for block in page.get_text('dict')['blocks']:
            for line in block.get('lines',[]):
                if abs(line['dir'][1])>.01: continue
                txt=''.join(s['text'] for s in line['spans']).strip()
                if txt: lines.append((fitz.Rect(line['bbox']),txt))
        codes=[(r,t) for r,t in lines if r.y0>50 and re.fullmatch(pattern,t)]
        images=page.get_image_info(xrefs=True)
        for i,(rect,code) in enumerate(codes):
            bottom=codes[i+1][0].y0 if i+1<len(codes) else page.rect.height-45
            slug=source+'-'+code.replace(' ','-').lower()
            target=ASSETS/(slug+'.png')
            text='\n'.join(t for r,t in lines if r.y0>=rect.y0-.1 and r.y1<bottom and r.y0<page.rect.height-45)
            if source=='clean':
                matches=[im for im in images if im['bbox'][1]>=rect.y0 and im['bbox'][1]<bottom]
                if len(matches)!=1: raise ValueError((code,len(matches)))
                pix=fitz.Pixmap(doc,matches[0]['xref'])
                if pix.n>4: pix=fitz.Pixmap(fitz.csRGB,pix)
                pix.save(target)
            else:
                page.get_pixmap(matrix=fitz.Matrix(2,2),clip=fitz.Rect(42,rect.y0-2,page.rect.width-36,bottom-2)).save(target)
            records.append(dict(source=source,code=code,domain=code.split()[0],page=page.number+1,
                image=target.name,image_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),text=text,
                review_status='pending',correct=None,explanation=None))
    print(source, sum(r['source']==source for r in records),flush=True)
assert len(records)==949,len(records)
(OUT/'catalogue.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
def ocr(r):
    if r['source']=='clean':
        result=subprocess.run(['tesseract',str(ASSETS/r['image']),'stdout','--psm','3'],capture_output=True,text=True,env={**__import__('os').environ,'OMP_THREAD_LIMIT':'1'})
        r['ocr_review_only']=result.stdout
    return r
with ThreadPoolExecutor(max_workers=4) as pool:
    records=list(pool.map(ocr,records))
(OUT/'catalogue.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
print('Catalogued',len(records),'entries; no keys inferred.',flush=True)
