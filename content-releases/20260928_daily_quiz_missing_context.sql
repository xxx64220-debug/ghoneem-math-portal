DO $repair$
DECLARE changed integer;
BEGIN
  IF (SELECT count(*) FROM public.questions WHERE id IN (
    '5d91ac0f-4a39-442b-589e-b668c396fa33','ba73ebd6-fc48-3f20-4799-49f55a3bfc87',
    '771d0c68-8e92-24d9-1c4e-0e63488b4176','b790b995-29fa-bde7-76ec-e0bba55d90bb',
    'e04957e5-b3a2-5e5d-9f1b-f49fb7325540','a0c46847-72c6-581c-8eae-e24748c74a81')) <> 6
  THEN RAISE EXCEPTION 'Expected six question records'; END IF;

  UPDATE public.questions
  SET topic='Coordinate Geometry, Circles & Conics',
      stem=$setup$In the figure, circle C has center O and radius 4 cm. A and K are endpoints of a diameter. AE is tangent to the circle at A, so AE is perpendicular to OA. H lies on OK with OH = 1.6 cm. B lies on the circle with BH perpendicular to OK, and B, O, E lie on one straight line. (Figure not drawn to scale.)$setup$ || E'\n\nQuestion 32. To the nearest tenth, what is the measure of angle OBH?',
      choices='[{"key":"A","text":"22.5°"},{"key":"B","text":"23.6°"},{"key":"C","text":"24.6°"},{"key":"D","text":"25.5°"},{"key":"E","text":"26.5°"}]'::jsonb,
      assets=assets || jsonb_build_object('svg',$svg$<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 350 390" width="350" height="390" role="img" aria-label="Circle centered at O with diameter AK, tangent AE at A, B on the circle, H on OK, and E, O, B collinear">
<circle cx="180" cy="155" r="92" fill="none" stroke="#263a58" stroke-width="2"/>
<line x1="88" y1="155" x2="272" y2="155" stroke="#263a58" stroke-width="2"/>
<line x1="88" y1="48" x2="88" y2="375" stroke="#263a58" stroke-width="2"/>
<line x1="88" y1="365.8" x2="216.8" y2="70.7" stroke="#263a58" stroke-width="2"/>
<line x1="216.8" y1="70.7" x2="216.8" y2="155" stroke="#263a58" stroke-width="2"/>
<path d="M88 167 L100 167 L100 155 M205 155 L205 144 L216.8 144" fill="none" stroke="#263a58" stroke-width="1.5"/>
<circle cx="88" cy="155" r="3" fill="#263a58"/><circle cx="180" cy="155" r="3" fill="#263a58"/><circle cx="272" cy="155" r="3" fill="#263a58"/><circle cx="216.8" cy="155" r="3" fill="#263a58"/><circle cx="216.8" cy="70.7" r="3" fill="#263a58"/><circle cx="88" cy="365.8" r="3" fill="#263a58"/>
<text x="70" y="150" font-size="16">A</text><text x="166" y="147" font-size="16">O</text><text x="277" y="160" font-size="16">K</text><text x="220" y="165" font-size="16">H</text><text x="220" y="66" font-size="16">B</text><text x="70" y="380" font-size="16">E</text><text x="265" y="229" font-size="16">C</text>
</svg>$svg$,'figure_caption','Circle and tangent diagram shared by Questions 32 and 33','content_repair','2026-09-28-shared-circle-context')
  WHERE id IN ('5d91ac0f-4a39-442b-589e-b668c396fa33','ba73ebd6-fc48-3f20-4799-49f55a3bfc87');
  GET DIAGNOSTICS changed=ROW_COUNT;
  IF changed<>2 THEN RAISE EXCEPTION 'Expected two Question 32 updates, got %',changed; END IF;

  UPDATE public.questions
  SET topic='Coordinate Geometry, Circles & Conics',
      stem=$setup$In the figure, circle C has center O and radius 4 cm. A and K are endpoints of a diameter. AE is tangent to the circle at A, so AE is perpendicular to OA. H lies on OK with OH = 1.6 cm. B lies on the circle with BH perpendicular to OK, and B, O, E lie on one straight line. (Figure not drawn to scale.)$setup$ || E'\n\nQuestion 33. What is the length of OE?',
      choices='[{"key":"A","text":"6 cm"},{"key":"B","text":"8 cm"},{"key":"C","text":"10 cm"},{"key":"D","text":"12 cm"},{"key":"E","text":"14 cm"}]'::jsonb,
      assets=assets || jsonb_build_object('svg',$svg$<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 350 390" width="350" height="390" role="img" aria-label="Circle centered at O with diameter AK, tangent AE at A, B on the circle, H on OK, and E, O, B collinear">
<circle cx="180" cy="155" r="92" fill="none" stroke="#263a58" stroke-width="2"/>
<line x1="88" y1="155" x2="272" y2="155" stroke="#263a58" stroke-width="2"/>
<line x1="88" y1="48" x2="88" y2="375" stroke="#263a58" stroke-width="2"/>
<line x1="88" y1="365.8" x2="216.8" y2="70.7" stroke="#263a58" stroke-width="2"/>
<line x1="216.8" y1="70.7" x2="216.8" y2="155" stroke="#263a58" stroke-width="2"/>
<path d="M88 167 L100 167 L100 155 M205 155 L205 144 L216.8 144" fill="none" stroke="#263a58" stroke-width="1.5"/>
<circle cx="88" cy="155" r="3" fill="#263a58"/><circle cx="180" cy="155" r="3" fill="#263a58"/><circle cx="272" cy="155" r="3" fill="#263a58"/><circle cx="216.8" cy="155" r="3" fill="#263a58"/><circle cx="216.8" cy="70.7" r="3" fill="#263a58"/><circle cx="88" cy="365.8" r="3" fill="#263a58"/>
<text x="70" y="150" font-size="16">A</text><text x="166" y="147" font-size="16">O</text><text x="277" y="160" font-size="16">K</text><text x="220" y="165" font-size="16">H</text><text x="220" y="66" font-size="16">B</text><text x="70" y="380" font-size="16">E</text><text x="265" y="229" font-size="16">C</text>
</svg>$svg$,'figure_caption','Circle and tangent diagram shared by Questions 32 and 33','content_repair','2026-09-28-shared-circle-context')
  WHERE id IN ('771d0c68-8e92-24d9-1c4e-0e63488b4176','b790b995-29fa-bde7-76ec-e0bba55d90bb');
  GET DIAGNOSTICS changed=ROW_COUNT;
  IF changed<>2 THEN RAISE EXCEPTION 'Expected two Question 33 updates, got %',changed; END IF;

  UPDATE public.questions
  SET stem='If p(x) = x³ − x² − x − 2 and q(x) = x² + 2x + a have a common factor, what is the value of a?',
      choices='[{"key":"A","text":"−8"},{"key":"B","text":"−3"},{"key":"C","text":"−2"},{"key":"D","text":"2"},{"key":"E","text":"8"}]'::jsonb,
      assets=assets || jsonb_build_object('content_repair','2026-09-28-polynomial-options')
  WHERE id IN ('e04957e5-b3a2-5e5d-9f1b-f49fb7325540','a0c46847-72c6-581c-8eae-e24748c74a81');
  GET DIAGNOSTICS changed=ROW_COUNT;
  IF changed<>2 THEN RAISE EXCEPTION 'Expected two polynomial updates, got %',changed; END IF;
END
$repair$;
