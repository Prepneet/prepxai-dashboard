create table if not exists public.pyq_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exam_id uuid not null references public.exams(id) on delete restrict,
  question_id uuid not null references public.questions(id) on delete cascade,
  selected_option integer,
  is_correct boolean not null,
  time_taken_sec integer not null default 0 check (time_taken_sec >= 0),
  created_at timestamptz not null default now()
);
create index if not exists pyq_attempts_user_exam_created_idx on public.pyq_attempts(user_id, exam_id, created_at desc);
alter table public.pyq_attempts enable row level security;
create policy "students read own pyq attempts" on public.pyq_attempts for select to authenticated using ((select auth.uid()) = user_id);
