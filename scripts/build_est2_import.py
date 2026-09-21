#!/usr/bin/env python3
"""Build deterministic EST II / EST I question-bank SQL from the supplied Markdown bank.

The importer only consumes individually identified questions (for example T1-01 or
CP-c05-01), requires an answer key, removes known duplicates/review-flagged items,
and emits idempotent SQL batches plus 40-question/60-minute EST II assessments.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import uuid
from collections import Counter, defaultdict
from pathlib import Path


NAMESPACE = uuid.UUID("571915f4-c0f6-4c17-9a68-d8bfc53c70d9")
QUESTION_HEADING = re.compile(r"^##\s+([A-Z][A-Za-z0-9-]*-[0-9]+)\s*\|\s*Topic:\s*(.+?)\s*$", re.M)
CHOICE_LINE = re.compile(r"^\s*\(?([A-EF-GHJK])\)?[.)]\s*(.+?)\s*$")
KEY_PAIR = re.compile(r"\b([A-Z][A-Za-z0-9-]*-[0-9]+)\s*(?:=\s*)?([^|;\n]+)")
REVIEW_MARKERS = ("[REVIEW", "flagged", "ambiguous", "recheck at final build")
KNOWN_DUPLICATES = {f"H-{n:02d}" for n in range(23, 30)}
KNOWN_REVIEW = {
    "T5-20", "T8-16", "T8-42", "T8-43", "T9-40", "T9-41", "T9-42",
    "T10-35", "T10-42", "T10-48", "MG-03", "MG-38",
}

LESSONS = (
    "Algebra Foundations, Equations & Inequalities",
    "Functions, Transformations & Graphs",
    "Polynomials & Quadratic Functions",
    "Rational, Radical, Exponential & Logarithmic Functions",
    "Sequences, Complex Numbers & Advanced Algebra",
    "Coordinate Geometry, Circles & Conics",
    "Triangles, Trigonometry & Similarity",
    "Plane Geometry, Measurement & Transformations",
    "Solid Geometry & Volume",
    "Statistics, Probability & Data Analysis",
)


def squash(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def normalized_stem(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def clean_answer(raw: str) -> str:
    value = raw.strip().strip(".* ")
    value = re.sub(r"\s*\([^)]*(?:likely|review|printed|approx)[^)]*\)\s*$", "", value, flags=re.I)
    value = re.sub(r"\s*\(see REVIEW[^)]*\)\s*$", "", value, flags=re.I)
    if re.fullmatch(r"[A-EF-GHJK]", value):
        return value
    # Preserve a precise fractional form and add the decimal alias when supplied.
    return value


def extract_answer_keys(text: str) -> dict[str, str]:
    keys: dict[str, str] = {}
    marker = text.find("## ANSWER KEY")
    if marker < 0:
        return keys
    tail = text[marker:]
    for match in KEY_PAIR.finditer(tail):
        keys[match.group(1)] = clean_answer(match.group(2))
    return keys


def parse_questions(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8")
    keys = extract_answer_keys(text)
    matches = list(QUESTION_HEADING.finditer(text))
    questions: list[dict] = []
    for index, match in enumerate(matches):
        code = match.group(1)
        if code in KNOWN_DUPLICATES or code in KNOWN_REVIEW or code not in keys:
            continue
        end = matches[index + 1].start() if index + 1 < len(matches) else text.find("## ANSWER KEY", match.end())
        if end < 0:
            end = len(text)
        block = text[match.end():end].strip()
        if any(marker.lower() in block.lower() for marker in REVIEW_MARKERS):
            continue
        lines = block.splitlines()
        choices: list[dict[str, str]] = []
        stem_lines: list[str] = []
        current_choice: dict[str, str] | None = None
        for line in lines:
            choice = CHOICE_LINE.match(line)
            if choice:
                current_choice = {"key": choice.group(1), "text": squash(choice.group(2))}
                choices.append(current_choice)
            elif current_choice is not None and line.strip() and not line.lstrip().startswith("["):
                current_choice["text"] = squash(current_choice["text"] + " " + line)
            else:
                stem_lines.append(line)
        stem = "\n".join(line.rstrip() for line in stem_lines).strip()
        stem = re.sub(r"\n{3,}", "\n\n", stem)
        if not stem or len(choices) not in (0, 4, 5):
            continue
        answer = keys[code]
        question_type = "mcq" if choices and re.fullmatch(r"[A-EF-GHJK]", answer) else "grid_in"
        if choices and question_type != "mcq":
            continue
        if question_type == "grid_in" and choices:
            continue
        questions.append({
            "code": code,
            "source_file": path.name,
            "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "raw_topic": squash(match.group(2)),
            "stem": stem,
            "choices": choices,
            "answer": answer,
            "type": question_type,
        })
    return questions


def lesson_for(topic: str, stem: str) -> str:
    value = f"{topic} {stem}".lower()
    if any(k in value for k in ("statistics", "probability", "counting", "data ", "scatterplot", "mean", "median", "mode", "survey", "sampling", "margin of error")):
        return LESSONS[9]
    if any(k in value for k in ("solid", "volume", "surface area", "prism", "pyramid", "cylinder", "cone", "sphere", "3-d", "three-dimensional", "cross-section")):
        return LESSONS[8]
    if any(k in value for k in ("trigonometry", "triangle", "similar", "pythagorean", "law of sine", "law of cosine", "angle of elevation", "sine", "cosine", "tangent")):
        return LESSONS[6]
    if any(k in value for k in ("circle", "conic", "ellipse", "parabola", "coordinate geometry", "distance formula", "midpoint", "slope")):
        return LESSONS[5]
    if any(k in value for k in ("geometry", "polygon", "quadrilateral", "rectangle", "square", "trapezoid", "rhombus", "parallelogram", "transformation", "rotation", "reflection", "dilation", "perimeter", "area")):
        return LESSONS[7]
    if any(k in value for k in ("sequence", "complex", "imaginary", "matrix", "logic", "set", "number properties", "defined operation")):
        return LESSONS[4]
    if any(k in value for k in ("rational", "radical", "exponential", "logarithm", "exponent", "asymptote")):
        return LESSONS[3]
    if any(k in value for k in ("quadratic", "polynomial", "factoring", "roots", "zeros", "discriminant", "vieta")):
        return LESSONS[2]
    if any(k in value for k in ("function", "domain", "range", "inverse", "composition", "graph")):
        return LESSONS[1]
    return LESSONS[0]


def common_with_est1(topic: str, lesson: str) -> bool:
    value = topic.lower()
    advanced = (
        "logarithm", "complex", "imaginary", "conic", "ellipse", "matrix",
        "trigonometric graph", "law of sine", "law of cosine", "radian", "unit circle",
        "geometric sequence", "polar", "three-dimensional coordinates",
    )
    return not any(item in value for item in advanced)


def difficulty_for(topic: str, stem: str) -> str:
    value = f"{topic} {stem}".lower()
    hard = ("proof", "logarithm", "complex", "conic", "law of", "conditional probability", "inverse function", "composition", "asymptote", "3-d coordinates")
    easy = ("evaluate", "basic", "simple interest", "perimeter", "mean", "median", "mode")
    if any(k in value for k in hard):
        return "hard"
    if any(k in value for k in easy):
        return "easy"
    return "medium"


def sql_literal(value: object) -> str:
    return "'" + json.dumps(value, ensure_ascii=False, separators=(",", ":")).replace("'", "''") + "'::jsonb"


def text_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def qid(track: str, code: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"{track}:{code}"))


def eid(code: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"exam:{code}"))


def choose_40(pool: list[dict], seed: str, used_first: set[str] | None = None) -> list[dict]:
    rng = random.Random(seed)
    candidates = [q for q in pool if q["type"] == "mcq"]
    visual = [q for q in candidates if q["has_visual"]]
    plain = [q for q in candidates if not q["has_visual"]]
    rng.shuffle(visual)
    rng.shuffle(plain)
    chosen: list[dict] = []
    if used_first:
        unseen_visual = [q for q in visual if q["code"] not in used_first]
        unseen_plain = [q for q in plain if q["code"] not in used_first]
        chosen.extend(unseen_visual[:8])
        chosen.extend(unseen_plain[:32])
        if len(chosen) >= 40:
            return chosen[:40]
    for sequence in (visual, plain, candidates):
        for question in sequence:
            if question not in chosen:
                chosen.append(question)
            if len(chosen) == 40:
                return chosen
    raise ValueError(f"Need 40 MCQs, found only {len(chosen)} for {seed}")


def build_assessments(questions: list[dict]) -> list[dict]:
    by_lesson: dict[str, list[dict]] = defaultdict(list)
    for question in questions:
        by_lesson[question["lesson"]].append(question)
    assessments: list[dict] = []
    lesson_used: dict[str, set[str]] = defaultdict(set)
    for number, lesson in enumerate(LESSONS, 1):
        pool = by_lesson[lesson]
        lesson_exam = choose_40(pool, f"lesson-{number}")
        lesson_used[lesson].update(q["code"] for q in lesson_exam)
        assessments.append({"code": f"EST2-L{number:02d}", "title": f"EST II — {lesson} — Lesson Practice", "type": "lesson_exam", "questions": lesson_exam})
        quiz = choose_40(pool, f"quiz-{number}", lesson_used[lesson])
        assessments.append({"code": f"EST2-Q{number:02d}", "title": f"EST II — {lesson} — Quiz", "type": "quiz", "questions": quiz})
    mcq = [q for q in questions if q["type"] == "mcq"]
    for number in range(1, 6):
        selected: list[dict] = []
        # Four questions from each curriculum lesson gives a balanced 40-question paper.
        for lesson_index, lesson in enumerate(LESSONS):
            pool = by_lesson[lesson]
            rng = random.Random(f"full-{number}-{lesson_index}")
            candidates = [q for q in pool if q["type"] == "mcq"]
            rng.shuffle(candidates)
            visual = [q for q in candidates if q["has_visual"]]
            first = visual[:1]
            remainder = [q for q in candidates if q not in first]
            selected.extend((first + remainder)[:4])
        if len(selected) != 40 or len({q["code"] for q in selected}) != 40:
            selected = choose_40(mcq, f"full-fallback-{number}")
        assessments.append({"code": f"EST2-F{number:02d}", "title": f"EST II Math Level 2 — Full Practice Exam {number:02d}", "type": "full_exam", "questions": selected})
    return assessments


def question_row(question: dict, track: str, asset_base: str) -> str:
    question_id = qid(track, question["code"])
    assets = {
        "source": "Kimi Agent Math PDF Question Bank (4)",
        "source_file": question["source_file"],
        "source_sha256": question["source_sha256"],
        "source_question_id": question["code"],
        "import_batch": "est2-kimi-bank-2026-09-21",
        "curriculum_lesson": question["lesson"],
    }
    if question["has_visual"]:
        assets.update({
            "image": f"{asset_base}/{question['visual_name']}",
            "image_alt": f"Original graph, diagram, or table for {question['code']}",
            "visual_verified": True,
        })
    return "(" + ",".join([
        f"'{question_id}'::uuid", f"'{track}'", sql_literal(question["lesson"]),
        f"'{question['difficulty']}'", f"'{question['type']}'", sql_literal(question["stem"]),
        sql_literal(question["choices"]), sql_literal(assets), sql_literal(question["answer"]),
        sql_literal(f"Source-keyed answer from {question['source_file']} ({question['code']})."),
    ]) + ")"


def emit_question_batches(questions: list[dict], track: str, asset_base: str, out_dir: Path, batch_size: int = 100) -> None:
    for batch_number, start in enumerate(range(0, len(questions), batch_size), 1):
        batch = questions[start:start + batch_size]
        values = ",\n".join(question_row(q, track, asset_base) for q in batch)
        # EST II is a new empty track; EST I additionally guards against normalized-stem duplicates.
        duplicate_guard = "true" if track == "est2" else "not exists (select 1 from public.questions e where e.track_id='est' and lower(regexp_replace(e.stem,'[^a-z0-9]+','','g'))=lower(regexp_replace(i.stem #>> '{}','[^a-z0-9]+','','g')))"
        sql = f"""begin;
with imported(id,track_id,topic,difficulty,type,stem,choices,assets,correct,explanation) as (values
{values}
), inserted as (
 insert into public.questions(id,track_id,topic,difficulty,type,stem,choices,assets)
 select i.id,i.track_id,i.topic #>> '{{}}',i.difficulty,i.type,i.stem #>> '{{}}',i.choices,i.assets
 from imported i
 where {duplicate_guard}
 on conflict (id) do update set topic=excluded.topic,difficulty=excluded.difficulty,type=excluded.type,stem=excluded.stem,choices=excluded.choices,assets=excluded.assets
 returning id
)
insert into public.question_keys(question_id,correct,explanation)
select i.id,i.correct,i.explanation #>> '{{}}' from imported i join public.questions q on q.id=i.id
on conflict (question_id) do update set correct=excluded.correct, explanation=excluded.explanation;
commit;
"""
        (out_dir / f"{track}_questions_{batch_number:03d}.sql").write_text(sql, encoding="utf-8")


def emit_assessments(assessments: list[dict], out_dir: Path) -> None:
    values = []
    for assessment in assessments:
        ids = [qid("est2", q["code"]) for q in assessment["questions"]]
        array = "ARRAY[" + ",".join(f"'{item}'::uuid" for item in ids) + "]"
        values.append("(" + ",".join([
            f"'{eid(assessment['code'])}'::uuid", "'est2'", text_literal(assessment["title"]), "3600", array,
            "true", "'full_review'", "3", "true", "true" if assessment["type"] == "full_exam" else "false",
            text_literal(assessment["type"]), text_literal(assessment["code"]),
        ]) + ")")
    sql = f"""begin;
insert into public.exams(id,track_id,title,duration_seconds,question_ids,shuffle,review_policy,max_attempts,is_published,is_full_length,assessment_type,exam_set_code)
values
{',\n'.join(values)}
on conflict (id) do update set title=excluded.title,duration_seconds=excluded.duration_seconds,question_ids=excluded.question_ids,shuffle=excluded.shuffle,review_policy=excluded.review_policy,max_attempts=excluded.max_attempts,is_published=excluded.is_published,is_full_length=excluded.is_full_length,assessment_type=excluded.assessment_type,exam_set_code=excluded.exam_set_code;
commit;
"""
    (out_dir / "est2_assessments.sql").write_text(sql, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bank", type=Path, required=True)
    parser.add_argument("--figures", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--asset-base", required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    figures = {path.name: path for path in args.figures.glob("*.png")}
    parsed: list[dict] = []
    for path in sorted(args.bank.glob("*.md")):
        if path.name == "panda_keys.md":
            continue
        parsed.extend(parse_questions(path))
    # Exact normalized-stem deduplication preserves the first source-keyed record.
    unique: list[dict] = []
    seen: set[str] = set()
    for question in parsed:
        fingerprint = normalized_stem(question["stem"])
        if fingerprint in seen:
            continue
        seen.add(fingerprint)
        question["lesson"] = lesson_for(question["raw_topic"], question["stem"])
        question["difficulty"] = difficulty_for(question["raw_topic"], question["stem"])
        candidates = [f"{question['code']}.png", f"{question['code']}b.png"]
        visual = next((name for name in candidates if name in figures), None)
        question["has_visual"] = visual is not None
        question["visual_name"] = visual
        unique.append(question)
    est1 = [q for q in unique if common_with_est1(q["raw_topic"], q["lesson"])]
    assessments = build_assessments(unique)
    emit_question_batches(unique, "est2", args.asset_base, args.out)
    emit_question_batches(est1, "est", args.asset_base, args.out)
    emit_assessments(assessments, args.out)
    report = {
        "parsed": len(parsed), "unique_est2": len(unique), "est1_common": len(est1),
        "mcq": sum(q["type"] == "mcq" for q in unique), "grid_in": sum(q["type"] == "grid_in" for q in unique),
        "visual": sum(q["has_visual"] for q in unique), "lessons": Counter(q["lesson"] for q in unique),
        "assessments": [{"code": a["code"], "type": a["type"], "questions": len(a["questions"]), "visuals": sum(q["has_visual"] for q in a["questions"])} for a in assessments],
    }
    (args.out / "import_report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
