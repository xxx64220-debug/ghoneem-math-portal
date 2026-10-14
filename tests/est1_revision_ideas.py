"""Offline integrity checks for the additive EST I revision idea release."""

from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "content-releases/20260929_est1_revision_ideas"

manifest = json.loads((OUT / "manifest.json").read_text())
fingerprints = json.loads((OUT / "fingerprints.json").read_text())
audit = json.loads((OUT / "audit.json").read_text())
sql = (OUT / "apply.sql").read_text()

assert len(manifest) == 60 == len(fingerprints)
assert len({row["id"] for row in manifest}) == 60
assert len({row["idea"] for row in manifest}) == 60
assert set(fingerprints) == {row["id"] for row in manifest}
assert all(re.fullmatch(r"[0-9a-f]{32}", value) for value in fingerprints.values())
assert audit == {
    "questions": 60,
    "ideas": 60,
    "lessons": {
        "Angles and polygons": 11,
        "Area and perimeter": 10,
        "Logic and sets": 5,
        "Matrices": 2,
        "Logarithms and exponentials": 5,
        "Polynomial division and remainder": 5,
        "Sequences": 10,
        "Volume and surface area": 12,
    },
    "classification_only": True,
    "new_answer_certification": False,
}

assert "revision.est1_idea_expansion.20260929" in sql
assert "already applied; do not rerun" in sql
assert "q.track_id<>'est'" in sql
assert "array['est']::text[]" in sql
assert "q.topic<>x.lesson" in sql
assert "public.revision_question_fingerprint" in sql
assert "content duplicates an existing revision item" in sql
assert "new_answer_certification',false" in sql
assert "insert into public.revision_items" in sql
assert not re.search(r"\b(update|delete|truncate)\s+public\.(questions|question_keys|exam_questions|exam_sessions|student_scores)\b", sql, re.I)
assert all(row["idea"] not in {"Needs classification", "Other", "Mixed review"} for row in manifest)

print("PASS: guarded 60-question EST I expansion; 60 distinct ideas; no EST II or question-content mutation.")
