-- Align NEET UG Biology to the 10 official NMC 2026 units.
-- Existing topic IDs are retained so student checkmarks, tasks, and notes remain linked.
-- Legacy Botany/Zoology containers are archived, not deleted.
alter table public.syllabus_nodes add column if not exists is_active boolean not null default true;

do $$
declare
  exam_uuid uuid;
  bio_uuid uuid;
  unit_row record;
  old_chapter record;
  target_title text;
begin
  select id into exam_uuid from public.exams where slug='neet-ug';
  select id into bio_uuid from public.syllabus_nodes where exam_id=exam_uuid and level='subject' and title='Biology' limit 1;
  if bio_uuid is null then
    insert into public.syllabus_nodes(exam_id,parent_id,title,level,sort_order,is_active)
    values(exam_uuid,null,'Biology','subject',3,true) returning id into bio_uuid;
  else
    update public.syllabus_nodes set is_active=true,sort_order=3 where id=bio_uuid;
  end if;
  for unit_row in select * from (values
    (1,'Diversity in Living World'),(2,'Structural Organisation in Animals and Plants'),
    (3,'Cell Structure and Function'),(4,'Plant Physiology'),(5,'Human Physiology'),
    (6,'Reproduction'),(7,'Genetics and Evolution'),(8,'Biology and Human Welfare'),
    (9,'Biotechnology and Its Applications'),(10,'Ecology and Environment')
  ) as u(sort_order,title) loop
    if not exists(select 1 from public.syllabus_nodes where exam_id=exam_uuid and parent_id=bio_uuid and level='chapter' and title=unit_row.title) then
      insert into public.syllabus_nodes(exam_id,parent_id,title,level,sort_order,is_active)
      values(exam_uuid,bio_uuid,unit_row.title,'chapter',unit_row.sort_order,true);
    else
      update public.syllabus_nodes set is_active=true,sort_order=unit_row.sort_order
      where exam_id=exam_uuid and parent_id=bio_uuid and level='chapter' and title=unit_row.title;
    end if;
  end loop;
  for old_chapter in
    select c.id,c.title as chapter_title,s.title as subject_title
    from public.syllabus_nodes c join public.syllabus_nodes s on s.id=c.parent_id
    where c.exam_id=exam_uuid and c.level='chapter' and s.title in ('Botany','Zoology')
  loop
    if old_chapter.chapter_title='Animal Kingdom and Structural Organisation' then
      update public.syllabus_nodes t set parent_id=(
        select id from public.syllabus_nodes where exam_id=exam_uuid and parent_id=bio_uuid and level='chapter'
          and title=case
            when t.title ilike '%locomotion%' then 'Human Physiology'
            when t.title ilike '%digestive system%' or t.title ilike '%circulatory%' or t.title ilike '%respiratory%'
              or t.title ilike '%excretory%' or t.title ilike '%tissue%' or t.title ilike '%earthworm%'
              or t.title ilike '%cockroach%' or t.title ilike '%frog%' then 'Structural Organisation in Animals and Plants'
            else 'Diversity in Living World' end
      ) where t.parent_id=old_chapter.id and t.level='topic';
    else
      target_title := case old_chapter.chapter_title
        when 'Diversity in the Living World' then 'Diversity in Living World'
        when 'Structural Organisation in Plants' then 'Structural Organisation in Animals and Plants'
        when 'Cell Structure and Function' then 'Cell Structure and Function'
        when 'Plant Physiology' then 'Plant Physiology'
        when 'Human Physiology' then 'Human Physiology'
        when 'Reproduction in Plants' then 'Reproduction'
        when 'Human Reproduction and Reproductive Health' then 'Reproduction'
        when 'Genetics and Evolution' then 'Genetics and Evolution'
        when 'Biology and Human Welfare' then 'Biology and Human Welfare'
        when 'Biotechnology and Its Applications' then 'Biotechnology and Its Applications'
        when 'Ecology and Environment' then 'Ecology and Environment'
        else null end;
      if target_title is not null then
        update public.syllabus_nodes t set parent_id=(
          select id from public.syllabus_nodes where exam_id=exam_uuid and parent_id=bio_uuid and level='chapter' and title=target_title
        ) where t.parent_id=old_chapter.id and t.level='topic';
      end if;
    end if;
    update public.syllabus_nodes set is_active=false where id=old_chapter.id;
  end loop;
  update public.syllabus_nodes set is_active=false
  where exam_id=exam_uuid and level='subject' and title in ('Botany','Zoology');
end $$;

update public.syllabus_topic_audit a set
  review_status=case when c.title='Basic Mathematics for Physics' then 'supplementary' else 'official' end,
  review_note=case when c.title='Basic Mathematics for Physics'
    then 'Foundational support material; not a standalone unit in the NMC NEET UG 2026 syllabus.'
    else 'Mapped against the NMC-finalized NEET UG 2026 official syllabus unit; student progress is preserved by keeping topic IDs unchanged.' end,
  source_title='NEET UG 2026 official syllabus — NMC / NTA',
  source_url='https://nta.ac.in/Download/Notice/Notice_20260108180635.pdf',
  syllabus_year=2026,verified_at=now(),updated_at=now()
from public.syllabus_nodes t join public.syllabus_nodes c on c.id=t.parent_id
where a.topic_id=t.id and t.exam_id=(select id from public.exams where slug='neet-ug') and t.level='topic';
