-- Store official source URLs against every syllabus topic and seed an explicit review queue.
alter table public.syllabus_topic_audit add column if not exists source_url text;

insert into public.syllabus_topic_audit
  (topic_id, exam_id, review_status, review_note, source_title, source_url, syllabus_year, updated_at)
select n.id, n.exam_id, 'needs_review',
  'Topic-level comparison pending against the linked official source; do not treat as verified yet.',
  case e.slug
    when 'neet-ug' then 'NEET UG 2026 syllabus — NMC/NTA'
    when 'jee-main' then 'JEE Main 2027 syllabus — NTA'
    when 'cuet-ug' then 'CUET UG 2026 subject syllabus — NTA'
    when 'bpsc' then 'Combined Competitive Examination syllabus — BPSC'
    when 'bihar-police' then 'Bihar Police recruitment syllabus portal — CSBC'
    when 'ibps-sbi-banking' then 'CRP PO/MT XVI recruitment page — IBPS'
    when 'rrb-ntpc' then 'NTPC recruitment notices — RRB'
    when 'ssc-cgl' then 'Combined Graduate Level 2026 notice — SSC'
    when 'upsc-cse' then 'Civil Services Preliminary Examination 2026 — UPSC'
    when 'nda' then 'NDA/NA examination notifications — UPSC'
  end,
  case e.slug
    when 'neet-ug' then 'https://nta.ac.in/Download/Notice/Notice_20260108180635.pdf'
    when 'jee-main' then 'https://jeemain.nta.nic.in/document/syllabus-2027/'
    when 'cuet-ug' then 'https://cuet.nta.nic.in/cuetug-2026-syllabus/'
    when 'bpsc' then 'https://bpsc.bihar.gov.in/wp-content/uploads/2025/01/Syllabus-CC-Exam-Updated.pdf'
    when 'bihar-police' then 'https://csbc.bihar.gov.in/Syllabus.htm'
    when 'ibps-sbi-banking' then 'https://www.ibps.in/index.php/management-trainees-xvi/'
    when 'rrb-ntpc' then 'https://www.rrbcdg.gov.in/employment-notices.php'
    when 'ssc-cgl' then 'https://ssc.gov.in/api/attachment/uploads/masterData/NoticeBoards/Notice_of_adv_cgl_2026.pdf'
    when 'upsc-cse' then 'https://www.upsc.gov.in/examinations/Civil%20Services%20%28Preliminary%29%20Examination%2C%202026'
    when 'nda' then 'https://www.upsc.gov.in/exams-related-info/exam-notification/archives'
  end,
  case e.slug
    when 'neet-ug' then 2026 when 'jee-main' then 2027 when 'cuet-ug' then 2026
    when 'bpsc' then 2025 when 'bihar-police' then 2025 when 'ibps-sbi-banking' then 2026
    when 'rrb-ntpc' then 2025 when 'ssc-cgl' then 2026 when 'upsc-cse' then 2026 when 'nda' then 2026
  end,
  now()
from public.syllabus_nodes n join public.exams e on e.id=n.exam_id
where n.level='topic'
on conflict (topic_id) do update set
  source_title=excluded.source_title,
  source_url=excluded.source_url,
  syllabus_year=excluded.syllabus_year,
  review_status=case when public.syllabus_topic_audit.review_status='official'
    then 'official' else 'needs_review' end,
  updated_at=now();
