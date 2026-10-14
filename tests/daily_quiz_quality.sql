-- Isolated portal_ci only; run with psql -X -qAt -v ON_ERROR_STOP=1.
-- The only stdout is JSON consumed by daily_quiz_quality.test.cjs.
-- Apply the real September 28 repair to synthetic broken rows, never live data.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL plpgsql.check_asserts = on;
DO $$ BEGIN
  ASSERT current_database() = 'portal_ci'
    AND to_regprocedure('public.test_login(uuid,text)') IS NOT NULL,
    'daily quiz regression requires the isolated portal_ci database and Auth shim';
END $$;

-- SAT and EST I come from 004_seed. EST II is a supported active math track
-- (also listed in web/index.html), but its production import is outside CI.
INSERT INTO public.tracks(id,name) VALUES ('est2','EST II Math') ON CONFLICT DO NOTHING;
CREATE TEMP TABLE daily_test_tracks AS
  SELECT id FROM public.tracks WHERE is_active AND id IN ('sat','est','est2');
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM daily_test_tracks) = 3, 'all three active math tracks required';
END $$;
INSERT INTO public.portal_track_controls(track_id)
  SELECT id FROM daily_test_tracks ON CONFLICT DO NOTHING;

CREATE TEMP TABLE repair_cases(
  n integer PRIMARY KEY, id uuid UNIQUE, track_id text, kind text,
  correct jsonb, explanation text
);
INSERT INTO repair_cases VALUES
 (1,'5d91ac0f-4a39-442b-589e-b668c396fa33','est','angle','"B"',
  'In right triangle OBH, sin(angle OBH)=OH/OB=1.6/4=0.4. The angle is 23.6 degrees to the nearest tenth.'),
 (2,'ba73ebd6-fc48-3f20-4799-49f55a3bfc87','est','angle','"B"',
  'In right triangle OBH, sin(angle OBH)=1.6/4, so the angle rounds to 23.6 degrees.'),
 (3,'771d0c68-8e92-24d9-1c4e-0e63488b4176','est','length','"C"',
  'The right triangles OAE and OHB are similar. OE/OB=OA/OH, so OE=4*4/1.6=10 cm.'),
 (4,'b790b995-29fa-bde7-76ec-e0bba55d90bb','est','length','"C"',
  'Similarity gives OE/4=4/1.6, so OE=10 cm.'),
 (5,'e04957e5-b3a2-5e5d-9f1b-f49fb7325540','est','polynomial','"A"',
  'p(x)=(x-2)(x^2+x+1). The common real root is 2, and q(2)=4+4+a=0 gives a=-8.'),
 (6,'a0c46847-72c6-581c-8eae-e24748c74a81','est2','polynomial','"A"',
  'p(2)=8-4-2-2=0. For x-2 to divide q(x), q(2)=8+a=0, so a=-8.');

-- Keys/explanations are independent test fixtures: the repair intentionally
-- preserves them. No archived or production answer snapshot is needed.
INSERT INTO public.questions(id,track_id,topic,type,stem,choices,assets)
SELECT id,track_id,'Broken context fixture','mcq',
  CASE kind WHEN 'angle' THEN 'Question 32. Find angle OBH.'
    WHEN 'length' THEN 'Question 33. Find OE.' ELSE 'Find the common factor parameter.' END,
  '[{"key":"A","text":"A in the original question"},{"key":"B","text":"B in the original question"},{"key":"C","text":"C in the original question"},{"key":"D","text":"D in the original question"},{"key":"E","text":"E in the original question"}]',
  '{"verified_release":"CI September 28 fixture","fixture_metadata":"preserve me"}'
FROM repair_cases;
INSERT INTO public.question_keys(question_id,correct,explanation)
SELECT id,correct,explanation FROM repair_cases;

\ir ../content-releases/20260928_daily_quiz_missing_context.sql

CREATE TEMP TABLE repaired_snapshot AS
  SELECT q.*,k.correct,k.explanation,c.n,c.kind FROM repair_cases c
  JOIN public.questions q ON q.id=c.id JOIN public.question_keys k ON k.question_id=q.id;

-- The existing repair must also be safe to reapply.
\ir ../content-releases/20260928_daily_quiz_missing_context.sql

DO $$
DECLARE r record; text_ text; setup_ text;
BEGIN
  FOR r IN SELECT q.*,k.correct,k.explanation,c.kind,c.correct expected_key,
      c.explanation expected_explanation FROM repair_cases c
      JOIN public.questions q ON q.id=c.id JOIN public.question_keys k ON k.question_id=q.id LOOP
    ASSERT r.correct = r.expected_key AND r.explanation = r.expected_explanation,
      'repair changed an existing key/explanation: ' || r.id;
    ASSERT r.assets->>'fixture_metadata' = 'preserve me', 'repair discarded existing assets';
    ASSERT nullif(r.assets->>'release_hold_reason','') IS NULL, 'repair added a release hold';
    SELECT ch->>'text' INTO text_ FROM jsonb_array_elements(r.choices) ch
      WHERE ch->>'key' = r.correct #>> '{}';
    IF r.kind IN ('angle','length') THEN
      FOREACH setup_ IN ARRAY ARRAY['center O','radius 4 cm','A and K are endpoints of a diameter',
          'AE is tangent','AE is perpendicular to OA','H lies on OK','OH = 1.6 cm',
          'B lies on the circle','BH perpendicular to OK','B, O, E lie on one straight line'] LOOP
        ASSERT position(setup_ IN r.stem)>0, 'missing shared circle context: ' || r.id || ' / ' || setup_;
      END LOOP;
      ASSERT r.assets->>'svg' LIKE '<svg%</svg>', 'missing shared circle SVG: ' || r.id;
      ASSERT r.assets->>'figure_caption' LIKE '%Questions 32 and 33%', 'missing circle caption';
      ASSERT r.topic = 'Coordinate Geometry, Circles & Conics', 'incorrect circle topic';
      IF r.kind='angle' THEN
        ASSERT r.stem LIKE '%Question 32.%angle OBH%', 'wrong angle prompt';
        ASSERT text_ = round(degrees(asin(1.6/4))::numeric,1)::text || '°', 'incorrect angle/key';
      ELSE
        ASSERT r.stem LIKE '%Question 33.%length of OE%', 'wrong length prompt';
        ASSERT text_ = (4*4/1.6)::integer::text || ' cm', 'incorrect tangent length/key';
      END IF;
    ELSE
      ASSERT r.stem LIKE '%p(x) = x³ − x² − x − 2%q(x) = x² + 2x + a%common factor%',
        'missing polynomial context: ' || r.id;
      ASSERT r.choices = '[{"key":"A","text":"−8"},{"key":"B","text":"−3"},{"key":"C","text":"−2"},{"key":"D","text":"2"},{"key":"E","text":"8"}]'::jsonb,
        'missing polynomial choices: ' || r.id;
      ASSERT replace(text_,'−','-')::integer = -(2*2+2*2), 'incorrect polynomial/key';
    END IF;
  END LOOP;
  ASSERT (SELECT count(DISTINCT assets->>'svg') FROM repaired_snapshot WHERE kind IN ('angle','length'))=1,
    'the four circle records must share the same figure';
  ASSERT NOT EXISTS (
    SELECT 1 FROM repaired_snapshot old JOIN public.questions q USING(id)
    JOIN public.question_keys k ON k.question_id=q.id
    WHERE ROW(q.stem,q.topic,q.choices,q.assets,k.correct,k.explanation)
      IS DISTINCT FROM ROW(old.stem,old.topic,old.choices,old.assets,old.correct,old.explanation)
  ), 'repair is not idempotent';
END $$;

-- Replay the repaired content on every active math track. The seventh template
-- checks that four-choice MCQs and table context remain eligible too.
CREATE TEMP TABLE daily_templates AS SELECT n,kind,stem,choices,assets,correct,explanation FROM repaired_snapshot;
INSERT INTO daily_templates VALUES (7,'table','The table gives the number of students in each group. How many students are there in total?',
 '[{"key":"A","text":"1"},{"key":"B","text":"3"},{"key":"C","text":"4"},{"key":"D","text":"7"}]',
 '{"verified_release":"CI table fixture","html":"<table><caption>Students by group</caption><tr><th>Group</th><th>Students</th></tr><tr><td>Red</td><td>3</td></tr><tr><td>Blue</td><td>4</td></tr></table>"}',
 '"D"','The total number of students is 3+4=7.');
CREATE TEMP TABLE daily_test_bank AS
SELECT md5('daily-quality:'||t.id||':'||f.n)::uuid id,t.id track_id,f.*
FROM daily_test_tracks t CROSS JOIN daily_templates f;
INSERT INTO public.questions(id,track_id,topic,type,stem,choices,assets)
SELECT id,track_id,'CI daily lesson','mcq',stem,choices,assets FROM daily_test_bank;
INSERT INTO public.question_keys(question_id,correct,explanation)
SELECT id,correct,explanation FROM daily_test_bank;

INSERT INTO auth.users(id,email) VALUES ('28000000-0000-0000-0000-000000000001','daily-quality@example.test');
INSERT INTO public.profiles(id,full_name,role,status)
VALUES ('28000000-0000-0000-0000-000000000001','Daily Quality Fixture','student','active')
ON CONFLICT(id) DO UPDATE SET role='student',status='active';
INSERT INTO public.enrollments(user_id,track_id)
SELECT '28000000-0000-0000-0000-000000000001',id FROM daily_test_tracks;
CREATE TEMP TABLE daily_client_cases(track text,mode text,cohort integer,phase text,payload jsonb);
GRANT SELECT ON daily_test_tracks,daily_test_bank TO service_role;
GRANT INSERT,SELECT ON daily_client_cases TO service_role;
-- The minimal local Auth shim supplies BYPASSRLS, not hosted table grants.
-- Supply only the privileges this service-role scenario uses, inside ROLLBACK.
GRANT SELECT ON public.tracks,public.profiles,public.enrollments TO service_role;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.questions,public.question_keys,
  public.daily_quizzes,public.daily_progress TO service_role;

CREATE FUNCTION pg_temp.daily_test_pool(track_ text,ids_ uuid[],mode_ text) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
  -- Only disposable fixture state is affected; the enclosing transaction rolls
  -- back the pool isolation, test enrollments, frozen quizzes and scores.
  UPDATE public.questions SET assets=assets||'{"release_hold_reason":"CI pool isolation"}'::jsonb
    WHERE track_id=track_;
  UPDATE public.questions q SET assets=b.assets,choices=b.choices,type='mcq',topic='CI daily lesson'
    FROM daily_test_bank b WHERE q.id=b.id AND q.id=ANY(ids_);
  INSERT INTO public.question_keys(question_id,correct,explanation)
    SELECT id,correct,explanation FROM daily_test_bank WHERE id=ANY(ids_)
    ON CONFLICT(question_id) DO UPDATE SET correct=excluded.correct,explanation=excluded.explanation;
  UPDATE public.portal_track_controls SET daily_mode=mode_,daily_question_ids=ids_,daily_lessons=ARRAY['CI daily lesson']
    WHERE track_id=track_;
  DELETE FROM public.daily_progress WHERE track_id=track_ AND day=(now() AT TIME ZONE 'Africa/Cairo')::date;
  DELETE FROM public.daily_quizzes WHERE track_id=track_ AND day=(now() AT TIME ZONE 'Africa/Cairo')::date;
END $$;

SET LOCAL ROLE service_role;
DO $$
DECLARE track_ text; mode_ text; cohort_ integer; ids_ uuid[]; state_ jsonb;
  q jsonb; c jsonb; expected_ record; answers_ jsonb; bad_ uuid; defect_ text;
  u constant uuid := '28000000-0000-0000-0000-000000000001';
  d date := (now() AT TIME ZONE 'Africa/Cairo')::date;
BEGIN
  FOR track_ IN SELECT id FROM daily_test_tracks ORDER BY id LOOP
    FOREACH mode_ IN ARRAY ARRAY['random','lessons','selected'] LOOP
      FOR cohort_ IN 1..2 LOOP
        SELECT array_agg(id ORDER BY n) INTO ids_ FROM daily_test_bank WHERE track_id=track_
          AND n=ANY(CASE cohort_ WHEN 1 THEN ARRAY[1,2,3,4,7] ELSE ARRAY[3,4,5,6,7] END);
        PERFORM pg_temp.daily_test_pool(track_,ids_,mode_);
        ASSERT NOT EXISTS(SELECT 1 FROM public.daily_quizzes WHERE track_id=track_ AND day=d), 'test must generate a fresh quiz';
        state_:=public.daily_state(u,track_);
        ASSERT state_->>'track'=track_ AND state_->>'selection_mode'=mode_, 'track/mode mismatch';
        ASSERT jsonb_array_length(state_->'quiz')=5, 'expected five generated questions';
        ASSERT (SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(state_->'quiz') x)=5, 'duplicate daily question';
        ASSERT (SELECT question_ids @> ids_ AND question_ids <@ ids_ FROM public.daily_quizzes WHERE track_id=track_ AND day=d),
          'generated quiz did not use the complete eligible pool';
        FOR q IN SELECT value FROM jsonb_array_elements(state_->'quiz') LOOP
          SELECT b.*,p.type INTO STRICT expected_ FROM daily_test_bank b JOIN public.questions p USING(id)
            WHERE b.id=(q->>'id')::uuid AND b.track_id=track_;
          ASSERT q->>'stem'=expected_.stem AND length(btrim(q->>'stem'))>0, 'context lost in daily response';
          ASSERT q->'assets'=expected_.assets, 'figure/table/metadata lost in daily response';
          ASSERT q->'choices'=expected_.choices AND jsonb_array_length(q->'choices')>=4, 'daily choices changed or missing';
          ASSERT expected_.type='mcq' AND nullif(q#>>'{assets,verified_release}','') IS NOT NULL, 'unverified/non-MCQ selected';
          ASSERT nullif(q#>>'{assets,release_hold_reason}','') IS NULL, 'held question selected';
          FOR c IN SELECT value FROM jsonb_array_elements(q->'choices') LOOP
            ASSERT jsonb_typeof(c->'text')='string' AND length(btrim(c->>'text'))>0
              AND c->>'text' NOT ILIKE '%in the original question%', 'non-real answer choice';
          END LOOP;
          ASSERT jsonb_typeof(expected_.correct)='string' AND length(btrim(expected_.explanation))>0, 'invalid key/explanation';
          ASSERT (SELECT count(*) FROM jsonb_array_elements(q->'choices') ch WHERE ch->'key'=expected_.correct)=1,
            'correct key must match exactly one displayed choice';
          ASSERT q->'answer'='null'::jsonb AND NOT q ?| ARRAY['correct','explanation'], 'answer leaked before submission';
        END LOOP;
        INSERT INTO daily_client_cases VALUES(track_,mode_,cohort_,'before',state_);
        ASSERT public.daily_state(u,track_)->'quiz'=state_->'quiz', 'reopening changed the frozen questions';
        -- A later pool edit must preserve an already-opened set.
        UPDATE public.portal_track_controls SET daily_mode='selected',daily_question_ids='{}' WHERE track_id=track_;
        ASSERT public.daily_state(u,track_)->'quiz'=state_->'quiz', 'pool edit changed a frozen quiz';
        SELECT jsonb_object_agg(id::text,correct) INTO answers_ FROM daily_test_bank WHERE id=ANY(ids_);
        state_:=public.daily_submit(u,track_,answers_);
        ASSERT (state_->>'completed')::boolean AND (state_->>'score')::int=5, 'verified keys did not score 5/5';
        FOR q IN SELECT value FROM jsonb_array_elements(state_->'quiz') LOOP
          SELECT * INTO STRICT expected_ FROM daily_test_bank WHERE id=(q->>'id')::uuid;
          ASSERT q#>'{answer,correct}'=expected_.correct AND q#>'{answer,submitted}'=expected_.correct,
            'completed answer does not match its question';
          ASSERT q#>>'{answer,explanation}'=expected_.explanation, 'completed explanation missing or mismatched';
        END LOOP;
        INSERT INTO daily_client_cases VALUES(track_,mode_,cohort_,'after',state_);
      END LOOP;

      -- Four good rows + one defective row makes every rejection deterministic,
      -- independent of md5 ordering or the Cairo calendar date.
      SELECT array_agg(id ORDER BY n) INTO ids_ FROM daily_test_bank WHERE track_id=track_ AND n IN (1,2,3,4,7);
      bad_:=ids_[5];
      FOREACH defect_ IN ARRAY ARRAY['placeholder_distractor','placeholder_correct_mixed_case',
          'unverified_missing','unverified_empty','unverified_null','release_hold','grid_in',
          'three_choices','missing_key','array_key','null_key','numeric_key','unmatched_key',
          'empty_explanation','whitespace_explanation'] LOOP
        PERFORM pg_temp.daily_test_pool(track_,ids_,mode_);
        CASE defect_
          WHEN 'placeholder_distractor' THEN UPDATE public.questions SET choices=jsonb_set(choices,'{0,text}','"Option A in the original question"') WHERE id=bad_;
          WHEN 'placeholder_correct_mixed_case' THEN UPDATE public.questions SET choices=jsonb_set(choices,'{3,text}','"See option D IN THE ORIGINAL QUESTION for the answer"') WHERE id=bad_;
          WHEN 'unverified_missing' THEN UPDATE public.questions SET assets=assets-'verified_release' WHERE id=bad_;
          WHEN 'unverified_empty' THEN UPDATE public.questions SET assets=jsonb_set(assets,'{verified_release}','""') WHERE id=bad_;
          WHEN 'unverified_null' THEN UPDATE public.questions SET assets=jsonb_set(assets,'{verified_release}','null') WHERE id=bad_;
          WHEN 'release_hold' THEN UPDATE public.questions SET assets=assets||'{"release_hold_reason":"Needs source review"}'::jsonb WHERE id=bad_;
          WHEN 'grid_in' THEN UPDATE public.questions SET type='grid_in' WHERE id=bad_;
          WHEN 'three_choices' THEN UPDATE public.questions SET choices=choices-0 WHERE id=bad_;
          WHEN 'missing_key' THEN DELETE FROM public.question_keys WHERE question_id=bad_;
          WHEN 'array_key' THEN UPDATE public.question_keys SET correct='["D"]' WHERE question_id=bad_;
          WHEN 'null_key' THEN UPDATE public.question_keys SET correct='null' WHERE question_id=bad_;
          WHEN 'numeric_key' THEN UPDATE public.question_keys SET correct='4' WHERE question_id=bad_;
          WHEN 'unmatched_key' THEN UPDATE public.question_keys SET correct='"Z"' WHERE question_id=bad_;
          WHEN 'empty_explanation' THEN UPDATE public.question_keys SET explanation='' WHERE question_id=bad_;
          WHEN 'whitespace_explanation' THEN UPDATE public.question_keys SET explanation='   ' WHERE question_id=bad_;
        END CASE;
        BEGIN
          PERFORM public.daily_state(u,track_);
          RAISE EXCEPTION 'accepted defective daily candidate: % / % / %',track_,mode_,defect_;
        EXCEPTION WHEN SQLSTATE 'P0001' THEN
          IF SQLERRM<>'daily_questions_unavailable' THEN RAISE; END IF;
        END;
        ASSERT NOT EXISTS(SELECT 1 FROM public.daily_quizzes WHERE track_id=track_ AND day=d), 'failed generation saved a partial quiz';
        ASSERT NOT EXISTS(SELECT 1 FROM public.daily_progress WHERE user_id=u AND track_id=track_ AND day=d), 'failed generation saved progress';
      END LOOP;
      RAISE NOTICE 'PASS: % / %: repaired context, fresh/frozen quizzes, keys, explanations and 15 rejection cases',track_,mode_;
    END LOOP;
  END LOOP;
END $$;
RESET ROLE;

-- Export actual RPC payloads for the production client-rendering tests.
SELECT jsonb_build_object('tracks',(SELECT jsonb_agg(id ORDER BY id) FROM daily_test_tracks),
  'templates',(SELECT jsonb_agg(to_jsonb(b) ORDER BY track_id,n) FROM daily_test_bank b),
  'cases',(SELECT jsonb_agg(to_jsonb(c) ORDER BY track,mode,cohort,phase) FROM daily_client_cases c));
ROLLBACK;
