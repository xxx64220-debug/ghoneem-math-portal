-- Run inside a transaction and always ROLLBACK; no student fixtures persist.
BEGIN;
INSERT INTO questions(id,track_id,topic,difficulty,type,stem,choices,assets) VALUES
 ('10000000-0000-0000-0000-000000000001','est','CI daily quiz','easy','mcq','CI daily quiz 1','[{"key":"A","text":"1"},{"key":"B","text":"2"},{"key":"C","text":"3"},{"key":"D","text":"4"}]','{"verified_release":"2026-09-14-batch-ci"}'),
 ('10000000-0000-0000-0000-000000000002','est','CI daily quiz','easy','mcq','CI daily quiz 2','[{"key":"A","text":"1"},{"key":"B","text":"2"},{"key":"C","text":"3"},{"key":"D","text":"4"}]','{"verified_release":"2026-09-14-batch-ci"}'),
 ('10000000-0000-0000-0000-000000000003','est','CI daily quiz','easy','mcq','CI daily quiz 3','[{"key":"A","text":"1"},{"key":"B","text":"2"},{"key":"C","text":"3"},{"key":"D","text":"4"}]','{"verified_release":"2026-09-14-batch-ci"}'),
 ('10000000-0000-0000-0000-000000000004','est','CI daily quiz','easy','mcq','CI daily quiz 4','[{"key":"A","text":"1"},{"key":"B","text":"2"},{"key":"C","text":"3"},{"key":"D","text":"4"}]','{"verified_release":"2026-09-14-batch-ci"}'),
 ('10000000-0000-0000-0000-000000000005','est','CI daily quiz','easy','mcq','CI daily quiz 5','[{"key":"A","text":"1"},{"key":"B","text":"2"},{"key":"C","text":"3"},{"key":"D","text":"4"}]','{"verified_release":"2026-09-14-batch-ci"}')
ON CONFLICT(id) DO UPDATE SET track_id=excluded.track_id,topic=excluded.topic,difficulty=excluded.difficulty,
 type=excluded.type,stem=excluded.stem,choices=excluded.choices,assets=excluded.assets;
INSERT INTO question_keys(question_id,correct,explanation)
SELECT id,'"A"'::jsonb,'CI fixture answer.' FROM questions
WHERE id BETWEEN '10000000-0000-0000-0000-000000000001'::uuid AND '10000000-0000-0000-0000-000000000005'::uuid
ON CONFLICT(question_id) DO UPDATE SET correct=excluded.correct,explanation=excluded.explanation;
INSERT INTO daily_quizzes(track_id,day,question_ids)
VALUES ('est',(now() at time zone 'Africa/Cairo')::date,ARRAY[
 '10000000-0000-0000-0000-000000000001'::uuid,'10000000-0000-0000-0000-000000000002'::uuid,
 '10000000-0000-0000-0000-000000000003'::uuid,'10000000-0000-0000-0000-000000000004'::uuid,
 '10000000-0000-0000-0000-000000000005'::uuid])
ON CONFLICT(track_id,day) DO UPDATE SET question_ids=excluded.question_ids;
DO $$
DECLARE u uuid; d date := (now() at time zone 'Africa/Cairo')::date; state jsonb; answers jsonb; points int;
BEGIN
 SELECT p.id INTO u FROM profiles p JOIN enrollments e ON e.user_id=p.id
 WHERE p.role='student' AND p.status='active' AND e.track_id='est' AND e.status='active' LIMIT 1;
 IF u IS NULL THEN RAISE EXCEPTION 'No enrolled test subject'; END IF;
 DELETE FROM daily_progress WHERE user_id=u AND track_id='est';
 state:=daily_state(u,'est');
 ASSERT (state#>>'{streak,current}')::int=0;
 ASSERT (state#>>'{streak,longest}')::int=0;
 ASSERT jsonb_array_length(state#>'{streak,week}')=7;
 ASSERT (state#>>'{streak,week,6,date}')::date=d;
 ASSERT (state#>>'{streak,week,6,today}')::boolean;
 ASSERT NOT (state->>'completed')::boolean;
 ASSERT NOT EXISTS(SELECT 1 FROM jsonb_array_elements(state->'quiz') q WHERE q->'answer'<>'null'::jsonb);
 INSERT INTO daily_progress(user_id,track_id,day,quiz_completed_at,quiz_score)
 SELECT u,'est',d-i,now(),0 FROM generate_series(11,40) i;
 INSERT INTO daily_progress(user_id,track_id,day,quiz_completed_at,quiz_score)
 SELECT u,'est',d-i,now(),0 FROM generate_series(1,3) i;
 state:=daily_state(u,'est');
 ASSERT (state#>>'{streak,current}')::int=3;
 ASSERT (state#>>'{streak,longest}')::int=30;
 state:=daily_mark(u,'est','focus');
 ASSERT (state#>>'{streak,current}')::int=3;
 BEGIN PERFORM daily_submit(u,'est','{}'::jsonb); RAISE EXCEPTION 'Empty submission accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'invalid_answers' THEN RAISE; END IF; END;
 SELECT jsonb_object_agg(q->>'id',q#>>'{choices,0,key}') INTO answers FROM jsonb_array_elements(state->'quiz') q;
 BEGIN PERFORM daily_submit(u,'est',answers || jsonb_build_object((state#>>'{quiz,0,id}'),'INVALID')); RAISE EXCEPTION 'Invalid choice accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'invalid_answers' THEN RAISE; END IF; END;
 state:=daily_submit(u,'est',answers);
 ASSERT (state#>>'{streak,current}')::int=4;
 ASSERT (state#>>'{streak,longest}')::int=30;
 ASSERT (state#>>'{streak,week,6,completed}')::boolean;
 points:=(state->>'points_today')::int;
 state:=daily_submit(u,'est',answers);
 ASSERT (state->>'points_today')::int=points;
 ASSERT (state#>>'{streak,current}')::int=4;
 DELETE FROM daily_progress WHERE user_id=u AND track_id='est' AND day=d-1;
 state:=daily_state(u,'est'); ASSERT (state#>>'{streak,current}')::int=1;
 DELETE FROM daily_progress WHERE user_id=u AND track_id='est' AND day=d;
 state:=daily_state(u,'est'); ASSERT (state#>>'{streak,current}')::int=0;
 ASSERT (state#>>'{streak,longest}')::int=30;
 BEGIN PERFORM daily_state(gen_random_uuid(),'est'); RAISE EXCEPTION 'Unauthorised user accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'not_enrolled_in_track' THEN RAISE; END IF; END;
 ASSERT NOT has_function_privilege('anon','public.daily_state(uuid,text)','EXECUTE');
 ASSERT NOT has_function_privilege('authenticated','public.daily_state(uuid,text)','EXECUTE');
 ASSERT has_function_privilege('service_role','public.daily_state(uuid,text)','EXECUTE');
END $$;
SELECT 'PASS: streaks, gaps, history, checklist isolation, complete answers, repeat submission and access checks' AS result;
ROLLBACK;
