"""Read the original scanned guide for source/key reconciliation."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import fitz, subprocess, os
source=Path('/workspace/scratch/861668d2e749/est-reference/b78f1d8e-d064-4cd8-b3c6-5039fad021ce_260825_202526.pdf')
out=source.parent/'ocr'
out.mkdir(exist_ok=True)
def read_page(i):
    target=out/f'{i+1:03}.txt'
    if target.exists():return
    doc=fitz.open(source)
    pix=doc[i].get_pixmap(matrix=fitz.Matrix(1.8,1.8))
    r=subprocess.run(['tesseract','stdin','stdout','--psm','3'],input=pix.tobytes('png'),capture_output=True,env={**os.environ,'OMP_THREAD_LIMIT':'1'})
    target.write_bytes(r.stdout)
    if i%20==0:print('page',i+1,flush=True)
with ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(read_page,range(129)))
print('Guide OCR complete',flush=True)
