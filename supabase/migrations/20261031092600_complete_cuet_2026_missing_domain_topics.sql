-- Fill three CUET UG 2026 domain subjects whose chapter nodes had no topic children.
-- Source documents are the official NTA-hosted PDFs linked from the CUET UG 2026 syllabus page.
insert into public.syllabus_nodes(exam_id,parent_id,title,level,sort_order)
select e.id,v.chapter_id,v.topic,'topic',v.ord
from public.exams e
cross join (values
 ('b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid,'Unit I: Nature and Significance of Management',1),
 ('b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid,'Unit II: Principles of Management',2),
 ('b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid,'Unit III: Business Environment',3),
 ('b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid,'Unit IV: Planning',4),
 ('b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid,'Unit V: Organising',5),
 ('b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid,'Unit VI: Staffing',6),
 ('b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid,'Unit VII: Directing',7),
 ('b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid,'Unit VIII: Controlling',8),
 ('b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid,'Unit IX: Business Finance',9),
 ('b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid,'Unit X: Financial Markets',10),
 ('b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid,'Unit XI: Marketing',11),
 ('b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid,'Unit XII: Consumer Protection',12),
 ('88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid,'Microeconomics: Consumer Behaviour and Demand',1),
 ('88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid,'Production, Costs and Firm Behaviour',2),
 ('88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid,'Market Equilibrium and Applications',3),
 ('88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid,'Macroeconomics and National Income Accounting',4),
 ('88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid,'Money and Banking',5),
 ('88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid,'Income and Employment Determination',6),
 ('88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid,'Government Budget and the Economy',7),
 ('88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid,'Open Economy Macroeconomics',8),
 ('88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid,'Indian Economic Development: 1947–1990',9),
 ('88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid,'Economic Reforms since 1991',10),
 ('88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid,'Current Challenges: Human Capital, Rural Development and Employment',11),
 ('88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid,'Environment, Sustainability and Comparative Development',12),
 ('4add5d3a-633d-4d93-8cb4-c6e1b5570df5'::uuid,'Unit 1: Electrostatics',1),
 ('4add5d3a-633d-4d93-8cb4-c6e1b5570df5'::uuid,'Unit 2: Current Electricity',2),
 ('4add5d3a-633d-4d93-8cb4-c6e1b5570df5'::uuid,'Unit 3: Magnetic Effects of Current and Magnetism',3),
 ('4add5d3a-633d-4d93-8cb4-c6e1b5570df5'::uuid,'Unit 4: Electromagnetic Induction and Alternating Currents',4),
 ('4add5d3a-633d-4d93-8cb4-c6e1b5570df5'::uuid,'Unit 5: Electromagnetic Waves',5),
 ('4add5d3a-633d-4d93-8cb4-c6e1b5570df5'::uuid,'Unit 6: Optics',6),
 ('4add5d3a-633d-4d93-8cb4-c6e1b5570df5'::uuid,'Unit 7: Dual Nature of Matter and Radiation',7),
 ('4add5d3a-633d-4d93-8cb4-c6e1b5570df5'::uuid,'Unit 8: Atoms and Nuclei',8),
 ('4add5d3a-633d-4d93-8cb4-c6e1b5570df5'::uuid,'Unit 9: Electronic Devices',9)
) as v(chapter_id,topic,ord)
where e.slug='cuet-ug'
and not exists(select 1 from public.syllabus_nodes x where x.exam_id=e.id and x.parent_id=v.chapter_id and x.level='topic' and x.title=v.topic);

insert into public.syllabus_topic_audit(topic_id,exam_id,review_status,review_note,source_title,source_url,syllabus_year,updated_at)
select n.id,n.exam_id,'needs_review','Matched to the CUET UG 2026 official subject syllabus; topic-level final verification pending.',
  case when n.parent_id='b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid then 'Business Studies 305 — CUET UG 2026'
       when n.parent_id='88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid then 'Economics 309 — CUET UG 2026'
       else 'Physics 322 — CUET UG 2026' end,
  case when n.parent_id='b8aa0016-7905-45d7-b5c7-8a93aff96f49'::uuid then 'https://cdnbbsr.s3waas.gov.in/s3d1a21da7bca4abff8b0b61b87597de73/uploads/2025/12/20251227259182286.pdf'
       when n.parent_id='88242c3f-9c6e-4394-9246-c29a1fb31127'::uuid then 'https://cdnbbsr.s3waas.gov.in/s3d1a21da7bca4abff8b0b61b87597de73/uploads/2025/12/202512271366341541.pdf'
       else 'https://cdnbbsr.s3waas.gov.in/s3d1a21da7bca4abff8b0b61b87597de73/uploads/2025/12/202512271334142557.pdf' end,
  2026,now()
from public.syllabus_nodes n
where n.level='topic' and n.parent_id in ('b8aa0016-7905-45d7-b5c7-8a93aff96f49','88242c3f-9c6e-4394-9246-c29a1fb31127','4add5d3a-633d-4d93-8cb4-c6e1b5570df5')
on conflict(topic_id) do update set source_title=excluded.source_title,source_url=excluded.source_url,syllabus_year=excluded.syllabus_year,updated_at=now();
