drop policy if exists "staff manage updates" on public.exam_updates;
create policy "staff manage updates" on public.exam_updates for all to authenticated using (public.is_staff()) with check (public.is_staff());
drop policy if exists "staff read student syllabus progress" on public.student_syllabus_progress;
create policy "staff read student syllabus progress" on public.student_syllabus_progress for select to authenticated using (public.is_staff());
revoke all on function public.is_staff() from public, anon;
grant execute on function public.is_staff() to authenticated;
