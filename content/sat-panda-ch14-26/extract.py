"""Index the original scanned exercise panels in College Panda Chapters 14–26.

Run with the pinned original PDF to produce a source-backed review index. The
answer OCR is intentionally separate: no key is inferred from a question crop.
"""
import hashlib
import json
import sys
from pathlib import Path

import fitz
import numpy as np
from PIL import Image

SOURCE_SHA = 'a6e7dcdb5eb34a88aff2163723015305c2700e26bdde7ce8e6242136a65593b8'
CHAPTERS = {
    14: ('Inequalities', [(1, 168, 171), (2, 172, 175)]),
    15: ('Function Transformations', [(1, 178, 181)]),
    16: ('Quadratic Functions', [(1, 191, 193), (2, 194, 197)]),
    17: ('Angles', [(1, 201, 204)]),
    18: ('Triangles', [(1, 217, 219), (2, 220, 223)]),
    19: ('Circles', [(1, 233, 234), (2, 235, 237)]),
    20: ('Radians', [(1, 240, 242)]),
    21: ('Trigonometry', [(1, 250, 251), (2, 252, 254)]),
    22: ('Area, Perimeter, & Volume', [(1, 261, 263), (2, 264, 266)]),
    23: ('Reading Data', [(1, 268, 272)]),
    24: ('Probability', [(1, 275, 278), (2, 279, 282)]),
    25: ('Statistics I', [(1, 289, 292), (2, 293, 297)]),
    26: ('Statistics II', [(1, 304, 307), (2, 308, 311)]),
}
# The chapter 27 printed answer section is on PDF pages 312–413.
ANSWER_PAGES = {
    14: [(1, 365, 366), (2, 367, 369)], 15: [(1, 370, 371)],
    16: [(1, 372, 374), (2, 374, 377)], 17: [(1, 378, 379)],
    18: [(1, 380, 382), (2, 382, 386)],
    19: [(1, 387, 388), (2, 388, 390)], 20: [(1, 391, 392)],
    21: [(1, 393, 394), (2, 395, 396)],
    22: [(1, 397, 398), (2, 398, 400)], 23: [(1, 401, 402)],
    24: [(1, 403, 403), (2, 404, 405)],
    25: [(1, 406, 407), (2, 407, 409)],
    26: [(1, 410, 411), (2, 411, 413)],
}
# Pixel y at 1.6x on pages containing the end of Exercise 1 and start of 2.
ANSWER_SPLITS = {(16, 374): 620, (18, 382): 473, (19, 388): 520,
                 (22, 398): 305, (25, 407): 688, (26, 411): 518}


def markers(gray, side):
    xs = range(65, 120) if side == 0 else range(475, 530)
    binary = (gray < 90).astype(np.int16)
    rows = np.maximum.reduce([binary[:, x:x + 32].sum(axis=1) for x in xs])
    score = np.convolve(rows, np.ones(20, dtype=int), 'same')
    ys = np.where(score > 280)[0]
    groups = []
    for y in ys:
        if not groups or y > groups[-1][-1] + 1:
            groups.append([])
        groups[-1].append(y)
    return [int(g[np.argmax(score[g])] - 10) for g in groups
            if g[-1] - g[0] >= 5 and 75 < g[0] < 1120]


def panels(doc, page):
    pix = doc[page - 1].get_pixmap(matrix=fitz.Matrix(1.6, 1.6))
    gray = np.asarray(Image.frombytes('RGB', (pix.width, pix.height), pix.samples).convert('L'))
    out = []
    for side in (0, 1):
        ys = markers(gray, side)
        for i, y in enumerate(ys):
            right = min(pix.width - 25, 475 if side == 0 else 920)
            left = 55 if side == 0 else 475
            bottom = (ys[i + 1] - 5) if i + 1 < len(ys) else min(pix.height - 65, 1150)
            if bottom < y + 35:
                raise ValueError(f'Collapsed panel on PDF page {page}, column {side}, y {y}')
            out.append({'page': page, 'rect': [left, y - 5, right, bottom], 'column': side})
    return out


def index(doc):
    result = []
    for chapter, (topic, exercises) in CHAPTERS.items():
        for exercise, first, last in exercises:
            n = 0
            for page in range(first, last + 1):
                for panel in panels(doc, page):
                    n += 1
                    result.append({'chapter': chapter, 'topic': topic,
                                   'exercise': exercise, 'n': n, **panel})
            print(f'Chapter {chapter}, Exercise {exercise}: {n} panels')
    return result


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: extract.py ORIGINAL_PDF OUTPUT_INDEX_JSON')
    source = Path(sys.argv[1])
    if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA:
        raise SystemExit('Source checksum differs from the reviewed PDF')
    doc = fitz.open(source)
    out = index(doc)
    Path(sys.argv[2]).write_text(json.dumps(out, indent=2) + '\n')
    print(f'{len(out)} indexed panels across Chapters 14–26')
