#!/usr/bin/env python3
"""Reassemble, verify and unpack the complete reviewed paper archive."""
from pathlib import Path
import hashlib,io,tarfile
root=Path(__file__).resolve().parent
parts=sorted((root/'archive').glob('part-*.bin'))
expected=[f'part-{i:03}.bin' for i in range(41)]
if [p.name for p in parts]!=expected:raise SystemExit('Missing archive parts: download or clone the complete repository first.')
data=b''.join(p.read_bytes() for p in parts)
sha='7d802ebd21ac651d9a9d409e7f3f7b1dd2e9509349ad982580305ebe634dbf72'
if hashlib.sha256(data).hexdigest()!=sha:raise SystemExit('Archive checksum mismatch; no files extracted.')
with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as archive:
 for member in archive.getmembers():
  destination=(root.parent/member.name).resolve()
  if not destination.is_relative_to(root.resolve()) or member.issym() or member.islnk():
   raise SystemExit('Unexpected archive member: '+member.name)
 archive.extractall(root.parent,filter='data')
print('Restored all 10 source PDFs, 450 question images, worked solutions, review records and import SQL.')
print('Open',root/'report.html')
