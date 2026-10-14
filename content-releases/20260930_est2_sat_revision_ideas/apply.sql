begin;
lock table public.questions, public.question_keys, public.revision_items, public.audit_log in share row exclusive mode;

create temporary table est2_sat_revision_idea_release_20260930 on commit drop as
select * from jsonb_to_recordset('[{"id":"770026cc-f1d9-51eb-b124-4b4dd75bf90d","track":"est2","lesson":"Functions and transformations","idea":"Solving a fixed-point equation with absolute value","fingerprint":"c8bd0ce8cf0a0cadf114f690019fe1de"},{"id":"2c4d101b-57da-54c6-b312-53d68f0f522a","track":"est2","lesson":"Functions and transformations","idea":"Interpreting input and output in a function model","fingerprint":"7159a1364de5e53a2f4a2e6ab7b97549"},{"id":"5a73282b-5df0-5e11-932b-3da080f93302","track":"est2","lesson":"Functions and transformations","idea":"Finding an inverse relation of a shifted square","fingerprint":"e02c7555e1b75deae4a5012673a4c329"},{"id":"0bd86cbf-8704-54be-8c51-08d98401913f","track":"est2","lesson":"Functions and transformations","idea":"Matching a graph to a piecewise formula","fingerprint":"1223832d709c07789a6adad4fcde4f64"},{"id":"427b4627-3d6c-5b2a-8490-8a7cf1272b3e","track":"est2","lesson":"Functions and transformations","idea":"Distinguishing holes from asymptotes in a rational function","fingerprint":"26603f23e921afd16da8f71bcb5c4bef"},{"id":"435a674f-a11f-544c-a740-04115f2b4810","track":"est2","lesson":"Functions and transformations","idea":"Evaluating nested composite functions","fingerprint":"d7c6dfa2f3931d528048d0f89193505f"},{"id":"45bccf82-49f4-5b2d-b55d-383451dcdaf2","track":"est2","lesson":"Functions and transformations","idea":"Identifying a vertical stretch of an exponential graph","fingerprint":"8383ed108f445f21ef3d75b29c4ad8eb"},{"id":"fc8a09b6-8ecf-5f25-b476-694696e116f0","track":"est2","lesson":"Functions and transformations","idea":"Recognizing origin symmetry of an odd function","fingerprint":"6d3a0f757d188ae7bf86b2cf83da451a"},{"id":"0d96db51-5e91-56c8-bbf0-1bcace472c3d","track":"est2","lesson":"Quadratics and polynomials","idea":"Coefficient matching in a difference-of-squares identity","fingerprint":"97a4c59b9c6851857308c437a9543a2c"},{"id":"b14f065a-bd3e-506b-ae40-a519eac6959c","track":"est2","lesson":"Quadratics and polynomials","idea":"Deducing an integer from expanded polynomial coefficients","fingerprint":"50805b670e997e77a58be1a835b775e7"},{"id":"428d6c33-f983-5913-a643-a93a8a466bb3","track":"est2","lesson":"Quadratics and polynomials","idea":"Matching coefficients in a perfect-square identity","fingerprint":"eaa33ef70e5009f88dccc0810b140686"},{"id":"38122a5d-9688-5469-9eb4-27bb5f00cb96","track":"est2","lesson":"Quadratics and polynomials","idea":"Using parabola symmetry around a maximum","fingerprint":"c2f1a5987d074bd62496915843e6dbdd"},{"id":"07012d2a-43af-5685-9f18-bb764cec89b5","track":"est2","lesson":"Quadratics and polynomials","idea":"Evaluating a projectile model from vertex data","fingerprint":"299d7e9f02bc899466e889eea0aaffb4"},{"id":"d010ff98-e902-5a48-968a-d5561b69b577","track":"est2","lesson":"Quadratics and polynomials","idea":"Finding a Vieta expression invariant under a coefficient change","fingerprint":"c1b721a9741fc90b61c4fa1e0c9d9570"},{"id":"7ac32843-d3cb-5162-b4d5-f3fae02bec32","track":"est2","lesson":"Quadratics and polynomials","idea":"Counting real roots of a factored polynomial","fingerprint":"19ea6f808b7accb03ab08f598f7c824e"},{"id":"b277c856-c263-5cf9-b85b-58118b05a14c","track":"est2","lesson":"Triangles and similarity","idea":"Chaining similarity and congruence in an isosceles trapezoid","fingerprint":"27a9201ee6c89f784949c60c3282090c"},{"id":"b927982b-5e81-56d8-a4e4-3de4ff419aab","track":"est2","lesson":"Triangles and similarity","idea":"Resolving the ambiguous sine-law case for area","fingerprint":"cdd48b524b502ed5feb78901816554be"},{"id":"80c4c753-bdbf-5f83-abc9-4c411d5eff71","track":"est2","lesson":"Triangles and similarity","idea":"Triangle area from coordinate base and height","fingerprint":"dd37bb64a684b468ebe346f690bd5ef7"},{"id":"5d2f5f27-f24a-5124-a7e5-edb068bac5e0","track":"est2","lesson":"Triangles and similarity","idea":"Justifying corresponding angles in a parallel-line proof","fingerprint":"0b8e30319b2adeab49eee121d375ebee"},{"id":"5d9d9aa4-0a9f-5f3c-8685-63e22a3d8518","track":"est2","lesson":"Triangles and similarity","idea":"Area of a 30-60-90 triangle from the hypotenuse","fingerprint":"4c0294c8bc7752eb0418efd3116c22f2"},{"id":"0878de38-4f1d-5e94-a9ed-ebbbc6a10bc7","track":"est2","lesson":"Triangles and similarity","idea":"Finding a triangle angle using an interior parallel segment","fingerprint":"4fb9ca91c122a52b6cb789382066198c"},{"id":"61c7269a-79f9-5171-9ca0-d5d55ec8a95c","track":"est2","lesson":"Triangles and similarity","idea":"Recovering an equilateral side from its altitude","fingerprint":"e3df4c264b7467cbcf128d7d7fde1ab9"},{"id":"e85a7456-9b0d-5138-b9b8-5e5537cde9a1","track":"est2","lesson":"Inequalities and absolute value","idea":"Counting solutions of an absolute-value equation","fingerprint":"0b884ab6f91e76f47a796c587d19ce91"},{"id":"2f8d8c77-2859-5f4c-944e-b203a065d3f0","track":"est2","lesson":"Inequalities and absolute value","idea":"Solving an equal-distance absolute-value equation","fingerprint":"c2d58d893c2f1bd884eb4ac8e9183e0b"},{"id":"9a7dc7ba-ba82-5652-ba95-13a18340dee5","track":"est2","lesson":"Inequalities and absolute value","idea":"Testing a point in a nonlinear inequality system","fingerprint":"076326217c3a3b937211a3c4fe57f000"},{"id":"b67bc54b-cde7-510b-bc7c-172e6e527ecc","track":"est2","lesson":"Inequalities and absolute value","idea":"Describing a region between a parabola and a line","fingerprint":"a395c027c312cbdac5920ff92f2882a4"},{"id":"5cb9629f-83da-5cdd-a800-024478c76729","track":"est2","lesson":"Inequalities and absolute value","idea":"Testing a point against three strict inequalities","fingerprint":"f20b18864fe3ecbc72fb5968b50bd7c5"},{"id":"76a4276d-6846-5db4-9def-0701c8aa763d","track":"est2","lesson":"Angles and polygons","idea":"Parallelogram area from adjacent sides and included angle","fingerprint":"08c99c73bad7bc381eff8e642ca7cb30"},{"id":"7d89850d-590c-56c1-b8d8-4b70c225f599","track":"est2","lesson":"Angles and polygons","idea":"Perimeter of an L-shaped polygon from missing dimensions","fingerprint":"b49a0981ae7dd29593f23cf49551b2dd"},{"id":"fa3cde1c-a38b-5706-bf1d-d72f6f2d6dd5","track":"est2","lesson":"Angles and polygons","idea":"Identifying a non-converse for parallel lines","fingerprint":"013ebe6e8f054f51f6737387c8b0c55c"},{"id":"a1ea88e6-efb5-5c0f-b759-e32ca8acfd7b","track":"est2","lesson":"Angles and polygons","idea":"Combining parallel-line angle transfer with triangle sum","fingerprint":"da8b93d0ba5cfd177ea51d6a77a785ea"},{"id":"28e44bb3-675e-5c92-bec9-b75f5c48b034","track":"est2","lesson":"Trigonometry","idea":"Locating intersections of sine and cosine graphs by quadrant","fingerprint":"a5cf2d1bd323cf7e92bb8abee0331a6e"},{"id":"77400e2a-a414-5b01-857d-0c94f2e7c901","track":"est2","lesson":"Trigonometry","idea":"Distinguishing exact trig solution families from approximations","fingerprint":"0e787307e43e15af7a1eb6e4cc2fb092"},{"id":"3de9cf47-9016-5190-aea4-ee1f303e4019","track":"est2","lesson":"Trigonometry","idea":"Calculating sine from right-triangle side lengths","fingerprint":"a7e570042cd1eaedfed5e8405e4915c4"},{"id":"53c05476-878d-5178-8816-98ded6f8655d","track":"est2","lesson":"Linear functions and slope","idea":"Parameter condition for a linear equation with no solution","fingerprint":"192bb975d9dd64132b55b57303c1a8df"},{"id":"5b77caf3-385a-5688-8e1e-15f96eb7aa05","track":"est2","lesson":"Linear functions and slope","idea":"Recognizing an identity with infinitely many solutions","fingerprint":"ece0a1b5a2a8134b1f034e832769bb29"},{"id":"68c1daac-cd10-5dc7-a048-24089b7ede0c","track":"est2","lesson":"Linear functions and slope","idea":"Matching coefficients and constants for an identity","fingerprint":"5fd84327be6ccc234b538ee915278b2e"},{"id":"a75cddc1-a40b-5325-b6d9-b9137d171417","track":"est2","lesson":"Linear functions and slope","idea":"Extrapolating a linear table","fingerprint":"e07f1169d68a15c1e1a3f80ecfc7f2f6"},{"id":"f9b3d45a-9b2b-5925-b1c8-2c4a1e2acfd3","track":"est2","lesson":"Linear functions and slope","idea":"Testing collinearity relations with symbolic coordinates","fingerprint":"b001c3b745277a0436aefbbe5cc2911b"},{"id":"95f36f97-7be2-5988-a2f9-fa17d6122050","track":"est2","lesson":"Systems of equations","idea":"Eliminating a variable in a parameterized two-equation system","fingerprint":"36e88c2b82fe07ee636f1b0a75cfd162"},{"id":"3e16380f-3640-4941-bcb2-48db723d4f44","track":"sat","lesson":"Algebraic expressions and equations","idea":"Isolating a subject from a formula with a fractional term","fingerprint":"ab558d117352c2bfe7f4e1114a2c6eec"},{"id":"28c6aa22-0fb7-4412-8c8d-2217824e9d78","track":"sat","lesson":"Algebraic expressions and equations","idea":"Using nonnegative squares whose sum is zero","fingerprint":"8dab32ecba5dceef833ee593f6a09efd"},{"id":"9e59abd1-ed34-4770-a32c-27e08bfc16ab","track":"sat","lesson":"Algebraic expressions and equations","idea":"Rearranging a rational formula for a variable","fingerprint":"ccaed0116b2d902f98953b02945e81bb"},{"id":"b17ebdf7-f356-4c02-9738-023d4341f912","track":"sat","lesson":"Algebraic expressions and equations","idea":"Identifying a missing factor after distribution","fingerprint":"788349666f2b8d4c266bab21ae0edcc1"},{"id":"152a5ab8-dc6d-4814-96b8-78336395a00b","track":"sat","lesson":"Systems of equations","idea":"Modeling item count and total cost with a system","fingerprint":"e6977ce36332ba625b7d21e4cf8e4270"},{"id":"1d3c42eb-04f4-4611-b516-3b288d0d10eb","track":"sat","lesson":"Systems of equations","idea":"Selecting the positive intersection of a line and parabola","fingerprint":"ef6f077bbf4e4fff9639f39c0845857a"},{"id":"22d58763-b9a5-422f-97a4-cae26f1e6f10","track":"sat","lesson":"Systems of equations","idea":"Recognizing a no-solution system of parallel lines","fingerprint":"fea5005a0f92a1828a8c8aad5d3f38ee"},{"id":"230d9f27-4020-47e7-b5fb-fa3897a9261b","track":"sat","lesson":"Systems of equations","idea":"Solving a two-category count-and-cost system","fingerprint":"a5754ebe1d4bef78e45fd2cfd4098051"},{"id":"48e5876a-6b64-49c1-8725-a3cc51efbf63","track":"sat","lesson":"Systems of equations","idea":"Finding a possible coordinate product from a nonlinear system","fingerprint":"d8f495cf2ddc424c931c65b790e09eef"},{"id":"4ff074e2-0470-43dc-9dc7-9fcff89183a1","track":"sat","lesson":"Systems of equations","idea":"Evaluating a linear combination after solving a system","fingerprint":"1e7a7f7e2f15f3ca8b2f7e51f1f5f6b3"},{"id":"0606b2b5-176d-4f3f-a11c-d13c77b52847","track":"sat","lesson":"Linear functions and slope","idea":"Scaling a linear rate over a time interval","fingerprint":"0925ba507609c3f8f1741a21c1b07010"},{"id":"0d6b71b9-3481-4ac0-9ff7-cb6343df3752","track":"sat","lesson":"Linear functions and slope","idea":"Comparing model outputs when a fixed charge cancels","fingerprint":"d0b24d4c3a2b3df4efe91b3285c330b8"},{"id":"138dea78-0f8a-4e75-9340-91f1c514bc93","track":"sat","lesson":"Linear functions and slope","idea":"Finding a point on a perpendicular line from its intercept","fingerprint":"b9bf790c451e0ffa47b01689d9ebfb08"},{"id":"213ca4c5-0223-46e5-bf1c-986734acfc53","track":"sat","lesson":"Linear functions and slope","idea":"Building a first-hour plus additional-hour cost model","fingerprint":"3b6b5e42fe7e4aa5ad9ca5496263747f"},{"id":"4e5ef664-63ec-4348-b43a-5bd60cdf1a89","track":"sat","lesson":"Linear functions and slope","idea":"Recovering fixed fee and unit rate from two data points","fingerprint":"35d4f9547096e55776f9cf92986f10c3"},{"id":"02681132-3bc4-463e-8dd8-3d2e391ecc35","track":"sat","lesson":"Quadratics and polynomials","idea":"Using the discriminant for exactly one real intersection","fingerprint":"ea2ae1994d99a65d0679dea157895eaa"},{"id":"19f1c051-e499-4195-ab05-ea92d2036d71","track":"sat","lesson":"Quadratics and polynomials","idea":"Reading roots and opening direction from factored form","fingerprint":"4baa510bda878bfc71b829967c00391e"},{"id":"1e8d7052-98ac-44df-a137-bff1a4101b04","track":"sat","lesson":"Quadratics and polynomials","idea":"Accepting either root of a factored grid-in equation","fingerprint":"54ec0294b8d91f7be2c3febdc64160b1"},{"id":"1f5ae1c4-7033-415e-ae23-3c84f126ed43","track":"sat","lesson":"Quadratics and polynomials","idea":"Factoring a difference of fourth powers","fingerprint":"9b369a595f62914207f6ae9b51719744"},{"id":"20576c86-59ef-4c41-b324-7e6419f4fa79","track":"sat","lesson":"Quadratics and polynomials","idea":"Choosing a polynomial with exactly two positive zeros","fingerprint":"09d6c40b14932dbb009d5f1e02f31374"},{"id":"231f13e5-d1f9-4595-8a44-c7bed1a815e3","track":"sat","lesson":"Quadratics and polynomials","idea":"Finding a vertex value from factored roots","fingerprint":"d3985adf7f8a607c810c8191db1db164"},{"id":"3448fdac-01c3-4871-b011-c274bd6f47be","track":"sat","lesson":"Quadratics and polynomials","idea":"Subtracting polynomial expressions and finding a coefficient","fingerprint":"a8cf741bc852d23e009110fdf364414a"},{"id":"382d192f-4638-488c-9085-de10e169dc43","track":"sat","lesson":"Functions and transformations","idea":"Translating a parabola horizontally","fingerprint":"999750e609c7c8d7b2171769cb4e449e"},{"id":"41dcbd06-8207-4ab4-9f92-38dbdae988ed","track":"sat","lesson":"Functions and transformations","idea":"Combining a horizontal shift with a vertical reflection","fingerprint":"fa808cbb10e3d37a3932089182adba95"},{"id":"48c84b71-a488-44d0-98c7-38259c34bcb6","track":"sat","lesson":"Functions and transformations","idea":"Interpreting a function constant as an initial value","fingerprint":"9dddd12de35a903a2c13cef5b6cbf8aa"},{"id":"49909356-7635-43d1-8de5-2e840a943008","track":"sat","lesson":"Functions and transformations","idea":"Selecting a parameter for rational-expression cancellation","fingerprint":"92ebc583443a1d608a47a33f1e0e125c"},{"id":"9d19b57b-a01a-41fc-8e5b-f67600bb3462","track":"sat","lesson":"Functions and transformations","idea":"Evaluating a function over restricted integer inputs","fingerprint":"aa7f752f1b7cd25e7fa37bab07a7c424"},{"id":"157c9c4e-8b08-4360-a95a-f7521b93e9f3","track":"sat","lesson":"Inequalities and absolute value","idea":"Translating resource and minimum constraints into inequalities","fingerprint":"a2676e1b99d7d88674bf65fd427d2c0f"},{"id":"8cc29206-7727-4cd9-a08e-5761366a9fce","track":"sat","lesson":"Inequalities and absolute value","idea":"Minimizing a product mix under a profit inequality","fingerprint":"066780ea408bcdd2a214f034d2e55696"},{"id":"0d27a72a-a77e-453f-af24-a86fcf102415","track":"sat","lesson":"Inequalities and absolute value","idea":"Representing inclusive estimation error with a compound inequality","fingerprint":"2a8c734aca98e57f10ad3b401167f192"},{"id":"d4dce377-ac57-4982-a05b-b0549e2003af","track":"sat","lesson":"Ratios, percentages and unit conversion","idea":"Undoing a fixed recording ratio","fingerprint":"e4b6408fbdd4b58276ada199a62e0fb9"},{"id":"af2c9ddb-7970-4cc9-a4ab-6c7f218b66b4","track":"sat","lesson":"Ratios, percentages and unit conversion","idea":"Solving inverse variation from a constant product","fingerprint":"22feecf8a1adae250a267f47bd5d5206"},{"id":"3b2e96ac-13ab-4237-a876-40cec92d571e","track":"sat","lesson":"Triangles and similarity","idea":"Judging whether information is sufficient for triangle congruence","fingerprint":"29c94eff112b0e88f1de8e7f7bf8345a"},{"id":"e8092230-3f69-a033-da8e-76c2259524c5","track":"sat","lesson":"Triangles and similarity","idea":"Ruling out a side equality from unequal base angles","fingerprint":"76a4e76d8f66e8a8e189a14d09243360"},{"id":"6b24b9ff-1108-4291-9b51-4e3d31a0e194","track":"sat","lesson":"Trigonometry","idea":"Finding a hypotenuse from tangent and vertical height","fingerprint":"e5305f16d39e501a0330223520a50c4f"},{"id":"b3c79ce3-fba9-4ed0-8d6c-53a69e2ef444","track":"sat","lesson":"Exponents, radicals and growth","idea":"Relating two radicals by isolating and squaring","fingerprint":"ced0afcafe8a8f9a8209ceb5e5d0b88a"},{"id":"a0454173-a83e-467c-aa30-9bd602639a26","track":"sat","lesson":"Statistics and data analysis","idea":"Interpreting a line-of-best-fit slope in context","fingerprint":"650c0c723d488a56af332a4edc1ac15e"},{"id":"c09a1ac8-37f7-4870-931b-64ac5fb657d2","track":"sat","lesson":"Desmos calculator guidance","idea":"Finding a line intersection with a graphing calculator","fingerprint":"6ae3f613005bf2d0eeecda0f012c58ed"},{"id":"252f3539-1756-4c52-9581-a99510de5a44","track":"sat","lesson":"Logarithms and exponentials","idea":"Recognizing exponential decay from a remaining fraction","fingerprint":"836defddabe6b18c55be6396970b8dd6"},{"id":"c082373c-ffb4-417c-8e02-8eabee22ed57","track":"sat","lesson":"Complex numbers","idea":"Multiplying complex conjugates","fingerprint":"a5eb171ec689467123bf00a1c7f6c990"}]'::jsonb)
 as r(id uuid,track text,lesson text,idea text,fingerprint text);

do $est2_sat_revision_ideas_20260930$
declare
 v_rows integer;
 v_expected_lessons constant jsonb := '{"est2|Angles and polygons":4,"est2|Functions and transformations":8,"est2|Inequalities and absolute value":5,"est2|Linear functions and slope":5,"est2|Quadratics and polynomials":7,"est2|Systems of equations":1,"est2|Triangles and similarity":7,"est2|Trigonometry":3,"sat|Algebraic expressions and equations":4,"sat|Complex numbers":1,"sat|Desmos calculator guidance":1,"sat|Exponents, radicals and growth":1,"sat|Functions and transformations":5,"sat|Inequalities and absolute value":3,"sat|Linear functions and slope":5,"sat|Logarithms and exponentials":1,"sat|Quadratics and polynomials":7,"sat|Ratios, percentages and unit conversion":2,"sat|Statistics and data analysis":1,"sat|Systems of equations":6,"sat|Triangles and similarity":2,"sat|Trigonometry":1}'::jsonb;
begin
 if exists(select 1 from public.audit_log where action='revision.est2_sat_idea_expansion.20260930') then
  raise exception 'Second SAT and EST II revision idea expansion already applied; do not rerun';
 end if;
 if (select count(*) from public.revision_items)<>2347
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1301
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>456
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>288
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>300
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>328 then
  raise exception 'Revision catalogue changed; re-review before the second SAT and EST II expansion';
 end if;
 if (select count(*) from est2_sat_revision_idea_release_20260930)<>80
    or (select count(*) from est2_sat_revision_idea_release_20260930 where track='sat')<>40
    or (select count(*) from est2_sat_revision_idea_release_20260930 where track='est2')<>40
    or (select count(distinct id) from est2_sat_revision_idea_release_20260930)<>80
    or (select count(distinct (track,lesson,idea)) from est2_sat_revision_idea_release_20260930)<>80 then
  raise exception 'Second SAT and EST II revision release manifest is incomplete or duplicated';
 end if;
 if (select jsonb_object_agg(track||'|'||lesson,n) from (
       select track,lesson,count(*) n from est2_sat_revision_idea_release_20260930 group by track,lesson order by track,lesson
     ) x)<>v_expected_lessons then
  raise exception 'Second SAT and EST II revision release lesson distribution changed';
 end if;
 if exists(
  select 1 from est2_sat_revision_idea_release_20260930 x
  left join public.questions q on q.id=x.id
  left join public.question_keys k on k.question_id=q.id
  where q.id is null or q.track_id<>x.track or q.topic<>x.lesson
   or x.track not in ('sat','est2')
   or nullif(q.assets->>'verified_release','') is null
   or nullif(q.assets->>'release_hold_reason','') is not null
   or jsonb_typeof(k.correct) not in ('string','array')
   or length(btrim(k.explanation))=0
   or k.explanation ~* '^Source-keyed answer'
   or (q.type='mcq' and (
       jsonb_typeof(k.correct)<>'string'
       or jsonb_array_length(q.choices)<2
       or not exists(select 1 from jsonb_array_elements(q.choices) c where c->>'key'=k.correct#>>'{}')
      ))
   or public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)<>x.fingerprint
 ) then raise exception 'Selected SAT or EST II source changed or is no longer eligible'; end if;
 if exists(select 1 from est2_sat_revision_idea_release_20260930 x join public.revision_items r on r.question_id=x.id) then
  raise exception 'Selected SAT or EST II question is already in Final Revision';
 end if;
 if exists(
  select 1 from est2_sat_revision_idea_release_20260930 x
  join public.revision_items r on r.lesson=x.lesson and lower(trim(r.idea))=lower(trim(x.idea))
  join public.questions q on q.id=r.question_id and q.track_id=x.track
 ) then raise exception 'Selected SAT or EST II idea already exists in its track and lesson'; end if;
 if exists(
  select 1 from est2_sat_revision_idea_release_20260930 x
  join public.questions q on q.id=x.id
  join public.questions q2 on md5(lower(regexp_replace(q2.stem,'\s+',' ','g'))||q2.choices::text)
    =md5(lower(regexp_replace(q.stem,'\s+',' ','g'))||q.choices::text)
  join public.revision_items r on r.question_id=q2.id
 ) then raise exception 'Selected SAT or EST II content duplicates an existing revision item'; end if;

 insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
 select x.id,x.lesson,x.idea,q.difficulty,array[x.track]::text[],x.fingerprint,true,
  jsonb_build_object(
   'collections',jsonb_build_array('unique'),
   'bank_occurrences',1,
   'takeaway','Key skill: '||x.idea||'.',
   'math_format',case when q.stem like '%\(%' or q.stem like '%\[%' or q.stem like '%$%' then 'latex' else 'plain' end,
   'release','20260930-est2-sat-idea-expansion'
  )
 from est2_sat_revision_idea_release_20260930 x join public.questions q on q.id=x.id;
 get diagnostics v_rows=row_count;
 if v_rows<>80 then raise exception 'Second SAT and EST II revision insertion count is incorrect'; end if;

 insert into public.audit_log(action,target_type,target_id,meta)
 select 'revision.est2_sat_idea_expansion.item.20260930','question',x.id::text,
  jsonb_build_object('track',x.track,'lesson',x.lesson,'idea',x.idea,'fingerprint',x.fingerprint)
 from est2_sat_revision_idea_release_20260930 x;
 get diagnostics v_rows=row_count;
 if v_rows<>80 then raise exception 'Second SAT and EST II revision item audit is incomplete'; end if;

 if (select count(*) from public.revision_items)<>2427
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1341
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>496
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>328
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>300
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>368
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
        where q.track_id='sat' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>1341
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
        where q.track_id='est' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>578
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
        where q.track_id='est2' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>495
    or exists(select 1 from est2_sat_revision_idea_release_20260930 x join public.revision_items r on r.question_id=x.id
              where not r.active or r.programmes<>array[x.track]::text[])
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590 then
  raise exception 'Post-release second SAT and EST II revision verification failed';
 end if;

 insert into public.audit_log(action,target_type,target_id,meta)
 values ('revision.est2_sat_idea_expansion.20260930','release','20260930',
  jsonb_build_object(
   'tracks',jsonb_build_object('sat',40,'est2',40),
   'added_questions',80,'added_ideas',80,
   'catalogue_questions',jsonb_build_object('sat',1341,'est',590,'est2',496),
   'catalogue_ideas',jsonb_build_object('sat',328,'est',300,'est2',368),
   'lessons',v_expected_lessons,
   'classification_only',true,'new_answer_certification',false));
end $est2_sat_revision_ideas_20260930$;

commit;

select q.track_id,count(*) total,
 count(*) filter(where r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)) ready,
 count(distinct (r.lesson,r.idea)) ideas
from public.revision_items r
join public.questions q on q.id=r.question_id
join public.question_keys k on k.question_id=q.id
group by q.track_id order by q.track_id;


