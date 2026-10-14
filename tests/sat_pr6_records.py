"""Offline provenance checks. Never execute the historical release builders."""
import ast
import hashlib
import json
from collections import Counter
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT / 'content-releases/20261006_sat_pr6_reconciliation'
read = lambda path: json.loads((ROOT / path).read_text())
inventory = json.loads((PACKET / 'preservation-index.json').read_text())
assert inventory['source_head'] == '4c2b60308e0df2b97453b1444676cec8e4a59c19'
assert len(inventory['files']) == 73
assert len({r['preserved_path'] for r in inventory['files']}) == 73
for record in inventory['files']:
    data = (ROOT / record['preserved_path']).read_bytes()
    assert len(data) == record['bytes'], record['preserved_path']
    assert hashlib.sha256(data).hexdigest() == record['sha256'], record['preserved_path']
    assert not record['preserved_path'].startswith('supabase/migrations/')

early = 0
for chapter in range(1, 14):
    rows = read(f'content/sat-panda-ch{chapter:02}/questions.json')
    early += len(rows)
    assert len({(q['exercise'], q['n']) for q in rows}) == len(rows)
    assert all(q['stem'] and q['correct'] and q['explanation'] for q in rows)
assert early == 498

index = read('content/sat-panda-ch14-26/question-index.json')
keys = read('content/sat-panda-ch14-26/reviewed-keys.json')
assert len(index) == sum(map(len, keys.values())) == 380
assert len(keys) == 22
assert {q['chapter'] for q in index} == set(range(14, 27))
assert len({(q['chapter'], q['exercise'], q['n']) for q in index}) == 380
counts = Counter(f"{q['chapter']}-{q['exercise']}" for q in index)
assert counts == {ex: len(answers) for ex, answers in keys.items()}
builder = ast.parse((ROOT / 'content/sat-panda-ch14-26/build.py').read_text())
ends = next(ast.literal_eval(n.value) for n in builder.body
            if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'ANSWER_ENDS' for t in n.targets))
pages = set()
for q in index:
    ex = f"{q['chapter']}-{q['exercise']}"
    assert 1 <= q['n'] <= len(keys[ex])
    assert q['rect'][2] > q['rect'][0] and q['rect'][3] > q['rect'][1]
    answer = keys[ex][q['n'] - 1]
    if answer not in ('A', 'B', 'C', 'D'):
        for form in answer.split('|'):
            Fraction(form)
    pages.add(next(page for last, page in ends[ex] if q['n'] <= last))
assert pages == set(range(365, 413))

recovered = read('content/sat-sep-held-2026-09-29/questions.json')
assert [(q['n'], q['correct']) for q in recovered] == [(19, 'B'), (24, ['414'])]
assert 'Q18 remains held' in (ROOT / 'content/sat-sep-held-2026-09-29/README.md').read_text()
assert 'Source defect' in (ROOT / 'content/sat-panda-ch01/README.md').read_text()
print('PASS: 73 exact provenance files; 498 + 380 exercises; 22 sections; 48 private-page references; complete unique index/key pairs; source holds retained. No imports executed.')
