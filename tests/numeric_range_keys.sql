-- Runs in the disposable CI PostgreSQL database after numeric_range_keys.sql.
-- Exact interval boundaries intentionally do not use the scalar-key tolerance.
begin;
do $$
declare t record; actual boolean; n integer:=0;
begin
 for t in select * from (values
  ('above lower bound','grid_in','6'::text,'"(5, ∞)"'::jsonb,true),
  ('fraction above bound','grid_in','21/4','"(5, ∞)"',true),
  ('arbitrarily near inside','grid_in','5.00000001','"(5, ∞)"',true),
  ('open endpoint excluded','grid_in','5','"(5, ∞)"',false),
  ('fraction equals endpoint','grid_in','10/2','"(5, ∞)"',false),
  ('arbitrarily near outside','grid_in','4.99999999','"(5, ∞)"',false),
  ('negative branch excluded','grid_in','-4','"(5, ∞)"',false),
  ('bounded interval decimal','grid_in','1.5','"(1, 2)"',true),
  ('bounded interval fraction','grid_in','3/2','"(1, 2)"',true),
  ('left endpoint excluded','grid_in','1','"(1, 2)"',false),
  ('right endpoint excluded','grid_in','2','"(1, 2)"',false),
  ('outside bounded interval','grid_in','2.1','"(1, 2)"',false),
  ('closed left endpoint','grid_in','-2','"[-2, 3)"',true),
  ('open right endpoint','grid_in','3','"[-2, 3)"',false),
  ('closed right endpoint','grid_in','3','"(-2, 3]"',true),
  ('unbounded below','grid_in','-1000','"(-∞, -3)"',true),
  ('unbounded below endpoint','grid_in','-3','"(-∞, -3)"',false),
  ('empty interval','grid_in','1','"(1, 1)"',false),
  ('singleton closed interval','grid_in','1','"[1, 1]"',true),
  ('reversed bounds','grid_in','1.5','"(2, 1)"',false),
  ('invalid bound','grid_in','1.5','"(abc, 2)"',false),
  ('extra separator','grid_in','1.5','"(1, 2, 3)"',false),
  ('missing bracket','grid_in','(1, 2','"(1, 2"',false),
  ('NaN bound','grid_in','6','"(5, NaN)"',false),
  ('literal interval response','grid_in','(5, ∞)','"(5, ∞)"',false),
  ('inequality response','grid_in','x > 5','"(5, ∞)"',false),
  ('infinite response','grid_in','Infinity','"(5, ∞)"',false),
  ('NaN response','grid_in','NaN','"(5, ∞)"',false),
  ('fraction infinite response','grid_in','Infinity/2','"(5, ∞)"',false),
  ('zero denominator','grid_in','6/0','"(5, ∞)"',false),
  ('blank response','grid_in','','"(5, ∞)"',false),
  ('null response','grid_in',null,'"(5, ∞)"',false),
  ('interval alternatives','grid_in','-4','["(-∞, -3)","(5, ∞)"]',true),
  ('between alternatives','grid_in','0','["(-∞, -3)","(5, ∞)"]',false),
  ('fraction endpoint key','grid_in','0.75','"(1/2, 3/2)"',true),
  ('unicode negative','grid_in','−1','"(−2, 0)"',true),
  ('legacy equivalent fraction','grid_in','1/2','"0.5"',true),
  ('legacy accepted alternatives','grid_in','2','["1","2"]',true),
  ('legacy incorrect number','grid_in','3','["1","2"]',false),
  ('legacy numeric JSON key','grid_in','4','4',true),
  ('legacy MCQ normalization','mcq',' a ','"A"',true),
  ('legacy alternate MCQ','mcq','D','["B","D"]',true),
  ('legacy incorrect MCQ','mcq','A','["B","D"]',false),
  ('MCQ does not use interval membership','mcq','1.5','"(1, 2)"',false),
  ('void key','grid_in','6','{"void":true}',false),
  ('null key','grid_in','6','null',false)
 ) cases(label,qtype,response,correct,expected)
 loop
  actual=public.answer_matches(t.qtype,to_jsonb(t.response),t.correct);
  if actual is distinct from t.expected then
   raise exception 'Range-key case %: expected %, got %',t.label,t.expected,actual;
  end if;
  n=n+1;
 end loop;
 raise notice 'PASS: % numeric-range and legacy-grading cases',n;
end $$;
rollback;
