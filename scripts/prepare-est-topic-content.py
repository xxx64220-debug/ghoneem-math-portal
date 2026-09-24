"""Extract native question text and original figures, excluding editorial captions.

The topic PDF's small italic diagram descriptions contain transcription errors.
They are not source data. Original embedded diagrams are retained instead.
"""
from pathlib import Path
import json, re, fitz

ROOT = Path(__file__).resolve().parents[1]
DOC = fitz.open('/workspace/scratch/861668d2e749/upload/EST_I_Math_Questions_by_Topic-2.pdf')
OUT = ROOT/'content/est-banks-2026'
FIG = ROOT/'web/exams/est-banks-2026/figures'
FIG.mkdir(parents=True, exist_ok=True)
records = []
subtopic = ''
for page in DOC:
    lines=[]
    for block in page.get_text('dict')['blocks']:
        for line in block.get('lines', []):
            if abs(line['dir'][1])>.01: continue
            spans=line['spans']
            text=''.join(s['text'] for s in spans).strip()
            if text: lines.append((fitz.Rect(line['bbox']), text, max(s['size'] for s in spans)))
    codes=[(r,t) for r,t,s in lines if r.y0>50 and re.fullmatch(r'(?:FA|DAP|AAF|GT) \d{3}',t)]
    for i,(rect,code) in enumerate(codes):
        headings=[(r,t) for r,t,s in lines if abs(s-11)<.05 and r.y0<rect.y0]
        if headings: subtopic=headings[-1][1].replace('  (cont.)','').replace(' (cont.)','')
        bottom=codes[i+1][0].y0 if i+1<len(codes) else page.rect.height-45
        part=[(r,t,s) for r,t,s in lines if rect.y0-.1<=r.y0<bottom]
        source=next(t for r,t,s in part if re.fullmatch(r'Test \d · Q\d+',t))
        test,number=map(int,re.findall(r'\d+',source))
        stem=' '.join(t for r,t,s in part if abs(s-9.8)<.05)
        choices=[]
        for r,t,s in part:
            m=re.match(r'^([ABCD])\.\s*(.*)',t)
            if m: choices.append({'key':m[1],'text':m[2]})
            elif abs(s-9.4)<.05 and choices:
                choices[-1]['text']+=' '+t
        assert len(choices)==4,(code,choices)
        images=[]
        for im in page.get_image_info(xrefs=True):
            if rect.y0<im['bbox'][1]<bottom:
                path=FIG/(code.lower().replace(' ','-')+f'-{len(images)+1}.png')
                fitz.Pixmap(DOC,im['xref']).save(path)
                images.append('/exams/est-banks-2026/figures/'+path.name)
        records.append(dict(code=code,domain=code.split()[0],subtopic=subtopic,
            source_test=test,source_question=number,source_page=page.number+1,
            stem=stem,choices=choices,images=images))
assert len(records)==250
(OUT/'topic-questions.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
print('Extracted',len(records),'questions with',sum(len(r['images']) for r in records),'figures.')
