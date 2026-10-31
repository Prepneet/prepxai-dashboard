alter table public.mock_tests add column if not exists assigned_user_id uuid references auth.users(id) on delete cascade;
create index if not exists mock_tests_assigned_user_schedule_idx on public.mock_tests(assigned_user_id, scheduled_for) where assigned_user_id is not null;
