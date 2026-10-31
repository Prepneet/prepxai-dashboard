alter table public.study_tasks add column if not exists node_id uuid references public.syllabus_nodes(id) on delete set null;
create index if not exists study_tasks_user_node_date_idx on public.study_tasks(user_id, node_id, task_date);
