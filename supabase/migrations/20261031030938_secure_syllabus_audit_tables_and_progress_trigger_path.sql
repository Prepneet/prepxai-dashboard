alter table public.syllabus_topic_audit enable row level security;
alter table public.syllabus_topic_overlap_review enable row level security;
alter table public.syllabus_chapter_structure_audit enable row level security;
create policy "staff read syllabus topic audit" on public.syllabus_topic_audit for select to authenticated using (public.has_staff_role(array['owner','super_admin','academic']));
create policy "staff read syllabus overlap review" on public.syllabus_topic_overlap_review for select to authenticated using (public.has_staff_role(array['owner','super_admin','academic']));
create policy "staff read syllabus chapter audit" on public.syllabus_chapter_structure_audit for select to authenticated using (public.has_staff_role(array['owner','super_admin','academic']));
alter function public.set_student_syllabus_progress_updated_at() set search_path = public;
