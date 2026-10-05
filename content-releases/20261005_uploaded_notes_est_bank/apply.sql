begin;
set transaction isolation level repeatable read;
set local lock_timeout='5s';
do $release$
declare r jsonb; qid uuid; inserted integer:=0; protected_before jsonb; protected_after jsonb;
begin
 perform pg_advisory_xact_lock(hashtextextended('20261005_uploaded_notes_est_bank',0));
 if exists(select 1 from audit_log where action='question.20261005_uploaded_notes_est_bank') then raise exception 'Release already applied'; end if;
 select jsonb_build_object(
   'exams',(select md5(coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]')::text) from exams x),
   'assignments',(select md5(coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]')::text) from assignments x),
   'attempts',(select md5(coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]')::text) from attempts x),
   'answers',(select md5(coalesce(jsonb_agg(to_jsonb(x) order by x.attempt_id,x.question_id),'[]')::text) from attempt_answers x),
   'results',(select md5(coalesce(jsonb_agg(to_jsonb(x) order by x.attempt_id,x.question_id),'[]')::text) from attempt_results x),
   'revision',(select md5(coalesce(jsonb_agg(to_jsonb(x) order by x.question_id),'[]')::text) from revision_items x)
 ) into protected_before;
 for r in select value from jsonb_array_elements($packet${
  "release": "20261005_uploaded_notes_est_bank",
  "source_document": "Notes_261005_140129.pdf",
  "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
  "track_id": "est",
  "created_at": "2026-10-05",
  "questions": [
    {
      "id": "bd91fe55-32f0-50b9-b82b-fc0319f6911a",
      "track_id": "est",
      "topic": "Functions and transformations",
      "difficulty": "easy",
      "type": "grid_in",
      "stem": "The table shows values of the linear function f.\n\nx | f(x)\n1 | m\n2 | 6\n3 | n\n\nWhat is the value of m + n?\nRecord your answer as a number.",
      "choices": [],
      "correct": "12",
      "explanation": "A linear function changes by the same amount for each increase of 1 in x. Thus 6−m=n−6, so m+n=12.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 1,
        "source_item": 1,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Functions and transformations",
        "lesson_subtopic": "Linear functions and tables",
        "lesson_original_topic": "Functions and transformations",
        "lesson_taxonomy_version": "20260929"
      }
    },
    {
      "id": "fe364c75-f5c4-5da8-aeea-09e9538d97c7",
      "track_id": "est",
      "topic": "Quadratics and polynomials",
      "difficulty": "medium",
      "type": "mcq",
      "stem": "Figure 8 shows rectangle ABCD. Points A and D lie on the parabola y = 2x² − 8, and points B and C lie on the parabola y = 9 − x². If B has coordinates (−1.50, 6.75), what is the area of rectangle ABCD?",
      "choices": [
        {
          "key": "A",
          "text": "12.50"
        },
        {
          "key": "B",
          "text": "17.50"
        },
        {
          "key": "C",
          "text": "22.75"
        },
        {
          "key": "D",
          "text": "26.50"
        },
        {
          "key": "E",
          "text": "30.75"
        }
      ],
      "correct": "E",
      "explanation": "Because the parabolas are symmetric about the y-axis, the rectangle’s vertical sides have x-coordinates −1.5 and 1.5, so its width is 3. The upper y-coordinate is 6.75. The lower y-coordinate is 2(1.5)²−8=−3.5. Its height is 10.25, so its area is 3×10.25=30.75.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 2,
        "source_item": 1,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Quadratics and polynomials",
        "lesson_subtopic": "Parabolas and applications",
        "lesson_original_topic": "Quadratics and polynomials",
        "lesson_taxonomy_version": "20260929",
        "figure": "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA3NjAgNTAwIiByb2xlPSJpbWciIGFyaWEtbGFiZWw9IlR3byBwYXJhYm9sYXMgd2l0aCBhIHJlY3RhbmdsZSBiZXR3ZWVuIHRoZW0iPjxyZWN0IHdpZHRoPSI3NjAiIGhlaWdodD0iNTAwIiBmaWxsPSJ3aGl0ZSIvPjxsaW5lIHgxPSIxMDAuMCIgeTE9IjM1IiB4Mj0iMTAwLjAiIHkyPSI0NDAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSIyMDAuMCIgeTE9IjM1IiB4Mj0iMjAwLjAiIHkyPSI0NDAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSIzMDAuMCIgeTE9IjM1IiB4Mj0iMzAwLjAiIHkyPSI0NDAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSI0MDAuMCIgeTE9IjM1IiB4Mj0iNDAwLjAiIHkyPSI0NDAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSI1MDAuMCIgeTE9IjM1IiB4Mj0iNTAwLjAiIHkyPSI0NDAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSI2MDAuMCIgeTE9IjM1IiB4Mj0iNjAwLjAiIHkyPSI0NDAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSI3MDAuMCIgeTE9IjM1IiB4Mj0iNzAwLjAiIHkyPSI0NDAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSI3MCIgeTE9IjQxMy4wIiB4Mj0iNzMwIiB5Mj0iNDEzLjAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSI3MCIgeTE9IjM1OS4wIiB4Mj0iNzMwIiB5Mj0iMzU5LjAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSI3MCIgeTE9IjMwNS4wIiB4Mj0iNzMwIiB5Mj0iMzA1LjAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSI3MCIgeTE9IjI1MS4wIiB4Mj0iNzMwIiB5Mj0iMjUxLjAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSI3MCIgeTE9IjE5Ny4wIiB4Mj0iNzMwIiB5Mj0iMTk3LjAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSI3MCIgeTE9IjE0My4wIiB4Mj0iNzMwIiB5Mj0iMTQzLjAiIHN0cm9rZT0iI2UzZThlZiIvPjxsaW5lIHgxPSI3MCIgeTE9Ijg5LjAiIHgyPSI3MzAiIHkyPSI4OS4wIiBzdHJva2U9IiNlM2U4ZWYiLz48bGluZSB4MT0iNDAwLjAiIHkxPSIzNSIgeDI9IjQwMC4wIiB5Mj0iNDQwIiBzdHJva2U9IiMzMzQxNTUiIHN0cm9rZS13aWR0aD0iMiIvPjxsaW5lIHgxPSI3MCIgeTE9IjMwNS4wIiB4Mj0iNzMwIiB5Mj0iMzA1LjAiIHN0cm9rZT0iIzMzNDE1NSIgc3Ryb2tlLXdpZHRoPSIyIi8+PHBhdGggZD0iTTcwLjAsMzU2LjAgTDczLjAsMzUwLjcgTDc2LjAsMzQ1LjQgTDc5LjAsMzQwLjIgTDgyLjAsMzM1LjAgTDg1LjAsMzI5LjkgTDg4LjAsMzI0LjggTDkxLjAsMzE5LjggTDk0LjAsMzE0LjggTDk3LjAsMzA5LjkgTDEwMC4wLDMwNS4wIEwxMDMuMCwzMDAuMiBMMTA2LjAsMjk1LjQgTDEwOS4wLDI5MC42IEwxMTIuMCwyODUuOSBMMTE1LjAsMjgxLjMgTDExOC4wLDI3Ni43IEwxMjEuMCwyNzIuMiBMMTI0LjAsMjY3LjcgTDEyNy4wLDI2My4yIEwxMzAuMCwyNTguOCBMMTMzLjAsMjU0LjUgTDEzNi4wLDI1MC4yIEwxMzkuMCwyNDUuOSBMMTQyLjAsMjQxLjcgTDE0NS4wLDIzNy42IEwxNDguMCwyMzMuNSBMMTUxLjAsMjI5LjQgTDE1NC4wLDIyNS40IEwxNTcuMCwyMjEuNCBMMTYwLjAsMjE3LjUgTDE2My4wLDIxMy43IEwxNjYuMCwyMDkuOCBMMTY5LjAsMjA2LjEgTDE3Mi4wLDIwMi40IEwxNzUuMCwxOTguNyBMMTc4LjAsMTk1LjEgTDE4MS4wLDE5MS41IEwxODQuMCwxODguMCBMMTg3LjAsMTg0LjUgTDE5MC4wLDE4MS4xIEwxOTMuMCwxNzcuNyBMMTk2LjAsMTc0LjQgTDE5OS4wLDE3MS4xIEwyMDIuMCwxNjcuOSBMMjA1LjAsMTY0LjcgTDIwOC4wLDE2MS41IEwyMTEuMCwxNTguNCBMMjE0LjAsMTU1LjQgTDIxNy4wLDE1Mi40IEwyMjAuMCwxNDkuNSBMMjIzLjAsMTQ2LjYgTDIyNi4wLDE0My43IEwyMjkuMCwxNDEuMCBMMjMyLjAsMTM4LjIgTDIzNS4wLDEzNS41IEwyMzguMCwxMzIuOSBMMjQxLjAsMTMwLjMgTDI0NC4wLDEyNy43IEwyNDcuMCwxMjUuMiBMMjUwLjAsMTIyLjggTDI1My4wLDEyMC4zIEwyNTYuMCwxMTguMCBMMjU5LjAsMTE1LjcgTDI2Mi4wLDExMy40IEwyNjUuMCwxMTEuMiBMMjY4LjAsMTA5LjAgTDI3MS4wLDEwNi45IEwyNzQuMCwxMDQuOSBMMjc3LjAsMTAyLjggTDI4MC4wLDEwMC45IEwyODMuMCw5OS4wIEwyODYuMCw5Ny4xIEwyODkuMCw5NS4zIEwyOTIuMCw5My41IEwyOTUuMCw5MS44IEwyOTguMCw5MC4xIEwzMDEuMCw4OC41IEwzMDQuMCw4Ni45IEwzMDcuMCw4NS40IEwzMTAuMCw4My45IEwzMTMuMCw4Mi40IEwzMTYuMCw4MS4xIEwzMTkuMCw3OS43IEwzMjIuMCw3OC40IEwzMjUuMCw3Ny4yIEwzMjguMCw3Ni4wIEwzMzEuMCw3NC45IEwzMzQuMCw3My44IEwzMzcuMCw3Mi43IEwzNDAuMCw3MS43IEwzNDMuMCw3MC44IEwzNDYuMCw2OS45IEwzNDkuMCw2OS4wIEwzNTIuMCw2OC4yIEwzNTUuMCw2Ny41IEwzNTguMCw2Ni44IEwzNjEuMCw2Ni4xIEwzNjQuMCw2NS41IEwzNjcuMCw2NC45IEwzNzAuMCw2NC40IEwzNzMuMCw2NC4wIEwzNzYuMCw2My42IEwzNzkuMCw2My4yIEwzODIuMCw2Mi45IEwzODUuMCw2Mi42IEwzODguMCw2Mi40IEwzOTEuMCw2Mi4yIEwzOTQuMCw2Mi4xIEwzOTcuMCw2Mi4wIEw0MDAuMCw2Mi4wIEw0MDMuMCw2Mi4wIEw0MDYuMCw2Mi4xIEw0MDkuMCw2Mi4yIEw0MTIuMCw2Mi40IEw0MTUuMCw2Mi42IEw0MTguMCw2Mi45IEw0MjEuMCw2My4yIEw0MjQuMCw2My42IEw0MjcuMCw2NC4wIEw0MzAuMCw2NC40IEw0MzMuMCw2NC45IEw0MzYuMCw2NS41IEw0MzkuMCw2Ni4xIEw0NDIuMCw2Ni44IEw0NDUuMCw2Ny41IEw0NDguMCw2OC4yIEw0NTEuMCw2OS4wIEw0NTQuMCw2OS45IEw0NTcuMCw3MC44IEw0NjAuMCw3MS43IEw0NjMuMCw3Mi43IEw0NjYuMCw3My44IEw0NjkuMCw3NC45IEw0NzIuMCw3Ni4wIEw0NzUuMCw3Ny4yIEw0NzguMCw3OC40IEw0ODEuMCw3OS43IEw0ODQuMCw4MS4xIEw0ODcuMCw4Mi40IEw0OTAuMCw4My45IEw0OTMuMCw4NS40IEw0OTYuMCw4Ni45IEw0OTkuMCw4OC41IEw1MDIuMCw5MC4xIEw1MDUuMCw5MS44IEw1MDguMCw5My41IEw1MTEuMCw5NS4zIEw1MTQuMCw5Ny4xIEw1MTcuMCw5OS4wIEw1MjAuMCwxMDAuOSBMNTIzLjAsMTAyLjggTDUyNi4wLDEwNC45IEw1MjkuMCwxMDYuOSBMNTMyLjAsMTA5LjAgTDUzNS4wLDExMS4yIEw1MzguMCwxMTMuNCBMNTQxLjAsMTE1LjcgTDU0NC4wLDExOC4wIEw1NDcuMCwxMjAuMyBMNTUwLjAsMTIyLjggTDU1My4wLDEyNS4yIEw1NTYuMCwxMjcuNyBMNTU5LjAsMTMwLjMgTDU2Mi4wLDEzMi45IEw1NjUuMCwxMzUuNSBMNTY4LjAsMTM4LjIgTDU3MS4wLDE0MS4wIEw1NzQuMCwxNDMuNyBMNTc3LjAsMTQ2LjYgTDU4MC4wLDE0OS41IEw1ODMuMCwxNTIuNCBMNTg2LjAsMTU1LjQgTDU4OS4wLDE1OC40IEw1OTIuMCwxNjEuNSBMNTk1LjAsMTY0LjcgTDU5OC4wLDE2Ny45IEw2MDEuMCwxNzEuMSBMNjA0LjAsMTc0LjQgTDYwNy4wLDE3Ny43IEw2MTAuMCwxODEuMSBMNjEzLjAsMTg0LjUgTDYxNi4wLDE4OC4wIEw2MTkuMCwxOTEuNSBMNjIyLjAsMTk1LjEgTDYyNS4wLDE5OC43IEw2MjguMCwyMDIuNCBMNjMxLjAsMjA2LjEgTDYzNC4wLDIwOS44IEw2MzcuMCwyMTMuNyBMNjQwLjAsMjE3LjUgTDY0My4wLDIyMS40IEw2NDYuMCwyMjUuNCBMNjQ5LjAsMjI5LjQgTDY1Mi4wLDIzMy41IEw2NTUuMCwyMzcuNiBMNjU4LjAsMjQxLjcgTDY2MS4wLDI0NS45IEw2NjQuMCwyNTAuMiBMNjY3LjAsMjU0LjUgTDY3MC4wLDI1OC44IEw2NzMuMCwyNjMuMiBMNjc2LjAsMjY3LjcgTDY3OS4wLDI3Mi4yIEw2ODIuMCwyNzYuNyBMNjg1LjAsMjgxLjMgTDY4OC4wLDI4NS45IEw2OTEuMCwyOTAuNiBMNjk0LjAsMjk1LjQgTDY5Ny4wLDMwMC4yIEw3MDAuMCwzMDUuMCBMNzAzLjAsMzA5LjkgTDcwNi4wLDMxNC44IEw3MDkuMCwzMTkuOCBMNzEyLjAsMzI0LjggTDcxNS4wLDMyOS45IEw3MTguMCwzMzUuMCBMNzIxLjAsMzQwLjIgTDcyNC4wLDM0NS40IEw3MjcuMCwzNTAuNyBMNzMwLjAsMzU2LjAiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzI1NjNlYiIgc3Ryb2tlLXdpZHRoPSIzIi8+PHBhdGggZD0iTTEwMC4wLDM1LjAgTDEwMy4wLDQ0LjcgTDEwNi4wLDU0LjIgTDEwOS4wLDYzLjcgTDExMi4wLDczLjEgTDExNS4wLDgyLjQgTDExOC4wLDkxLjYgTDEyMS4wLDEwMC43IEwxMjQuMCwxMDkuNiBMMTI3LjAsMTE4LjUgTDEzMC4wLDEyNy4zIEwxMzMuMCwxMzYuMCBMMTM2LjAsMTQ0LjYgTDEzOS4wLDE1My4xIEwxNDIuMCwxNjEuNiBMMTQ1LjAsMTY5LjkgTDE0OC4wLDE3OC4xIEwxNTEuMCwxODYuMiBMMTU0LjAsMTk0LjIgTDE1Ny4wLDIwMi4xIEwxNjAuMCwyMTAuMCBMMTYzLjAsMjE3LjcgTDE2Ni4wLDIyNS4zIEwxNjkuMCwyMzIuOSBMMTcyLjAsMjQwLjMgTDE3NS4wLDI0Ny42IEwxNzguMCwyNTQuOSBMMTgxLjAsMjYyLjAgTDE4NC4wLDI2OS4xIEwxODcuMCwyNzYuMCBMMTkwLjAsMjgyLjkgTDE5My4wLDI4OS42IEwxOTYuMCwyOTYuMyBMMTk5LjAsMzAyLjggTDIwMi4wLDMwOS4zIEwyMDUuMCwzMTUuNyBMMjA4LjAsMzIxLjkgTDIxMS4wLDMyOC4xIEwyMTQuMCwzMzQuMiBMMjE3LjAsMzQwLjIgTDIyMC4wLDM0Ni4wIEwyMjMuMCwzNTEuOCBMMjI2LjAsMzU3LjUgTDIyOS4wLDM2My4xIEwyMzIuMCwzNjguNiBMMjM1LjAsMzc0LjAgTDIzOC4wLDM3OS4zIEwyNDEuMCwzODQuNSBMMjQ0LjAsMzg5LjYgTDI0Ny4wLDM5NC42IEwyNTAuMCwzOTkuNSBMMjUzLjAsNDA0LjMgTDI1Ni4wLDQwOS4wIEwyNTkuMCw0MTMuNiBMMjYyLjAsNDE4LjIgTDI2NS4wLDQyMi42IEwyNjguMCw0MjYuOSBMMjcxLjAsNDMxLjEgTDI3NC4wLDQzNS4zIEwyNzcuMCw0MzkuMyBMNTIzLjAsNDM5LjMgTDUyNi4wLDQzNS4zIEw1MjkuMCw0MzEuMSBMNTMyLjAsNDI2LjkgTDUzNS4wLDQyMi42IEw1MzguMCw0MTguMiBMNTQxLjAsNDEzLjYgTDU0NC4wLDQwOS4wIEw1NDcuMCw0MDQuMyBMNTUwLjAsMzk5LjUgTDU1My4wLDM5NC42IEw1NTYuMCwzODkuNiBMNTU5LjAsMzg0LjUgTDU2Mi4wLDM3OS4zIEw1NjUuMCwzNzQuMCBMNTY4LjAsMzY4LjYgTDU3MS4wLDM2My4xIEw1NzQuMCwzNTcuNSBMNTc3LjAsMzUxLjggTDU4MC4wLDM0Ni4wIEw1ODMuMCwzNDAuMiBMNTg2LjAsMzM0LjIgTDU4OS4wLDMyOC4xIEw1OTIuMCwzMjEuOSBMNTk1LjAsMzE1LjcgTDU5OC4wLDMwOS4zIEw2MDEuMCwzMDIuOCBMNjA0LjAsMjk2LjMgTDYwNy4wLDI4OS42IEw2MTAuMCwyODIuOSBMNjEzLjAsMjc2LjAgTDYxNi4wLDI2OS4xIEw2MTkuMCwyNjIuMCBMNjIyLjAsMjU0LjkgTDYyNS4wLDI0Ny42IEw2MjguMCwyNDAuMyBMNjMxLjAsMjMyLjkgTDYzNC4wLDIyNS4zIEw2MzcuMCwyMTcuNyBMNjQwLjAsMjEwLjAgTDY0My4wLDIwMi4xIEw2NDYuMCwxOTQuMiBMNjQ5LjAsMTg2LjIgTDY1Mi4wLDE3OC4xIEw2NTUuMCwxNjkuOSBMNjU4LjAsMTYxLjYgTDY2MS4wLDE1My4xIEw2NjQuMCwxNDQuNiBMNjY3LjAsMTM2LjAgTDY3MC4wLDEyNy4zIEw2NzMuMCwxMTguNSBMNjc2LjAsMTA5LjYgTDY3OS4wLDEwMC43IEw2ODIuMCw5MS42IEw2ODUuMCw4Mi40IEw2ODguMCw3My4xIEw2OTEuMCw2My43IEw2OTQuMCw1NC4yIEw2OTcuMCw0NC43IEw3MDAuMCwzNS4wIiBmaWxsPSJub25lIiBzdHJva2U9IiNiNDUzMDkiIHN0cm9rZS13aWR0aD0iMyIvPjxyZWN0IHg9IjI1MC4wIiB5PSIxMjIuOCIgd2lkdGg9IjMwMC4wIiBoZWlnaHQ9IjI3Ni44IiBmaWxsPSIjZmVmM2M3IiBmaWxsLW9wYWNpdHk9Ii41IiBzdHJva2U9IiMxMTE4MjciIHN0cm9rZS13aWR0aD0iMi40Ii8+PGNpcmNsZSBjeD0iMjUwLjAiIGN5PSIzOTkuNSIgcj0iNCIgZmlsbD0iIzExMTgyNyIvPjx0ZXh0IHg9IjIzMi4wIiB5PSI0MTcuNSIgZm9udC1mYW1pbHk9IkFyaWFsLHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSI2MDAiPkE8L3RleHQ+PGNpcmNsZSBjeD0iMjUwLjAiIGN5PSIxMjIuOCIgcj0iNCIgZmlsbD0iIzExMTgyNyIvPjx0ZXh0IHg9IjIzMi4wIiB5PSIxMTIuOCIgZm9udC1mYW1pbHk9IkFyaWFsLHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSI2MDAiPkI8L3RleHQ+PGNpcmNsZSBjeD0iNTUwLjAiIGN5PSIxMjIuOCIgcj0iNCIgZmlsbD0iIzExMTgyNyIvPjx0ZXh0IHg9IjU1OC4wIiB5PSIxMTIuOCIgZm9udC1mYW1pbHk9IkFyaWFsLHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSI2MDAiPkM8L3RleHQ+PGNpcmNsZSBjeD0iNTUwLjAiIGN5PSIzOTkuNSIgcj0iNCIgZmlsbD0iIzExMTgyNyIvPjx0ZXh0IHg9IjU1OC4wIiB5PSI0MTcuNSIgZm9udC1mYW1pbHk9IkFyaWFsLHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSI2MDAiPkQ8L3RleHQ+PHRleHQgeD0iMTAwLjAiIHk9IjMyNy4wIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LWZhbWlseT0iQXJpYWwsc2Fucy1zZXJpZiIgZm9udC1zaXplPSIxNSIgZmlsbD0iIzMzNDE1NSI+LTM8L3RleHQ+PHRleHQgeD0iMjAwLjAiIHk9IjMyNy4wIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LWZhbWlseT0iQXJpYWwsc2Fucy1zZXJpZiIgZm9udC1zaXplPSIxNSIgZmlsbD0iIzMzNDE1NSI+LTI8L3RleHQ+PHRleHQgeD0iMzAwLjAiIHk9IjMyNy4wIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LWZhbWlseT0iQXJpYWwsc2Fucy1zZXJpZiIgZm9udC1zaXplPSIxNSIgZmlsbD0iIzMzNDE1NSI+LTE8L3RleHQ+PHRleHQgeD0iNTAwLjAiIHk9IjMyNy4wIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LWZhbWlseT0iQXJpYWwsc2Fucy1zZXJpZiIgZm9udC1zaXplPSIxNSIgZmlsbD0iIzMzNDE1NSI+MTwvdGV4dD48dGV4dCB4PSI2MDAuMCIgeT0iMzI3LjAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtZmFtaWx5PSJBcmlhbCxzYW5zLXNlcmlmIiBmb250LXNpemU9IjE1IiBmaWxsPSIjMzM0MTU1Ij4yPC90ZXh0Pjx0ZXh0IHg9IjcwMC4wIiB5PSIzMjcuMCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1mYW1pbHk9IkFyaWFsLHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTUiIGZpbGw9IiMzMzQxNTUiPjM8L3RleHQ+PHRleHQgeD0iMzg4LjAiIHk9IjQxOC4wIiB0ZXh0LWFuY2hvcj0iZW5kIiBmb250LWZhbWlseT0iQXJpYWwsc2Fucy1zZXJpZiIgZm9udC1zaXplPSIxNSIgZmlsbD0iIzMzNDE1NSI+LTQ8L3RleHQ+PHRleHQgeD0iMzg4LjAiIHk9IjM2NC4wIiB0ZXh0LWFuY2hvcj0iZW5kIiBmb250LWZhbWlseT0iQXJpYWwsc2Fucy1zZXJpZiIgZm9udC1zaXplPSIxNSIgZmlsbD0iIzMzNDE1NSI+LTI8L3RleHQ+PHRleHQgeD0iMzg4LjAiIHk9IjI1Ni4wIiB0ZXh0LWFuY2hvcj0iZW5kIiBmb250LWZhbWlseT0iQXJpYWwsc2Fucy1zZXJpZiIgZm9udC1zaXplPSIxNSIgZmlsbD0iIzMzNDE1NSI+MjwvdGV4dD48dGV4dCB4PSIzODguMCIgeT0iMjAyLjAiIHRleHQtYW5jaG9yPSJlbmQiIGZvbnQtZmFtaWx5PSJBcmlhbCxzYW5zLXNlcmlmIiBmb250LXNpemU9IjE1IiBmaWxsPSIjMzM0MTU1Ij40PC90ZXh0Pjx0ZXh0IHg9IjM4OC4wIiB5PSIxNDguMCIgdGV4dC1hbmNob3I9ImVuZCIgZm9udC1mYW1pbHk9IkFyaWFsLHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTUiIGZpbGw9IiMzMzQxNTUiPjY8L3RleHQ+PHRleHQgeD0iMzg4LjAiIHk9Ijk0LjAiIHRleHQtYW5jaG9yPSJlbmQiIGZvbnQtZmFtaWx5PSJBcmlhbCxzYW5zLXNlcmlmIiBmb250LXNpemU9IjE1IiBmaWxsPSIjMzM0MTU1Ij44PC90ZXh0Pjx0ZXh0IHg9IjcyMiIgeT0iMjk1LjAiIGZvbnQtZmFtaWx5PSJBcmlhbCxzYW5zLXNlcmlmIiBmb250LXNpemU9IjE3IiBmaWxsPSIjMTExODI3Ij54PC90ZXh0Pjx0ZXh0IHg9IjQxMC4wIiB5PSI0OSIgZm9udC1mYW1pbHk9IkFyaWFsLHNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTciIGZpbGw9IiMxMTE4MjciPnk8L3RleHQ+PHRleHQgeD0iNzgiIHk9IjUzIiBmb250LWZhbWlseT0iQXJpYWwsc2Fucy1zZXJpZiIgZm9udC1zaXplPSIxNiIgZmlsbD0iIzI1NjNlYiI+eSA9IDkg4oiSIHjCsjwvdGV4dD48dGV4dCB4PSI3OCIgeT0iNDMyIiBmb250LWZhbWlseT0iQXJpYWwsc2Fucy1zZXJpZiIgZm9udC1zaXplPSIxNiIgZmlsbD0iI2I0NTMwOSI+eSA9IDJ4wrIg4oiSIDg8L3RleHQ+PC9zdmc+",
        "figure_caption": "Rectangle with vertical sides at x = −1.5 and x = 1.5 between y = 9 − x² and y = 2x² − 8.",
        "image_alt": "Rectangle with vertical sides at x = −1.5 and x = 1.5 between y = 9 − x² and y = 2x² − 8."
      }
    },
    {
      "id": "38106f66-a183-53bb-87b9-0a53da3d59fe",
      "track_id": "est",
      "topic": "Circles",
      "difficulty": "medium",
      "type": "mcq",
      "stem": "O is the center of a circle, and T is outside the circle. The tangent segment from the point of tangency to T has length 7, and OT = 10. If the area of the circle is kπ, what is k?",
      "choices": [
        {
          "key": "A",
          "text": "51"
        },
        {
          "key": "B",
          "text": "49"
        },
        {
          "key": "C",
          "text": "√51"
        },
        {
          "key": "D",
          "text": "60"
        }
      ],
      "correct": "A",
      "explanation": "The radius to the point of tangency is perpendicular to the tangent. Thus r²+7²=10², so r²=51. The area is 51π, giving k=51.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 2,
        "source_item": 2,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Circles",
        "lesson_subtopic": "Circle theorems and area",
        "lesson_original_topic": "Circles",
        "lesson_taxonomy_version": "20260929"
      }
    },
    {
      "id": "fade939d-a933-5a95-8448-84620f6bc435",
      "track_id": "est",
      "topic": "Quadratics and polynomials",
      "difficulty": "medium",
      "type": "grid_in",
      "stem": "The table gives several points on the graph of the quadratic function q(x).\n\nx: −5, −3, −1, 1, 3, 5\nq(x): −7, −15, −15, −7, 9, 33\n\nWhat is q(−9)?\nRecord your answer as a number.",
      "choices": [],
      "correct": "33",
      "explanation": "The first differences for a step of 2 are −8, 0, 8, 16, 24, so the constant second difference is 8 and the leading coefficient is 1. The values fit q(x)=x²+4x−12. Therefore q(−9)=81−36−12=33.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 4,
        "source_item": 1,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Quadratics and polynomials",
        "lesson_subtopic": "Quadratic functions and tables",
        "lesson_original_topic": "Quadratics and polynomials",
        "lesson_taxonomy_version": "20260929"
      }
    },
    {
      "id": "40a2b239-15ea-5538-a297-339b61ee30ef",
      "track_id": "est",
      "topic": "Linear functions and slope",
      "difficulty": "medium",
      "type": "mcq",
      "stem": "The lines y = m₁x + 4 and y = m₂x + 3 intersect to the right of the y-axis if and only if which condition holds?",
      "choices": [
        {
          "key": "A",
          "text": "m₁ = m₂"
        },
        {
          "key": "B",
          "text": "m₁ < m₂"
        },
        {
          "key": "C",
          "text": "m₁ > m₂"
        },
        {
          "key": "D",
          "text": "m₁ + m₂ = 0"
        },
        {
          "key": "E",
          "text": "m₁ ≠ m₂"
        }
      ],
      "correct": "B",
      "explanation": "At the intersection, m₁x+4=m₂x+3, so x=−1/(m₁−m₂). For x>0, the denominator must be negative. Therefore m₁−m₂<0, or m₁<m₂.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 5,
        "source_item": 1,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Linear functions and slope",
        "lesson_subtopic": "Intersection and slope conditions",
        "lesson_original_topic": "Linear functions and slope",
        "lesson_taxonomy_version": "20260929"
      }
    },
    {
      "id": "e7ef8a6a-3155-57ad-ae60-fda29c2e525a",
      "track_id": "est",
      "topic": "Linear functions and slope",
      "difficulty": "medium",
      "type": "mcq",
      "stem": "In the xy-plane, the line through (3, m) and (m, 12) passes through the origin. Which value could m be?",
      "choices": [
        {
          "key": "A",
          "text": "−6"
        },
        {
          "key": "B",
          "text": "9"
        },
        {
          "key": "C",
          "text": "1"
        },
        {
          "key": "D",
          "text": "0"
        }
      ],
      "correct": "A",
      "explanation": "Since the line passes through the origin, the slopes from the origin to both listed points are equal: m/3=12/m. Thus m²=36, so m=±6. Of the choices, only −6 is listed.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 5,
        "source_item": 2,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Linear functions and slope",
        "lesson_subtopic": "Lines through the origin",
        "lesson_original_topic": "Linear functions and slope",
        "lesson_taxonomy_version": "20260929"
      }
    },
    {
      "id": "c7fbd005-b09f-5075-b19f-b2da9d124cf2",
      "track_id": "est",
      "topic": "Ratios, percentages and unit conversion",
      "difficulty": "medium",
      "type": "grid_in",
      "stem": "Lucas bought a car for $3,500. He sold it to Brad for 12% less than he paid. Brad then sold it to Amira for 5% more than he paid. How much did Amira pay?\nRecord your answer in dollars.",
      "choices": [],
      "correct": "3234",
      "explanation": "Brad paid 3500×0.88=$3,080. Amira paid 3080×1.05=$3,234.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 8,
        "source_item": 2,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Ratios, percentages and unit conversion",
        "lesson_subtopic": "Successive percentage change",
        "lesson_original_topic": "Ratios, percentages and unit conversion",
        "lesson_taxonomy_version": "20260929"
      }
    },
    {
      "id": "e1c96638-70fb-5b2b-95e4-3e9fb5a0dbfe",
      "track_id": "est",
      "topic": "Quadratics and polynomials",
      "difficulty": "medium",
      "type": "grid_in",
      "stem": "A rectangle has an area of 155 square inches. Its length is 4 inches less than 7 times its width. What is the width, in inches?\nRecord your answer as a number.",
      "choices": [],
      "correct": "5",
      "explanation": "Let w be the width. Then w(7w−4)=155, so 7w²−4w−155=0. The discriminant is 4²+4·7·155=4356=66². The positive root is (4+66)/14=5; the negative root is not a possible width.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 9,
        "source_item": 1,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Quadratics and polynomials",
        "lesson_subtopic": "Quadratic modeling",
        "lesson_original_topic": "Quadratics and polynomials",
        "lesson_taxonomy_version": "20260929"
      }
    },
    {
      "id": "c871d4ca-141b-5068-a566-68b38fc560b4",
      "track_id": "est",
      "topic": "Ratios, percentages and unit conversion",
      "difficulty": "medium",
      "type": "mcq",
      "stem": "In 2008, Zinah earned 14% more than in 2007, and in 2009 she earned 4% more than in 2008. If Zinah earned y times as much in 2009 as in 2007, what is y?",
      "choices": [
        {
          "key": "A",
          "text": "0.5600"
        },
        {
          "key": "B",
          "text": "1.0056"
        },
        {
          "key": "C",
          "text": "1.1800"
        },
        {
          "key": "D",
          "text": "1.1856"
        }
      ],
      "correct": "D",
      "explanation": "Let the 2007 amount be 1. Then the 2008 amount is 1.14 and the 2009 amount is 1.14×1.04=1.1856 times the 2007 amount.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 9,
        "source_item": 2,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Ratios, percentages and unit conversion",
        "lesson_subtopic": "Successive percentage change",
        "lesson_original_topic": "Ratios, percentages and unit conversion",
        "lesson_taxonomy_version": "20260929"
      }
    },
    {
      "id": "dc96305d-be90-53be-af44-6376cb2e18a6",
      "track_id": "est",
      "topic": "Linear functions and slope",
      "difficulty": "easy",
      "type": "mcq",
      "stem": "Line k is defined by y = 7x + 1/8. Line j is perpendicular to line k in the xy-plane. What is the slope of line j?",
      "choices": [
        {
          "key": "A",
          "text": "−8"
        },
        {
          "key": "B",
          "text": "−1/7"
        },
        {
          "key": "C",
          "text": "1/8"
        },
        {
          "key": "D",
          "text": "7"
        }
      ],
      "correct": "B",
      "explanation": "Line k has slope 7. A perpendicular line has slope equal to the negative reciprocal, −1/7.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 10,
        "source_item": 1,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Linear functions and slope",
        "lesson_subtopic": "Perpendicular slopes",
        "lesson_original_topic": "Linear functions and slope",
        "lesson_taxonomy_version": "20260929"
      }
    },
    {
      "id": "16692185-16a4-53c3-b1e4-547f7db14ef9",
      "track_id": "est",
      "topic": "Statistics and data analysis",
      "difficulty": "easy",
      "type": "mcq",
      "stem": "Brad’s average on his last three math tests was 76. What grade should he earn on the fourth test to have an average of 80?",
      "choices": [
        {
          "key": "A",
          "text": "88"
        },
        {
          "key": "B",
          "text": "90"
        },
        {
          "key": "C",
          "text": "92"
        },
        {
          "key": "D",
          "text": "94"
        }
      ],
      "correct": "C",
      "explanation": "The first three scores total 3×76=228. A four-test average of 80 requires a total of 320, so the fourth score must be 320−228=92.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 10,
        "source_item": 2,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Statistics and data analysis",
        "lesson_subtopic": "Mean and averages",
        "lesson_original_topic": "Statistics and data analysis",
        "lesson_taxonomy_version": "20260929"
      }
    },
    {
      "id": "bbba6fb0-9daa-5cf1-9374-3f80b7460810",
      "track_id": "est",
      "topic": "Ratios, percentages and unit conversion",
      "difficulty": "medium",
      "type": "mcq",
      "stem": "From 2018 to 2019, the amount in Julia’s bank account increased by 22.5% to $14,325. To the nearest dollar, what was the amount in her account in 2018?",
      "choices": [
        {
          "key": "A",
          "text": "$11,694"
        },
        {
          "key": "B",
          "text": "$14,010"
        },
        {
          "key": "C",
          "text": "$11,102"
        },
        {
          "key": "D",
          "text": "$12,775"
        }
      ],
      "correct": "A",
      "explanation": "If P was the 2018 balance, then 1.225P=14,325. Thus P=14,325/1.225≈11,693.88, which rounds to $11,694.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 11,
        "source_item": 1,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Ratios, percentages and unit conversion",
        "lesson_subtopic": "Percent increase and reverse calculation",
        "lesson_original_topic": "Ratios, percentages and unit conversion",
        "lesson_taxonomy_version": "20260929"
      }
    },
    {
      "id": "4303079b-1b94-558e-951e-b84b32c61fe4",
      "track_id": "est",
      "topic": "Circles",
      "difficulty": "medium",
      "type": "grid_in",
      "stem": "In the xy-plane, x² + y² − 2kx + 4y − 3k² = 0 is the equation of a circle with center (1/2, −2) and radius √5. What is k?\nRecord your answer as a number.",
      "choices": [],
      "correct": "0.5",
      "explanation": "In standard form, the center is (k, −2), so k=1/2. Completing the square gives r²=4k²+4=5, which is consistent with k=1/2.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 11,
        "source_item": 2,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Circles",
        "lesson_subtopic": "Circle equations",
        "lesson_original_topic": "Circles",
        "lesson_taxonomy_version": "20260929"
      }
    },
    {
      "id": "8718178a-37c6-5acd-8f8e-dd9449825645",
      "track_id": "est",
      "topic": "Ratios, percentages and unit conversion",
      "difficulty": "easy",
      "type": "grid_in",
      "stem": "On a map, 1 cm represents 25 km. If two cities are 7.5 cm apart on the map, what is the actual distance between them, in kilometers?\nRecord your answer as a number.",
      "choices": [],
      "correct": "187.5",
      "explanation": "Multiply the map distance by the scale: 7.5×25=187.5 km.",
      "assets": {
        "source": "teacher_uploaded_notes_20261005",
        "source_document": "Notes_261005_140129.pdf",
        "source_page": 12,
        "source_item": 1,
        "source_sha256": "c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c",
        "release_batch": "20261005_uploaded_notes_est_bank",
        "answer_review": "2026-10-05-independent-solution-and-image-check",
        "verified_release": "20261005_uploaded_notes_est_bank",
        "verification_note": "Transcribed from the uploaded page image; independently solved. The student-facing stem preserves all needed source givens.",
        "curriculum_lesson": "Ratios, percentages and unit conversion",
        "lesson_subtopic": "Scale and unit rates",
        "lesson_original_topic": "Ratios, percentages and unit conversion",
        "lesson_taxonomy_version": "20260929"
      }
    }
  ],
  "excluded": [
    {
      "source_page": 3,
      "source_item": 1,
      "status": "held_source_defect",
      "reason": "Interpreting the printed exponent as (n−1)^4, taking base-3 exponents gives (n−1)^4+4n−11=0. This has two real solutions, approximately −0.963 and 2.211, but the choices do not include a value near 2.211; the single-answer item is not safe to grade."
    },
    {
      "source_page": 3,
      "source_item": 2,
      "status": "held_incomplete_choices",
      "reason": "The printed stem and figure are present, but no answer choices are included in the notes. The solved area is 3√3, which is not a numeric-only grid-in response; do not invent choices or silently change the response format."
    },
    {
      "source_page": 7,
      "source_item": 1,
      "status": "duplicate_skipped",
      "duplicate_of": "a8928d2f-90e9-f05d-6dfd-5425820e7b96",
      "reason": "Same circle center (−2,0), radius 3, shift down 6 and double radius; exact existing EST question."
    },
    {
      "source_page": 8,
      "source_item": 1,
      "status": "duplicate_skipped",
      "duplicate_of": "bb6c8acb-c9e2-532c-ba7d-3306a0d10091",
      "reason": "Same perpendicular-bisector question with the same coordinates and x=8; exact existing EST question."
    },
    {
      "source_page": 11,
      "source_item": 3,
      "status": "duplicate_skipped",
      "duplicate_of": "d4ba140c-c921-52b0-8d2c-a4fb03baafda",
      "reason": "Near-duplicate of the existing EST chained-ratio question: both combine a:b and b:c and ask for a:c. Excluded to avoid repeating the same tested idea."
    },
    {
      "source_page": 6,
      "source_item": 1,
      "status": "held_missing_assumption",
      "reason": "The printed score item does not say the student answered all 50 questions. If unanswered items are allowed and score zero, multiple correct-answer counts can produce 75; the handwritten x+y=50 assumption is not stated in the printed question."
    }
  ],
  "database_notes": {
    "insert_count": 14,
    "update_count": 0,
    "assessment_changes": 0,
    "revision_membership_changes": 0,
    "answer_format": "MCQ keys stored as letter strings; grid-in keys stored as answer strings."
  }
}$packet$::jsonb -> 'questions') loop
   qid:=(r->>'id')::uuid;
   if r->>'track_id'<>'est' then raise exception 'Unexpected track for %',qid; end if;
   if exists(select 1 from questions where id=qid) then raise exception 'Question ID already exists: %',qid; end if;
   if exists(select 1 from questions where track_id='est' and lower(regexp_replace(stem,'[^a-z0-9]+','','g'))=lower(regexp_replace(r->>'stem','[^a-z0-9]+','','g'))) then raise exception 'Normalized stem duplicate found for %',qid; end if;
   if exists(select 1 from exams where qid=any(question_ids)) then raise exception 'Unexpected assessment membership for new ID %',qid; end if;
   insert into questions(id,track_id,topic,difficulty,type,stem,choices,assets)
     values(qid,'est',r->>'topic',r->>'difficulty',r->>'type',r->>'stem',r->'choices',r->'assets');
   insert into question_keys(question_id,correct,explanation)
     values(qid,to_jsonb(r->>'correct'),r->>'explanation');
   insert into audit_log(actor_id,action,target_type,target_id,meta)
     values(null,'question.20261005_uploaded_notes_est_bank','questions',qid::text,jsonb_build_object('release','20261005_uploaded_notes_est_bank','source_sha256','c8866e74eb87ce3401c5e3bd6ea7a7717f889dc70ec6398eedc2d0e89e4ed62c','source_page',r->'assets'->'source_page','source_item',r->'assets'->'source_item','topic',r->>'topic'));
   inserted:=inserted+1;
 end loop;
 if inserted<>14 then raise exception 'Expected 14 new questions; inserted %',inserted; end if;
 select jsonb_build_object(
   'exams',(select md5(coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]')::text) from exams x),
   'assignments',(select md5(coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]')::text) from assignments x),
   'attempts',(select md5(coalesce(jsonb_agg(to_jsonb(x) order by x.id),'[]')::text) from attempts x),
   'answers',(select md5(coalesce(jsonb_agg(to_jsonb(x) order by x.attempt_id,x.question_id),'[]')::text) from attempt_answers x),
   'results',(select md5(coalesce(jsonb_agg(to_jsonb(x) order by x.attempt_id,x.question_id),'[]')::text) from attempt_results x),
   'revision',(select md5(coalesce(jsonb_agg(to_jsonb(x) order by x.question_id),'[]')::text) from revision_items x)
 ) into protected_after;
 if protected_before is distinct from protected_after then raise exception 'Assessment, student history, or revision membership changed'; end if;
end $release$;
commit;
