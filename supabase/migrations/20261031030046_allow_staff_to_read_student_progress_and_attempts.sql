create policy "staff read student study tasks" on public.study_tasks for select to authenticated using (public.has_staff_role(array['owner','super_admin','academic']));
create policy "staff read student mock attempts" on public.mock_attempts for select to authenticated using (public.has_staff_role(array['owner','super_admin','academic']));
create policy "staff read student pyq attempts" on public.pyq_attempts for select to authenticated using (public.has_staff_role(array['owner','super_admin','academic']));
