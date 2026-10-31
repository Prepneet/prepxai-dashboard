drop policy if exists "academic staff update syllabus topic audit" on public.syllabus_topic_audit;
create policy "academic staff update syllabus topic audit"
on public.syllabus_topic_audit for update to authenticated
using (has_staff_role(ARRAY['owner','super_admin','academic']::text[]))
with check (has_staff_role(ARRAY['owner','super_admin','academic']::text[]));
