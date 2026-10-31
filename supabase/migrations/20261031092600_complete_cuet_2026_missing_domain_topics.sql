-- Fill three CUET UG 2026 domain subjects whose chapter nodes had no topic children.
-- Resolve parents by exam and syllabus labels; do not rely on generated UUIDs.
with unit_data(subject_name,chapter_name,topic,ord) as (values
 ('Business Studies (Domain)','Principles and Functions of Management and Business Finance','Unit I: Nature and Significance of Management',1),
 ('Business Studies (Domain)','Principles and Functions of Management and Business Finance','Unit II: Principles of Management',2),
 ('Business Studies (Domain)','Principles and Functions of Management and Business Finance','Unit III: Business Environment',3),
 ('Business Studies (Domain)','Principles and Functions of Management and Business Finance','Unit IV: Planning',4),
 ('Business Studies (Domain)','Principles and Functions of Management and Business Finance','Unit V: Organising',5),
 ('Business Studies (Domain)','Principles and Functions of Management and Business Finance','Unit VI: Staffing',6),
 ('Business Studies (Domain)','Principles and Functions of Management and Business Finance','Unit VII: Directing',7),
 ('Business Studies (Domain)','Principles and Functions of Management and Business Finance','Unit VIII: Controlling',8),
 ('Business Studies (Domain)','Principles and Functions of Management and Business Finance','Unit IX: Business Finance',9),
 ('Business Studies (Domain)','Principles and Functions of Management and Business Finance','Unit X: Financial Markets',10),
 ('Business Studies (Domain)','Principles and Functions of Management and Business Finance','Unit XI: Marketing',11),
 ('Business Studies (Domain)','Principles and Functions of Management and Business Finance','Unit XII: Consumer Protection',12),
 ('Economics / Business Economics (Domain)','Development Economics, Macroeconomics and Indian Economy','Microeconomics: Consumer Behaviour and Demand',1),
 ('Economics / Business Economics (Domain)','Development Economics, Macroeconomics and Indian Economy','Production, Costs and Firm Behaviour',2),
 ('Economics / Business Economics (Domain)','Development Economics, Macroeconomics and Indian Economy','Market Equilibrium and Applications',3),
 ('Economics / Business Economics (Domain)','Development Economics, Macroeconomics and Indian Economy','Macroeconomics and National Income Accounting',4),
 ('Economics / Business Economics (Domain)','Development Economics, Macroeconomics and Indian Economy','Money and Banking',5),
 ('Economics / Business Economics (Domain)','Development Economics, Macroeconomics and Indian Economy','Income and Employment Determination',6),
 ('Economics / Business Economics (Domain)','Development Economics, Macroeconomics and Indian Economy','Government Budget and the Economy',7),
 ('Economics / Business Economics (Domain)','Development Economics, Macroeconomics and Indian Economy','Open Economy Macroeconomics',8),
 ('Economics / Business Economics (Domain)','Development Economics, Macroeconomics and Indian Economy','Indian Economic Development: 1947–1990',9),
 ('Economics / Business Economics (Domain)','Development Economics, Macroeconomics and Indian Economy','Economic Reforms since 1991',10),
 ('Economics / Business Economics (Domain)','Development Economics, Macroeconomics and Indian Economy','Current Challenges: Human Capital, Rural Development and Employment',11),
 ('Economics / Business Economics (Domain)','Development Economics, Macroeconomics and Indian Economy','Environment, Sustainability and Comparative Development',12),
 ('Physics (Domain)','Electrostatics, Current Electricity and Magnetism','Unit 1: Electrostatics',1),
 ('Physics (Domain)','Electrostatics, Current Electricity and Magnetism','Unit 2: Current Electricity',2),
 ('Physics (Domain)','Electrostatics, Current Electricity and Magnetism','Unit 3: Magnetic Effects of Current and Magnetism',3),
 ('Physics (Domain)','Electrostatics, Current Electricity and Magnetism','Unit 4: Electromagnetic Induction and Alternating Currents',4),
 ('Physics (Domain)','Electrostatics, Current Electricity and Magnetism','Unit 5: Electromagnetic Waves',5),
 ('Physics (Domain)','Electrostatics, Current Electricity and Magnetism','Unit 6: Optics',6),
 ('Physics (Domain)','Electrostatics, Current Electricity and Magnetism','Unit 7: Dual Nature of Matter and Radiation',7),
 ('Physics (Domain)','Electrostatics, Current Electricity and Magnetism','Unit 8: Atoms and Nuclei',8),
 ('Physics (Domain)','Electrostatics, Current Electricity and Magnetism','Unit 9: Electronic Devices',9)
)
insert into public.syllabus_nodes(exam_id,parent_id,title,level,sort_order)
select e.id,c.id,d.topic,'topic',d.ord
from unit_data d
join public.exams e on e.slug='cuet-ug'
join public.syllabus_nodes s on s.exam_id=e.id and s.level='subject' and s.title=d.subject_name
join public.syllabus_nodes c on c.exam_id=e.id and c.parent_id=s.id and c.level='chapter' and c.title=d.chapter_name
where not exists(select 1 from public.syllabus_nodes x where x.exam_id=e.id and x.parent_id=c.id and x.level='topic' and x.title=d.topic);

insert into public.syllabus_topic_audit(topic_id,exam_id,review_status,review_note,source_title,source_url,syllabus_year,updated_at)
select n.id,n.exam_id,'needs_review','Matched to the CUET UG 2026 official subject syllabus; topic-level final verification pending.',
  case s.title when 'Business Studies (Domain)' then 'Business Studies 305 — CUET UG 2026'
       when 'Economics / Business Economics (Domain)' then 'Economics 309 — CUET UG 2026'
       else 'Physics 322 — CUET UG 2026' end,
  case s.title when 'Business Studies (Domain)' then 'https://cdnbbsr.s3waas.gov.in/s3d1a21da7bca4abff8b0b61b87597de73/uploads/2025/12/20251227259182286.pdf'
       when 'Economics / Business Economics (Domain)' then 'https://cdnbbsr.s3waas.gov.in/s3d1a21da7bca4abff8b0b61b87597de73/uploads/2025/12/202512271366341541.pdf'
       else 'https://cdnbbsr.s3waas.gov.in/s3d1a21da7bca4abff8b0b61b87597de73/uploads/2025/12/202512271334142557.pdf' end,
  2026,now()
from public.syllabus_nodes n
join public.syllabus_nodes c on c.id=n.parent_id
join public.syllabus_nodes s on s.id=c.parent_id
join public.exams e on e.id=n.exam_id
where e.slug='cuet-ug' and n.level='topic'
  and s.title in ('Business Studies (Domain)','Economics / Business Economics (Domain)','Physics (Domain)')
  and c.title in ('Principles and Functions of Management and Business Finance','Development Economics, Macroeconomics and Indian Economy','Electrostatics, Current Electricity and Magnetism')
on conflict(topic_id) do update set source_title=excluded.source_title,source_url=excluded.source_url,syllabus_year=excluded.syllabus_year,updated_at=now();
