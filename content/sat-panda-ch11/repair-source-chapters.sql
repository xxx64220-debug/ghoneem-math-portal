-- Correct existing College Panda source-chapter tags for Chapters 6–11.
-- Scoped to the known 205 records; safe to rerun after the correction.
begin;
do $$
declare wrong_count integer;
begin
  select count(*) into wrong_count from public.questions
  where track_id='sat'
    and assets->>'code' ~ '^PANDA-CH(0[6-9]|10|11)-E[12]-Q[0-9]{2}$'
    and assets->>'source_chapter' = '5';
  if wrong_count not in (0,205) then
    raise exception 'Unexpected count of incorrectly tagged Panda questions: %',wrong_count;
  end if;
end $$;

with fixed as (
  update public.questions q
  set assets=jsonb_set(q.assets,'{source_chapter}',
    to_jsonb((substring(q.assets->>'code' from '^PANDA-CH([0-9]+)'))::integer))
  where q.track_id='sat'
    and q.assets->>'code' ~ '^PANDA-CH(0[6-9]|10|11)-E[12]-Q[0-9]{2}$'
    and q.assets->>'source_chapter'='5'
  returning q.id,q.stem,q.choices,q.assets
)
update public.revision_items r
set fingerprint=md5(jsonb_build_array(f.stem,f.choices,f.assets,k.correct,k.explanation)::text)
from fixed f, public.question_keys k
where r.question_id=f.id and k.question_id=f.id;

do $$
begin
  if (select count(*) from public.questions
      where track_id='sat'
        and assets->>'code' ~ '^PANDA-CH(0[6-9]|10|11)-E[12]-Q[0-9]{2}$'
        and assets->>'source_chapter' =
            (substring(assets->>'code' from '^PANDA-CH([0-9]+)'))::integer::text) <> 205
  then raise exception 'Panda source-chapter repair incomplete'; end if;
end $$;
commit;
