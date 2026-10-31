alter table public.mock_tests add column if not exists scheduled_for date;
alter table public.mock_tests add column if not exists strategy_text text;
alter table public.mock_tests add column if not exists publish_at timestamptz;
create index if not exists mock_tests_exam_schedule_idx on public.mock_tests(exam_id, scheduled_for) where published = true and is_active = true;
create policy "mock question staff manage" on public.mock_questions for all to authenticated using (public.has_staff_role(array['owner','super_admin','academic'])) with check (public.has_staff_role(array['owner','super_admin','academic']));
