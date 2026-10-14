begin;
lock table public.questions, public.question_keys, public.revision_items, public.audit_log in share row exclusive mode;

create temporary table est2_sat_revision_idea_release on commit drop as
select * from jsonb_to_recordset('[{"id":"e8e6cee5-a546-45a8-88a4-9c72ff9645e0","track":"sat","lesson":"Algebraic expressions and equations","idea":"Integer solutions from factor pairs","fingerprint":"9143b6a0731b3e937240614ea8d1d7a2"},{"id":"e9a84255-4386-41a2-ad46-4089fda8296a","track":"sat","lesson":"Algebraic expressions and equations","idea":"Equivalent quadratic forms reveal x-intercepts","fingerprint":"39b73682c41ce831e1098166074133a8"},{"id":"2ea6b139-b961-4e8e-95c0-0d6549bf700b","track":"sat","lesson":"Circles","idea":"Vertical-line intersections with a circle","fingerprint":"3c34799618e74e741632b0c882a6673c"},{"id":"383f3fe1-ce09-4240-88b7-ee3f37c283a6","track":"sat","lesson":"Circles","idea":"Radius geometry with a cofunction","fingerprint":"804f34d11961aeca9f7684dc35d9d10a"},{"id":"51abc8a6-b2fd-41fe-9c39-6fd6d63dfb10","track":"sat","lesson":"Exponents, radicals and growth","idea":"Domain of a radical inequality","fingerprint":"8c9f38d950b38bb1bc93da6e55cfe488"},{"id":"ce4246af-7d42-494b-9246-6e12a16815a9","track":"sat","lesson":"Exponents, radicals and growth","idea":"Comparing linear and exponential projections","fingerprint":"2da9d735e2cfd458043a461028e00b96"},{"id":"afe5843b-14f9-4ad2-93d5-cf326e938c01","track":"sat","lesson":"Functions and transformations","idea":"Inferring a function-shift parameter","fingerprint":"06e3b37bdf34c2563d593d2540450ff6"},{"id":"b38c9d84-6c97-4184-b4aa-10e6b218fb9d","track":"sat","lesson":"Functions and transformations","idea":"Even-function values at opposite inputs","fingerprint":"5e554f500e67facd6c9a0c4611251054"},{"id":"56b1eb3e-6529-4165-afc5-ae7cf5c7376a","track":"sat","lesson":"Functions and transformations","idea":"Interpreting a model''s positive x-intercept","fingerprint":"658da33658f4d4658edc397d91b400b5"},{"id":"958b0dd7-4208-49e8-a675-76174e5fe914","track":"sat","lesson":"Functions and transformations","idea":"Undefined rational expressions after simplification","fingerprint":"330ae998547adeecbd62ed1c8c64d49f"},{"id":"1ca27ab6-926b-425d-ab15-f05eb2c20f20","track":"sat","lesson":"Functions and transformations","idea":"Restricting inputs from an output interval","fingerprint":"ec1ed12a9da287065f1cc4426870ef03"},{"id":"12039edd-0ed2-4caf-847b-1f8b79633f6d","track":"sat","lesson":"Functions and transformations","idea":"Matching a function to a prescribed range","fingerprint":"f2d17cd270d3185a163adf7f06272add"},{"id":"63b6d44d-d8e3-4faa-80dc-a00a6d16c899","track":"sat","lesson":"Functions and transformations","idea":"Modeling repeated weekly activity","fingerprint":"cc615ce9a92d2f83ac7e695a1cfe2dc9"},{"id":"499f1412-68b4-4de8-82f0-7618fab62f0d","track":"sat","lesson":"Inequalities and absolute value","idea":"Selecting the positive absolute-value solution","fingerprint":"507bbb1dd2b4fadff5b085d35f7b5cad"},{"id":"e1a145e0-19c8-4a10-ab87-1c8272a9e5d9","track":"sat","lesson":"Inequalities and absolute value","idea":"Comparing compensation plans with an inequality","fingerprint":"1a6b8059ee4db9620022abda9d127db0"},{"id":"68f4e06f-7ee7-4bed-ab3f-8c357da33aec","track":"sat","lesson":"Inequalities and absolute value","idea":"Solving a quadratic inequality","fingerprint":"5c2122ba7b2547d626f99c821c75bb58"},{"id":"e26d4251-7424-449c-a392-7fd163fa23e9","track":"sat","lesson":"Inequalities and absolute value","idea":"Locating integer roots from sign changes","fingerprint":"b5c4530ddd19953f4745b56a00459211"},{"id":"f570d8cf-b268-4e55-9de5-be285903cc23","track":"sat","lesson":"Linear functions and slope","idea":"Interpreting a coefficient in a cost model","fingerprint":"9b3d337ba22d7dac109328f3ac0a6fd7"},{"id":"2d3e2f48-545b-484e-8e37-052e6fdd281b","track":"sat","lesson":"Linear functions and slope","idea":"Interpreting a linear model''s x-intercept","fingerprint":"77923daf9f2033a810972c0f8a06bcde"},{"id":"9a3e9c26-f0f6-463a-a521-e7eec77e3dfb","track":"sat","lesson":"Linear functions and slope","idea":"Interpreting a negative unit-conversion rate","fingerprint":"369398a786cfb6f8ad545e0f36f2f493"},{"id":"579d6261-3865-4398-80a7-2608ba35b71a","track":"sat","lesson":"Linear functions and slope","idea":"Building a linear depreciation model","fingerprint":"11c48d0010ed7efb622249a9dc947905"},{"id":"fe98ecc5-40c9-4f63-9001-e1da89337e16","track":"sat","lesson":"Linear functions and slope","idea":"Writing a line from a point and slope","fingerprint":"b0aaa52879d5267732a2ccc52abde430"},{"id":"c1552f24-30a7-469a-ab60-f03d3058d106","track":"sat","lesson":"Polynomial division and remainder","idea":"Matching a polynomial division identity","fingerprint":"733849634d24d5fb9d43f89a7f6ca219"},{"id":"8d667823-7663-f140-519d-69cc6fdc7748","track":"sat","lesson":"Probability and conditional probability","idea":"Conditional sample space from a table","fingerprint":"92732e7b8178092a240ce9fe20b70389"},{"id":"68907f5e-81ff-4d5a-95a5-18af21b8ad1e","track":"sat","lesson":"Quadratics and polynomials","idea":"Concavity from the leading coefficient","fingerprint":"2dc1ba0cf47e814e794f964ad192ef47"},{"id":"e0ad7c44-18d6-4695-99d7-696fad89744e","track":"sat","lesson":"Quadratics and polynomials","idea":"Difference between quadratic roots","fingerprint":"61228d3f5529dc350311625eae660190"},{"id":"c8e9e760-1205-4f83-af6a-cfa6ed70c13d","track":"sat","lesson":"Quadratics and polynomials","idea":"Reducing a higher-degree equation by factoring","fingerprint":"3081a0a907ebb3bca06c69ac22ef3fea"},{"id":"11673e50-3288-4f02-b709-59ad81a602c4","track":"sat","lesson":"Quadratics and polynomials","idea":"Coefficient matching in a polynomial identity","fingerprint":"c111afd0bbcf9327147ac4dd56999857"},{"id":"34db0bed-9d02-408b-afd0-4e362cd2f7a6","track":"sat","lesson":"Quadratics and polynomials","idea":"Time of flight from a quadratic model","fingerprint":"61c316aa79e2e7ad4a24b73c800ac942"},{"id":"b9b7e5e0-ad04-4093-aaa5-354def348d5b","track":"sat","lesson":"Quadratics and polynomials","idea":"Range of a downward-opening quadratic","fingerprint":"c1ec80a62ee3b0e9cc3abfb1f24819af"},{"id":"df6b2668-1700-4464-b5f0-882fcffd1f38","track":"sat","lesson":"Quadratics and polynomials","idea":"Equal-height points on a symmetric parabola","fingerprint":"650c63ad8b607464692f5f41d60be5eb"},{"id":"ac2da2e1-99a4-4a18-910f-2cf7e1de86e6","track":"sat","lesson":"Quadratics and polynomials","idea":"Tangency condition for a parabola","fingerprint":"750d678a31d9abf95e999398c9a4c3fb"},{"id":"0ee9d7b8-1d68-4f86-93cd-998c6997632b","track":"sat","lesson":"Ratios, percentages and unit conversion","idea":"Reversing successive percentage decreases","fingerprint":"353a09517274c96063189529340eb9e6"},{"id":"181016cd-5c63-498a-bebc-f68578349ba7","track":"sat","lesson":"Ratios, percentages and unit conversion","idea":"Recovering a component of a cost mixture","fingerprint":"4edd9ea7d0f33de34e844b22e680530a"},{"id":"9b2143d0-cbf7-4765-9465-5d75ec5446f2","track":"sat","lesson":"Ratios, percentages and unit conversion","idea":"Weighted-average interest allocation","fingerprint":"b0d5d854240624698920ec4f88c27d03"},{"id":"a931ad24-dd98-434a-b34a-51f9419253a3","track":"sat","lesson":"Ratios, percentages and unit conversion","idea":"Compound rate and unit conversion","fingerprint":"d9ff1001a10d49648240bd0ee51caa2a"},{"id":"2bb56c82-c2f3-4a21-87e3-ca687c00aaf7","track":"sat","lesson":"Statistics and data analysis","idea":"Recovering a missing value from the mean","fingerprint":"f29601ede61b6d6839111d686cd43060"},{"id":"f780c894-8db8-4fd0-acaa-30254f2cb8e4","track":"sat","lesson":"Systems of equations","idea":"Solving a linear-quadratic system","fingerprint":"96dcc7c5a1fe3135a89e8aea4a788bc5"},{"id":"23edf940-b3d6-4a39-9c6f-cd033482edc7","track":"sat","lesson":"Systems of equations","idea":"Capacity under paired resource constraints","fingerprint":"ee9da1975c0ac77f00f0782390f45331"},{"id":"367e0ba3-bac4-48ca-a038-c202281d1795","track":"sat","lesson":"Trigonometry","idea":"Unit-circle coordinates from a reference angle","fingerprint":"f2054937090f1a5715c1f7a8f3f44048"},{"id":"6ac3fdb6-0f06-5c8f-90ee-9c3e43f1cb6b","track":"est2","lesson":"Algebraic expressions and equations","idea":"Allocating prime factors among odd integers","fingerprint":"a584cba34b95a9068bdace9c94ab3228"},{"id":"82a4cfa7-2608-5406-972c-2235da920ea9","track":"est2","lesson":"Algebraic expressions and equations","idea":"Quotient-and-remainder arithmetic","fingerprint":"17f67a1e140a740067ada22f2d53c04b"},{"id":"8bd77556-4760-58d9-b07b-93aeba048af6","track":"est2","lesson":"Algebraic expressions and equations","idea":"Divisibility involving a factorial","fingerprint":"43d2699287d41ce8c163d8753ba91f41"},{"id":"16b7d466-d0d4-5eec-8be9-ada72ccd11a0","track":"est2","lesson":"Area and perimeter","idea":"Recovering a parallelogram side from perimeter","fingerprint":"a40deb8c36f01123cc2bc13a9b843f09"},{"id":"1c0d9d6c-c7d5-51c0-a3c3-21665ffb46fb","track":"est2","lesson":"Area and perimeter","idea":"Scaling an area rate over time","fingerprint":"c0bd8496050c3ed47ccb42ab4653d122"},{"id":"1bd08d20-7c50-5a04-8989-c8ddc71fdeb3","track":"est2","lesson":"Area and perimeter","idea":"Counterexample comparing square area and perimeter","fingerprint":"61dd588f65f022c902aceba6ca1f3351"},{"id":"38533b6f-8f10-5b29-bbec-f6023248aba6","track":"est2","lesson":"Area and perimeter","idea":"Isosceles-trapezoid perimeter from area","fingerprint":"5ec3d4db62d9d6495a96ce22344e51f7"},{"id":"3cca3f1d-6043-5635-9df2-c775befe1a55","track":"est2","lesson":"Area and perimeter","idea":"Right-trapezoid area with a 45-degree leg","fingerprint":"58a49dca089aa7b0d2b88fc4e1bd04d3"},{"id":"9c06eb33-0735-5ba9-8db8-0dc0fa051d37","track":"est2","lesson":"Area and perimeter","idea":"Square area from its diagonal","fingerprint":"323fdb144f6e7cfc449d1dca59080b33"},{"id":"c3d1f83e-6db2-5e10-aac6-75c1fa60ebc1","track":"est2","lesson":"Area and perimeter","idea":"Unshaded area between nested squares","fingerprint":"bc9e2d9d68c16d6fefea435525b597f9"},{"id":"3a70c319-9fc1-5155-9c21-286cc2dca857","track":"est2","lesson":"Logic and sets","idea":"Contrapositive after chained implications","fingerprint":"086aaf618739cd4b37e3a8ebe22e96f8"},{"id":"afa2bba1-4661-5728-b450-0236657327e9","track":"est2","lesson":"Logic and sets","idea":"Transitive chaining of conditional statements","fingerprint":"535b06f526b3436cf9e7e874c807e8fb"},{"id":"113267c2-1409-59e3-80eb-f9e2eb0291ce","track":"est2","lesson":"Sequences","idea":"Counting terms strictly between sequence values","fingerprint":"f4f48d1a6952fd78bb553304b35faeb9"},{"id":"78d13ad4-bb9d-5fb6-8849-aa7031eaec44","track":"est2","lesson":"Logarithms and exponentials","idea":"Inverse relationship between logarithms and exponentials","fingerprint":"c5d1e803a98d4f445b92319a50433688"},{"id":"dc963911-a748-5368-a85d-40227434e37c","track":"est2","lesson":"Vectors","idea":"Solving for components of a unit vector","fingerprint":"7d50065698b2f38d0e406573a7a1227c"},{"id":"fc01b0d9-f150-5bd5-ab52-4eb412b8d343","track":"est2","lesson":"Exponents, radicals and growth","idea":"Combining radicals with different indices","fingerprint":"09ba017035468fdf9366beaeeaf3fd5c"},{"id":"c46f2294-ba80-5847-9f99-f82db1572b10","track":"est2","lesson":"Exponents, radicals and growth","idea":"Transforming and reflecting a radical graph","fingerprint":"3ed06bca7b6f190a5c6fbc0da6d5a4f7"},{"id":"a64c4aa9-b66a-5f7e-a866-65909450df34","track":"est2","lesson":"Probability and conditional probability","idea":"Complement probability over independent trials","fingerprint":"1e5e40e16858126bd61e01f612d22eec"},{"id":"664e3a55-dcae-5dff-af2d-7c9ae7562787","track":"est2","lesson":"Statistics and data analysis","idea":"Quadratic regression extrapolation","fingerprint":"bedf9cfa264f22d71acdc7a0479925c0"},{"id":"6d879c43-fa32-59d5-8fd3-bf7d2620c678","track":"est2","lesson":"Statistics and data analysis","idea":"Scaling a sample standard deviation","fingerprint":"6ed4a6904127bd663deb7e53dfa5589f"},{"id":"34640b54-ae91-5745-9805-be2026c73f90","track":"est2","lesson":"Circles","idea":"Circular-segment area from a right-angle sector","fingerprint":"9447b59300ad7ebc6dca1a394bd561b0"},{"id":"68d07a14-d21b-5c02-bfec-1e66f417053a","track":"est2","lesson":"Circles","idea":"External secant lengths by power of a point","fingerprint":"7c8c172666efdc619ae58868a74aeecb"},{"id":"df01d725-7d8c-5795-af82-fe10c1c54f20","track":"est2","lesson":"Circles","idea":"Exterior secant angle from intercepted arcs","fingerprint":"fd584d7b52b43741c81af208f8ad14c9"},{"id":"a4b60be6-68a5-518d-a60c-c7b82d789801","track":"est2","lesson":"Circles","idea":"Sector-area ratio from a radian angle","fingerprint":"46e49d2cf80cf1746727750521c20d21"},{"id":"a663a028-065c-501a-b0d8-6ec959b2d84f","track":"est2","lesson":"Circles","idea":"Triangle of centers for tangent circles","fingerprint":"e03c1f8f45b5a6a5fb850ef576d8831e"},{"id":"becabf70-f6d5-56fb-9890-82c90f168cc1","track":"est2","lesson":"Circles","idea":"Square and equilateral triangle in one circumcircle","fingerprint":"3c9cdcd9520e0765412e86b416860292"},{"id":"c1a90781-6cf0-5c1d-a44b-d79e2300992f","track":"est2","lesson":"Circles","idea":"Equilateral-triangle area from its inradius","fingerprint":"4512c9af2daebf5258bb48ab83a74484"},{"id":"08885f56-8e44-5796-9aab-df62ac5d66e9","track":"est2","lesson":"Circles","idea":"Similar triangles formed by two secants","fingerprint":"5bd592aff13689546e63fcd46251658b"},{"id":"23c5e99c-5c8b-5073-ad27-2e4fe4e4b347","track":"est2","lesson":"Circles","idea":"Radius from a chord and its center distance","fingerprint":"de45cdb3343aab5d0a202d206c5004a6"},{"id":"22aaea36-59dc-5f29-8fd9-4bf23a108483","track":"est2","lesson":"Circles","idea":"Combined area of tangent circles packed in a rectangle","fingerprint":"001bec1945bd873aed25027e5cd7e1e0"},{"id":"2aa7fe50-884f-56a0-9110-2fea5d11f80e","track":"est2","lesson":"Circles","idea":"Radius from cylindrical-can packing","fingerprint":"0e2166cd2d00bd924859ccba3ea5f255"},{"id":"69aceaac-4811-5fdf-9dbb-0cbf0cb09cf5","track":"est2","lesson":"Circles","idea":"Exterior perimeter with an attached semicircle","fingerprint":"7162752765cc2054dd49e4e5efd4b51c"},{"id":"5e9f3e1f-daab-5b3d-abec-c687d2e8bc8f","track":"est2","lesson":"Circles","idea":"Inscribed angle from a central angle","fingerprint":"926a5c41d0b89dbf9d0298193633bd3b"},{"id":"6623cea2-0ac9-50c5-a6e3-383b9dffbee0","track":"est2","lesson":"Systems of equations","idea":"Eliminating variables in a three-variable system","fingerprint":"0b2751f4f31cad5ad535fae7ba245df1"},{"id":"1a899114-e340-564d-914b-7a1a0a23e22e","track":"est2","lesson":"Volume and surface area","idea":"Oblique cross-section of a right cone","fingerprint":"47f7b786f4ecfc6f4f4d40435b99f025"},{"id":"216bd3e6-d766-56a9-bef1-c2463656ede1","track":"est2","lesson":"Volume and surface area","idea":"Volume of a pool with linearly varying depth","fingerprint":"44dd4743e0ac4000aa896a36f8a829c0"},{"id":"95c6064e-5cfd-5100-af46-4ac90789baf0","track":"est2","lesson":"Volume and surface area","idea":"Surface-area scaling when all dimensions double","fingerprint":"fa455f71f3288a5b3f681e6493b6652a"},{"id":"8d3f20e4-615c-50be-b54c-dcca5080a2cb","track":"est2","lesson":"Volume and surface area","idea":"Perpendicular cross-section of a right prism","fingerprint":"90ac7917b8b07ab105bff937b9f9b9ae"},{"id":"43a5129b-ccdb-5252-bddf-efd3bba8f00c","track":"est2","lesson":"Volume and surface area","idea":"Cone lateral area compared with a hemisphere","fingerprint":"00bb128aa57b1dde082d14dc4216b62e"},{"id":"092fc4c3-860f-54f9-8b0d-6164041e1273","track":"est2","lesson":"Volume and surface area","idea":"Cone lateral area from radius and slant height","fingerprint":"d1c87edb5776e60d51695575353698e1"}]'::jsonb)
 as r(id uuid,track text,lesson text,idea text,fingerprint text);

do $est2_sat_revision_ideas$
declare
 v_rows integer;
 v_expected_lessons constant jsonb := '{"est2|Algebraic expressions and equations":3,"est2|Area and perimeter":7,"est2|Circles":13,"est2|Exponents, radicals and growth":2,"est2|Logarithms and exponentials":1,"est2|Logic and sets":2,"est2|Probability and conditional probability":1,"est2|Sequences":1,"est2|Statistics and data analysis":2,"est2|Systems of equations":1,"est2|Vectors":1,"est2|Volume and surface area":6,"sat|Algebraic expressions and equations":2,"sat|Circles":2,"sat|Exponents, radicals and growth":2,"sat|Functions and transformations":7,"sat|Inequalities and absolute value":4,"sat|Linear functions and slope":5,"sat|Polynomial division and remainder":1,"sat|Probability and conditional probability":1,"sat|Quadratics and polynomials":8,"sat|Ratios, percentages and unit conversion":4,"sat|Statistics and data analysis":1,"sat|Systems of equations":2,"sat|Trigonometry":1}'::jsonb;
begin
 if exists(select 1 from public.audit_log where action='revision.est2_sat_idea_expansion.20260929') then
  raise exception 'SAT and EST II revision idea expansion already applied; do not rerun';
 end if;
 if (select count(*) from public.revision_items)<>2267
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1261
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>416
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>248
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>300
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>288 then
  raise exception 'Revision catalogue changed; re-review before expanding SAT and EST II';
 end if;
 if (select count(*) from est2_sat_revision_idea_release)<>80
    or (select count(*) from est2_sat_revision_idea_release where track='sat')<>40
    or (select count(*) from est2_sat_revision_idea_release where track='est2')<>40
    or (select count(distinct id) from est2_sat_revision_idea_release)<>80
    or (select count(distinct (track,lesson,idea)) from est2_sat_revision_idea_release)<>80 then
  raise exception 'SAT and EST II revision release manifest is incomplete or duplicated';
 end if;
 if (select jsonb_object_agg(track||'|'||lesson,n) from (
       select track,lesson,count(*) n from est2_sat_revision_idea_release group by track,lesson order by track,lesson
     ) x)<>v_expected_lessons then
  raise exception 'SAT and EST II revision release lesson distribution changed';
 end if;
 if exists(
  select 1 from est2_sat_revision_idea_release x
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
 if exists(select 1 from est2_sat_revision_idea_release x join public.revision_items r on r.question_id=x.id) then
  raise exception 'Selected SAT or EST II question is already in Final Revision';
 end if;
 if exists(
  select 1 from est2_sat_revision_idea_release x
  join public.revision_items r on r.lesson=x.lesson and lower(trim(r.idea))=lower(trim(x.idea))
  join public.questions q on q.id=r.question_id and q.track_id=x.track
 ) then raise exception 'Selected SAT or EST II idea already exists in its track and lesson'; end if;
 if exists(
  select 1 from est2_sat_revision_idea_release x
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
   'release','20260929-est2-sat-idea-expansion'
  )
 from est2_sat_revision_idea_release x join public.questions q on q.id=x.id;
 get diagnostics v_rows=row_count;
 if v_rows<>80 then raise exception 'SAT and EST II revision insertion count is incorrect'; end if;

 insert into public.audit_log(action,target_type,target_id,meta)
 select 'revision.est2_sat_idea_expansion.item.20260929','question',x.id::text,
  jsonb_build_object('track',x.track,'lesson',x.lesson,'idea',x.idea,'fingerprint',x.fingerprint)
 from est2_sat_revision_idea_release x;
 get diagnostics v_rows=row_count;
 if v_rows<>80 then raise exception 'SAT and EST II revision item audit is incomplete'; end if;

 if (select count(*) from public.revision_items)<>2347
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1301
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>456
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>288
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>300
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>328
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
        where q.track_id='sat' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>1301
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
        where q.track_id='est' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>578
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
        where q.track_id='est2' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>455
    or exists(select 1 from est2_sat_revision_idea_release x join public.revision_items r on r.question_id=x.id
              where not r.active or r.programmes<>array[x.track]::text[])
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590 then
  raise exception 'Post-release SAT and EST II revision verification failed';
 end if;

 insert into public.audit_log(action,target_type,target_id,meta)
 values ('revision.est2_sat_idea_expansion.20260929','release','20260929',
  jsonb_build_object(
   'tracks',jsonb_build_object('sat',40,'est2',40),
   'added_questions',80,'added_ideas',80,
   'catalogue_questions',jsonb_build_object('sat',1301,'est',590,'est2',456),
   'catalogue_ideas',jsonb_build_object('sat',288,'est',300,'est2',328),
   'lessons',v_expected_lessons,
   'classification_only',true,'new_answer_certification',false));
end $est2_sat_revision_ideas$;

commit;

select q.track_id,count(*) total,
 count(*) filter(where r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)) ready,
 count(distinct (r.lesson,r.idea)) ideas
from public.revision_items r
join public.questions q on q.id=r.question_id
join public.question_keys k on k.question_id=q.id
group by q.track_id order by q.track_id;
