-- =====================================================================
--  SAT & EST EXAM PORTAL  —  004  SEED
--  Tracks, plus one small demo exam per track so the portal is testable
--  end to end before the real banks are imported.
--  Abdelrahman Ghoneem | 01116004434
-- =====================================================================

insert into public.tracks (id, name, theme, scoring, default_duration_seconds) values
 ('sat', 'SAT Math',
  '{"accent":"#C9A227","navy":"#14243E","label":"SAT"}'::jsonb,
  '{"min":200,"max":800,"step":10}'::jsonb, 2100),
 ('est', 'EST Math',
  '{"accent":"#2E7D6B","navy":"#14243E","label":"EST"}'::jsonb,
  '{"min":100,"max":400,"step":5}'::jsonb, 3600)
on conflict (id) do update
  set name = excluded.name,
      theme = excluded.theme,
      scoring = excluded.scoring,
      default_duration_seconds = excluded.default_duration_seconds;

-- ---------------------------------------------------------------------
-- Demo content. Safe to delete once the real banks are imported.
-- ---------------------------------------------------------------------
do $$
declare
  q1 uuid; q2 uuid; q3 uuid;
  e1 uuid; e2 uuid;
begin
  if exists (select 1 from public.exams where title like 'Demo %') then
    return;
  end if;

  -- ---- SAT demo ----
  insert into public.questions(track_id, topic, difficulty, type, stem, choices)
  values ('sat','Linear Equations','easy','mcq',
          'If $3x + 7 = 22$, what is the value of $x$?',
          '[{"key":"A","text":"3"},{"key":"B","text":"5"},{"key":"C","text":"7"},{"key":"D","text":"15"}]'::jsonb)
  returning id into q1;
  insert into public.question_keys values (q1, '"B"'::jsonb,
    'Subtract 7 from both sides to get 3x = 15, then divide by 3 to get x = 5.');

  insert into public.questions(track_id, topic, difficulty, type, stem, choices)
  values ('sat','Quadratics','medium','grid_in',
          'What is the positive solution of $x^2 - 5x + 6 = 0$ that is greater than 2?',
          '[]'::jsonb)
  returning id into q2;
  insert into public.question_keys values (q2, '["3"]'::jsonb,
    'Factor as (x-2)(x-3)=0, so x = 2 or x = 3. The solution greater than 2 is 3.');

  insert into public.exams(track_id, title, duration_seconds, question_ids,
                           review_policy, is_published)
  values ('sat','Demo SAT Math — Warm-up', 900, array[q1,q2], 'full_review', true)
  returning id into e1;

  -- ---- EST demo ----
  insert into public.questions(track_id, topic, difficulty, type, stem, choices)
  values ('est','Percentages','easy','mcq',
          'A price of 250 EGP is increased by 20%. What is the new price?',
          '[{"key":"A","text":"270"},{"key":"B","text":"290"},{"key":"C","text":"300"},{"key":"D","text":"320"}]'::jsonb)
  returning id into q3;
  insert into public.question_keys values (q3, '"C"'::jsonb,
    '20% of 250 is 50, so the new price is 250 + 50 = 300 EGP.');

  insert into public.exams(track_id, title, duration_seconds, question_ids,
                           review_policy, is_published)
  values ('est','Demo EST Math — Warm-up', 900, array[q3], 'full_review', true)
  returning id into e2;

  raise notice 'Seeded demo exams: SAT %, EST %', e1, e2;
end $$;
