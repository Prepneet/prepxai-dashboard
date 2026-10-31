-- Add a separate CDS syllabus instead of reusing NDA topics.
insert into public.exams(slug,name,category,short_desc,exam_mode,language_support,is_active)
values('cds','Combined Defence Services (CDS)','Defence Entrance','UPSC CDS: English, General Knowledge and Elementary Mathematics','Pen and Paper',array['English']::text[],true)
on conflict(slug) do update set name=excluded.name,category=excluded.category,short_desc=excluded.short_desc,is_active=true;

do $$
declare
  exam_uuid uuid; subj jsonb; chap jsonb; topic text;
  subject_uuid uuid; chapter_uuid uuid; s_order integer:=0; c_order integer; t_order integer;
begin
  select id into exam_uuid from public.exams where slug='cds';
  for subj in select value from jsonb_array_elements($data$[
    {"subject":"English","chapters":[
      {"title":"Comprehension and Reading Skills","topics":["Reading comprehension and inference","Main idea, tone and purpose","Vocabulary in context and contextual meaning"]},
      {"title":"Grammar and Usage","topics":["Parts of speech and sentence structure","Tenses, subject–verb agreement and articles","Prepositions, conjunctions and modifiers","Active/passive voice and direct/indirect speech"]},
      {"title":"Vocabulary and Verbal Ability","topics":["Synonyms and antonyms","Idioms, phrases and one-word substitutions","Spotting errors and sentence improvement","Ordering of words and sentences; fill in the blanks"]}
    ]},
    {"subject":"General Knowledge","chapters":[
      {"title":"Current Events and Everyday Science","topics":["National and international current affairs","Science in everyday life and recent developments","Defence exercises, organisations and national security awareness"]},
      {"title":"History and Culture of India","topics":["Ancient and medieval Indian history","Modern Indian history and the freedom movement","Indian culture, art, architecture and heritage"]},
      {"title":"Geography","topics":["Physical geography: landforms, climate and resources","Indian geography: rivers, agriculture, minerals and industries","World geography and environmental geography"]},
      {"title":"Polity and Economy","topics":["Constitution, political system and governance","Fundamental rights, duties, Parliament and judiciary","Indian economy: basic concepts, planning and development"]},
      {"title":"General Science and Environment","topics":["Physics and chemistry in everyday applications","Biology, human body, health and diseases","Ecology, biodiversity, pollution and conservation"]}
    ]},
    {"subject":"Elementary Mathematics","chapters":[
      {"title":"Arithmetic","topics":["Number system, fractions, decimals and simplification","Ratio, proportion, percentage and averages","Profit, loss, discount, interest and taxation","Time, work, distance, speed and elementary mensuration","HCF, LCM, divisibility and elementary number properties"]},
      {"title":"Algebra","topics":["Basic operations, factors and polynomials","Remainder and factor theorems","Quadratic equations and simultaneous linear equations","Indices, logarithms and elementary identities"]},
      {"title":"Trigonometry","topics":["Trigonometric ratios and standard identities","Trigonometric tables and transformations","Heights and distances"]},
      {"title":"Geometry and Mensuration","topics":["Lines, angles, triangles and congruence","Quadrilaterals, circles and polygons","Perimeter and area of plane figures","Surface area and volume of cuboids, cones, cylinders and spheres"]},
      {"title":"Statistics","topics":["Collection and tabulation of data","Bar charts, histograms and frequency polygons","Measures of central tendency: mean, median and mode"]}
    ]}
  ]$data$::jsonb) loop
    s_order:=s_order+1;
    select id into subject_uuid from public.syllabus_nodes where exam_id=exam_uuid and level='subject' and title=subj->>'subject' limit 1;
    if subject_uuid is null then
      insert into public.syllabus_nodes(exam_id,parent_id,title,level,sort_order) values(exam_uuid,null,subj->>'subject','subject',s_order) returning id into subject_uuid;
    end if;
    c_order:=0;
    for chap in select value from jsonb_array_elements(subj->'chapters') loop
      c_order:=c_order+1;
      select id into chapter_uuid from public.syllabus_nodes where exam_id=exam_uuid and level='chapter' and parent_id=subject_uuid and title=chap->>'title' limit 1;
      if chapter_uuid is null then
        insert into public.syllabus_nodes(exam_id,parent_id,title,level,sort_order) values(exam_uuid,subject_uuid,chap->>'title','chapter',c_order) returning id into chapter_uuid;
      end if;
      t_order:=0;
      for topic in select jsonb_array_elements_text(chap->'topics') loop
        t_order:=t_order+1;
        if not exists(select 1 from public.syllabus_nodes where exam_id=exam_uuid and level='topic' and parent_id=chapter_uuid and title=topic) then
          insert into public.syllabus_nodes(exam_id,parent_id,title,level,sort_order) values(exam_uuid,chapter_uuid,topic,'topic',t_order);
        end if;
      end loop;
    end loop;
  end loop;
end $$;

insert into public.syllabus_topic_audit(topic_id,exam_id,review_status,review_note,source_title,source_url,syllabus_year,updated_at)
select n.id,n.exam_id,'needs_review',
  'Mapped to UPSC CDS 2026 syllabus framework; confirm exact paper-specific topic detail before certification.',
  'Combined Defence Services Examination (I), 2026 — UPSC',
  'https://www.upsc.gov.in/exams-related-info/exam-notification/archives',2026,now()
from public.syllabus_nodes n join public.exams e on e.id=n.exam_id where e.slug='cds' and n.level='topic'
on conflict(topic_id) do update set source_title=excluded.source_title,source_url=excluded.source_url,syllabus_year=excluded.syllabus_year,updated_at=now();
