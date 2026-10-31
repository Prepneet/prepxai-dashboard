-- Additive PrepX Ai learning-content schema.
-- Existing notes and student progress are preserved.
alter table public.notes
  add column if not exists syllabus_node_id uuid references public.syllabus_nodes(id) on delete set null,
  add column if not exists language text not null default 'en',
  add column if not exists content_json jsonb not null default '[]'::jsonb,
  add column if not exists key_points text[] not null default '{}',
  add column if not exists quick_revision text,
  add column if not exists diagram_spec jsonb not null default '[]'::jsonb,
  add column if not exists reading_minutes integer not null default 5,
  add column if not exists syllabus_year integer,
  add column if not exists source_name text,
  add column if not exists source_url text,
  add column if not exists is_original boolean not null default true,
  add column if not exists content_version integer not null default 1,
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references auth.users(id) on delete set null;

create index if not exists notes_syllabus_node_idx on public.notes(syllabus_node_id);
create index if not exists notes_exam_subject_kind_idx on public.notes(exam, subject, kind) where is_active = true;

create table if not exists public.note_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  note_id uuid not null references public.notes(id) on delete cascade,
  status text not null default 'in_progress' check (status in ('in_progress','completed')),
  last_opened_at timestamptz not null default now(),
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, note_id)
);
alter table public.note_progress enable row level security;
grant select, insert, update, delete on public.note_progress to authenticated;
drop policy if exists "students manage own note progress" on public.note_progress;
create policy "students manage own note progress" on public.note_progress
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

alter table public.syllabus_topic_audit
  add column if not exists source_title text,
  add column if not exists syllabus_year integer,
  add column if not exists verified_at timestamptz,
  add column if not exists verified_by uuid references auth.users(id) on delete set null,
  add column if not exists source_hash text;

create index if not exists syllabus_audit_status_exam_idx
  on public.syllabus_topic_audit(exam_id, review_status);
