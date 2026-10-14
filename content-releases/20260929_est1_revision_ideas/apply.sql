begin;
lock table public.questions, public.question_keys, public.revision_items, public.audit_log in share row exclusive mode;

create temporary table est1_revision_idea_release on commit drop as
select * from jsonb_to_recordset('[{"id":"03cf85e7-9fba-0ddc-8b65-a0ed137ced3a","idea":"Angles defined by complements","lesson":"Angles and polygons","fingerprint":"c403713511be7ef1488a798ff9673f55"},{"id":"22854a9a-2d80-599b-b1b1-2d390e3d2e48","idea":"Conditions that guarantee a rectangle","lesson":"Angles and polygons","fingerprint":"b0b564ec4223c717f4f0b9cf21e451ac"},{"id":"2e77ea5f-a6ec-528c-9499-16dceb6e158f","idea":"Proving alternate interior angles congruent","lesson":"Angles and polygons","fingerprint":"869ec38010b5ae2c6c2e60bea6cd7b16"},{"id":"31f05973-3a54-5ff7-ac9b-666fca1ab747","idea":"Classifying quadrilaterals from coordinates","lesson":"Angles and polygons","fingerprint":"5c7276e6a15436759d70c60348455b67"},{"id":"388972da-4a3a-5f24-ae84-60d910ad613a","idea":"Parallelogram angles split by a diagonal","lesson":"Angles and polygons","fingerprint":"dcd1f7b05cfcfcd5e2d3f58887b096fc"},{"id":"3d310f7f-5e0d-ab67-1e88-9da99a899141","idea":"Same-side interior angle equations","lesson":"Angles and polygons","fingerprint":"b82181a81540bd64d34ec89d58044b2f"},{"id":"4adc17c6-37cb-5d1c-81e5-ce9b66de11d1","idea":"Trapezoid angle chasing","lesson":"Angles and polygons","fingerprint":"5dbc19a0c7ffe84ed3c0f4c2b6406fc3"},{"id":"5bbcddfb-87bd-5fd3-a344-5099266a8b8a","idea":"Diagonals of a regular pentagon","lesson":"Angles and polygons","fingerprint":"6024c05ebb01ecbff8a8ca39a57ae663"},{"id":"7338f9aa-e762-4077-aefa-1f2821de1b1f","idea":"Interior and exterior angles of a hexagon","lesson":"Angles and polygons","fingerprint":"b0a770c1d9e593b2d62bc16b0ea06508"},{"id":"d5bd2849-fc8b-56bb-8bf0-dfd571ea433c","idea":"Exterior-angle patterns in regular polygons","lesson":"Angles and polygons","fingerprint":"6767b5058fffe0e157760fca8a9d0e87"},{"id":"e4000309-25d3-57e6-9b79-1e7c56a93e65","idea":"Number of sides from an exterior angle","lesson":"Angles and polygons","fingerprint":"ac2aa6b6e4264053cbbc9b128b55a440"},{"id":"031394c4-cdf6-585c-869e-bfa9ff66bfce","idea":"Rectangle diagonal from area and perimeter","lesson":"Area and perimeter","fingerprint":"09b219e688b15067a4cb4a53411dd805"},{"id":"088a3922-48b5-593d-bf64-83b7ec0c9dad","idea":"Physical domain of a rectangle area model","lesson":"Area and perimeter","fingerprint":"dec735447dd2cbded170395ad1726e80"},{"id":"0a152c79-d964-505d-92a5-95edcc6b23f2","idea":"Tiled square area from rectangle perimeter","lesson":"Area and perimeter","fingerprint":"093a85b9e089ad3db391b93a9da3425f"},{"id":"120df286-53e8-5183-a50c-62c7fed7c5d3","idea":"Area under a scale factor","lesson":"Area and perimeter","fingerprint":"507467e3da41dedaedfe2a2b331dba79"},{"id":"13968e75-5f97-5f6f-8f1f-17c3d35e2273","idea":"Trapezoid area from coordinates","lesson":"Area and perimeter","fingerprint":"28f63e91cfe0e03f57745258525dfd2e"},{"id":"1a298c49-8244-508a-b696-d4445b1257a9","idea":"Fractional area across unequal partitions","lesson":"Area and perimeter","fingerprint":"86162e60a9252fffcf7b6a2060362fe6"},{"id":"2f40acd4-2cb4-549d-a922-508676981a40","idea":"Area of a regular hexagon","lesson":"Area and perimeter","fingerprint":"793e7d75771be796fd1e0afbfaf3cdd3"},{"id":"5a33ec05-0da0-547e-b394-7fc561ed85d4","idea":"Wall area after subtracting openings","lesson":"Area and perimeter","fingerprint":"795a7570f432521cd8eac5d629ebfe7f"},{"id":"64fc2333-f687-5500-a2e7-a4684dbcd583","idea":"L-shaped area by subtraction","lesson":"Area and perimeter","fingerprint":"4d32a6df548c733221babbbd6411d796"},{"id":"75029b8f-34b5-586e-b584-d076e219ba3d","idea":"Side-length factor for an area multiplier","lesson":"Area and perimeter","fingerprint":"ff67bbc0932da77b874ba8ea254a1c8f"},{"id":"0ab0cf8f-5fa0-5a6d-826c-d83ea3074f48","idea":"Equivalent forms of a conditional","lesson":"Logic and sets","fingerprint":"2894672ba5624fc0112ec953bdc9f2d9"},{"id":"a3890b66-fbb8-5dda-a86a-81be0c4c943f","idea":"Reading implications from a Venn diagram","lesson":"Logic and sets","fingerprint":"6773fc585ec96103dbfb7f28c88e9578"},{"id":"a4c68116-825f-4a37-9f49-1c20eaa92e6e","idea":"Set union, intersection and absorption","lesson":"Logic and sets","fingerprint":"75f192e033d2aa85657b44e7ec21ce07"},{"id":"bf3b309d-98d4-592c-bee1-3163c433c847","idea":"Chained conditionals and contraposition","lesson":"Logic and sets","fingerprint":"ca545a04e5a909b4a894541c42d279be"},{"id":"c923de85-c787-50b1-96b5-6106f8157742","idea":"Disproving a conditional by counterexample","lesson":"Logic and sets","fingerprint":"a863b8b13d3893ec35524f7ef199e7c0"},{"id":"b2142954-ef46-5d14-8b3a-517362f13e61","idea":"Solving an equation with a matrix determinant","lesson":"Matrices","fingerprint":"2087ac073326ee093878ff5fff4a7d6f"},{"id":"e1b24ddd-867f-57ee-b940-97e84d95c5a3","idea":"Scalar multiplication of a matrix","lesson":"Matrices","fingerprint":"55a66aa0027e056c1be7d39b59692f51"},{"id":"052a9e37-debf-9031-2d92-2102062f6899","idea":"Natural logarithm and exponential inverses","lesson":"Logarithms and exponentials","fingerprint":"bb2a15915badb79d3290fc208f63f87f"},{"id":"10fab705-da9f-6719-ec0d-3297d5afae40","idea":"Factoring exponential expressions","lesson":"Logarithms and exponentials","fingerprint":"80e92edbe372e92f3086f2539ed14ecb"},{"id":"7596a2b5-adc1-2b5a-e99b-7160610d3e3c","idea":"Comparing linear and exponential growth","lesson":"Logarithms and exponentials","fingerprint":"6597344c6972f9d724d35d9116080c82"},{"id":"3beae24d-3b6a-5b95-95c8-6f73ec49ce14","idea":"Changing logarithm bases in an exponent equation","lesson":"Logarithms and exponentials","fingerprint":"d2b98a83443bce604fecf1f16a1b9203"},{"id":"9642bb59-35fa-682a-7aed-02e79eaaeb13","idea":"Solving a mixed logarithmic-exponential equation","lesson":"Logarithms and exponentials","fingerprint":"550f819c82e45b3b7c84ee2c14758a81"},{"id":"519075c9-55b0-502d-9335-0e0e0312c25e","idea":"Division by a reversed linear factor","lesson":"Polynomial division and remainder","fingerprint":"fb65d2fe2dd1764015584c527535a838"},{"id":"6e358bf7-67f0-564a-b30d-dd74c27e9700","idea":"Dividing a cubic by a linear factor","lesson":"Polynomial division and remainder","fingerprint":"32d61f825416576ca1fe8050c1e181da"},{"id":"18047da0-7ece-552d-af59-2772796dfb02","idea":"Quotient-remainder decomposition","lesson":"Polynomial division and remainder","fingerprint":"e60882a6cee537d3f66bd0e1ee4fef9c"},{"id":"82d09e05-241a-5e7b-a97a-7f0bc535095a","idea":"Recovering a divisor parameter from a remainder","lesson":"Polynomial division and remainder","fingerprint":"ae83979694ed09177832173dbd98fd7f"},{"id":"eb0dc586-24c5-5b58-8d7f-0e745430090a","idea":"Using divisibility to find a coefficient","lesson":"Polynomial division and remainder","fingerprint":"5b856e40f89eb47c1f4403116afde8ca"},{"id":"0197bbd2-e0d0-5f81-853b-0bfe76a4e641","idea":"Arithmetic sequence rule from middle terms","lesson":"Sequences","fingerprint":"aa6929206b35bea84b3793970c077fa3"},{"id":"1003f7b0-8a16-5af0-b4d0-8aea0df4ee57","idea":"High-index terms of a geometric sequence","lesson":"Sequences","fingerprint":"c9ec176b84b812a4d8f4b0159d4155bc"},{"id":"33a79026-c3f7-5a55-928e-e595035c50e3","idea":"Summing a finite patterned series","lesson":"Sequences","fingerprint":"56aefbc1948a8a017a5356abbf39e9bd"},{"id":"35dc6ea5-40b4-5d5c-9276-822a3a7f3807","idea":"Arithmetic sequence term from two known terms","lesson":"Sequences","fingerprint":"d6954b2be8e3384b06310680d250c39d"},{"id":"489e131c-dce5-5214-9ceb-e7b6209d942e","idea":"Sum of the first n odd numbers","lesson":"Sequences","fingerprint":"6a1da356264365c9499c7f3c654cad1e"},{"id":"524e88ee-84de-5161-85d9-57eebb34b005","idea":"Explicit rule for a doubling sequence","lesson":"Sequences","fingerprint":"23936ceb50c83a19b90a3cc53f6f1418"},{"id":"7c35139a-029a-51fd-a970-19a386279109","idea":"Consecutive arithmetic terms with variables","lesson":"Sequences","fingerprint":"e8fc798d6dbd1aa933190d2210355aab"},{"id":"72bc20a3-8545-5b1a-a8fa-683b1b32b0d3","idea":"Digit positions in a repeating decimal","lesson":"Sequences","fingerprint":"56c094b2b19a43fd0ca2111ebb992a74"},{"id":"9870fa8a-4f65-4a0f-826a-ab5ecfe07cc9","idea":"Common ratio from separated geometric terms","lesson":"Sequences","fingerprint":"dc200265d89c96e3c50f83d0037254d7"},{"id":"a1fea07e-aed6-c933-4eba-c12ae4c65369","idea":"Arithmetic series in a seating model","lesson":"Sequences","fingerprint":"d7a94feb5bf4d05302ba3e8a57db165f"},{"id":"02308ce5-c682-53b8-88bf-c4c633df7225","idea":"Interpreting dimensions in a volume model","lesson":"Volume and surface area","fingerprint":"7ff17fb3b53a3da6aa2935588b9f587f"},{"id":"093fba82-26af-5bbc-a6df-5af830ff3753","idea":"Mass from density and cylinder volume","lesson":"Volume and surface area","fingerprint":"2ed397c9f64f0b3ba0b4ced941232f6e"},{"id":"09c4c1d7-526e-5804-b5d7-882720c219ee","idea":"Rectangular prism volume with fractional dimensions","lesson":"Volume and surface area","fingerprint":"1001a9a6d678e60ce5f0ac5343af6e9e"},{"id":"0ce93715-f9b1-5e81-88f7-4b6a8e523078","idea":"Depth from volume and base area","lesson":"Volume and surface area","fingerprint":"30f78cb937688b7e676c2aeaa4f649ff"},{"id":"0e41b704-4ff8-528a-ad9d-ca86d150b7b8","idea":"Cube surface area from volume","lesson":"Volume and surface area","fingerprint":"17dddf9fefd3eb6fb432acb733967502"},{"id":"11af28aa-4a85-7419-d966-1361063b998d","idea":"Volume scale factors for similar solids","lesson":"Volume and surface area","fingerprint":"1b509dee2a9b0995642bc58d331dc791"},{"id":"1a98e65e-44d9-5f09-a061-99ec4055bd69","idea":"Volume of a triangular prism","lesson":"Volume and surface area","fingerprint":"d9132932120b8beba8265d69c4f3257f"},{"id":"1b34b9d6-d5a7-548a-9766-1ed4a36a91a8","idea":"Volume of a rectangular pyramid","lesson":"Volume and surface area","fingerprint":"2de081ba73c72c170f1a8cf482859d91"},{"id":"1d7ce098-9bf6-5071-bbf3-3eb409abbc6b","idea":"Coordinates of vertices in a cube","lesson":"Volume and surface area","fingerprint":"c35de930724fbc8d13682d7048105855"},{"id":"21715799-2b84-543b-a5d5-e948683bf5f1","idea":"Cone height from circumference and slope angle","lesson":"Volume and surface area","fingerprint":"33aeef53beef6d2f35ccd0fa52981f9b"},{"id":"2a610d2a-86c0-8386-574a-e6ce2e386be3","idea":"Volume of a cylindrical sector","lesson":"Volume and surface area","fingerprint":"3a60a409d6037dca2bd0139ef1fa812f"},{"id":"2c386eb2-0f95-5a79-82ed-1190d9033a67","idea":"Cylinder volume under linear scaling","lesson":"Volume and surface area","fingerprint":"4af337666826d4ec391284f786d4fff5"}]'::jsonb)
 as r(id uuid,lesson text,idea text,fingerprint text);

do $est1_revision_ideas$
declare
 v_rows integer;
 v_expected_by_lesson constant jsonb := '{"Angles and polygons":11,"Area and perimeter":10,"Logic and sets":5,"Matrices":2,"Logarithms and exponentials":5,"Polynomial division and remainder":5,"Sequences":10,"Volume and surface area":12}'::jsonb;
begin
 if exists(select 1 from public.audit_log where action='revision.est1_idea_expansion.20260929') then
  raise exception 'EST I revision idea expansion already applied; do not rerun';
 end if;
 if (select count(*) from public.revision_items)<>2207
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1261
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>530
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>416
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>240 then
  raise exception 'Revision catalogue changed; re-review before expanding EST I';
 end if;
 if (select count(*) from est1_revision_idea_release)<>60
    or (select count(distinct id) from est1_revision_idea_release)<>60
    or (select count(distinct (lesson,idea)) from est1_revision_idea_release)<>60 then
  raise exception 'EST I revision release manifest is incomplete or duplicated';
 end if;
 if (select jsonb_object_agg(lesson,n) from (
       select lesson,count(*) n from est1_revision_idea_release group by lesson order by lesson
     ) x)<>v_expected_by_lesson then
  raise exception 'EST I revision release lesson distribution changed';
 end if;
 if exists(
  select 1 from est1_revision_idea_release x
  left join public.questions q on q.id=x.id
  left join public.question_keys k on k.question_id=q.id
  where q.id is null or q.track_id<>'est' or q.topic<>x.lesson
   or nullif(q.assets->>'verified_release','') is null
   or nullif(q.assets->>'release_hold_reason','') is not null
   or jsonb_typeof(k.correct) not in ('string','array')
   or length(btrim(k.explanation))=0
   or public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)<>x.fingerprint
 ) then raise exception 'Selected EST I source changed or is no longer eligible'; end if;
 if exists(select 1 from est1_revision_idea_release x join public.revision_items r on r.question_id=x.id) then
  raise exception 'Selected EST I question is already in Final Revision';
 end if;
 if exists(
  select 1 from est1_revision_idea_release x
  join public.revision_items r on r.lesson=x.lesson and r.idea=x.idea
 ) then raise exception 'Selected EST I idea already exists in its lesson'; end if;
 if exists(
  select 1 from est1_revision_idea_release x
  join public.questions q on q.id=x.id
  join public.questions q2 on md5(lower(regexp_replace(q2.stem,'\s+',' ','g'))||q2.choices::text)
    =md5(lower(regexp_replace(q.stem,'\s+',' ','g'))||q.choices::text)
  join public.revision_items r on r.question_id=q2.id
 ) then raise exception 'Selected EST I content duplicates an existing revision item'; end if;

 insert into public.revision_items(question_id,lesson,idea,difficulty,programmes,fingerprint,active,focus)
 select x.id,x.lesson,x.idea,q.difficulty,array['est']::text[],x.fingerprint,true,
  jsonb_build_object(
   'collections',jsonb_build_array('unique'),
   'bank_occurrences',1,
   'takeaway','Key skill: '||x.idea||'.',
   'math_format',case when q.stem like '%\(%' or q.stem like '%\[%' then 'latex' else 'plain' end,
   'release','20260929-est1-idea-expansion'
  )
 from est1_revision_idea_release x join public.questions q on q.id=x.id;
 get diagnostics v_rows=row_count;
 if v_rows<>60 then raise exception 'EST I revision insertion count is incorrect'; end if;

 insert into public.audit_log(action,target_type,target_id,meta)
 select 'revision.est1_idea_expansion.item.20260929','question',x.id::text,
  jsonb_build_object('track','est','lesson',x.lesson,'idea',x.idea,'fingerprint',x.fingerprint)
 from est1_revision_idea_release x;
 get diagnostics v_rows=row_count;
 if v_rows<>60 then raise exception 'EST I revision item audit is incomplete'; end if;

 if (select count(*) from public.revision_items)<>2267
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>590
    or (select count(distinct (r.lesson,r.idea)) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est')<>300
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id join public.question_keys k on k.question_id=q.id
        where q.track_id='est' and r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation))<>578
    or exists(select 1 from est1_revision_idea_release x join public.revision_items r on r.question_id=x.id where not r.active or r.programmes<>array['est']::text[])
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='sat')<>1261
    or (select count(*) from public.revision_items r join public.questions q on q.id=r.question_id where q.track_id='est2')<>416 then
  raise exception 'Post-release EST I revision verification failed';
 end if;

 insert into public.audit_log(action,target_type,target_id,meta)
 values ('revision.est1_idea_expansion.20260929','release','20260929',
  jsonb_build_object('track','est','added_questions',60,'added_ideas',60,
   'catalogue_questions',590,'catalogue_ideas',300,'lessons',v_expected_by_lesson,
   'classification_only',true,'new_answer_certification',false));
end $est1_revision_ideas$;

commit;

select q.track_id,count(*) total,
 count(*) filter(where r.fingerprint=public.revision_question_fingerprint(q.stem,q.choices,q.assets,k.correct,k.explanation)) ready,
 count(distinct (r.lesson,r.idea)) ideas
from public.revision_items r
join public.questions q on q.id=r.question_id
join public.question_keys k on k.question_id=q.id
group by q.track_id order by q.track_id;
