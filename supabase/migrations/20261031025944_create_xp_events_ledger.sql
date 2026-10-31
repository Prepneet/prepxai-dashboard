create table if not exists public.xp_events (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, source_type text not null check (source_type in ('study_task','pyq','mock_test')), source_id uuid not null, points integer not null check (points > 0), created_at timestamptz not null default now(), unique(user_id, source_type, source_id));
create index if not exists xp_events_week_user_idx on public.xp_events(created_at desc, user_id);
alter table public.xp_events enable row level security;
create policy "students read own xp" on public.xp_events for select to authenticated using ((select auth.uid()) = user_id);
create policy "staff read xp" on public.xp_events for select to authenticated using (public.has_staff_role(array['owner','super_admin','academic']));
