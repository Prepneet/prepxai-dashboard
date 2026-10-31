alter table public.syllabus_nodes add column if not exists is_active boolean not null default true;
create index if not exists syllabus_nodes_active_exam_level_idx on public.syllabus_nodes(exam_id,level,sort_order) where is_active=true;
