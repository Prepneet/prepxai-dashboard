-- Keep original PrepX Ai practice questions separate from verified previous-year questions.
alter table public.questions
  add column if not exists is_pyq boolean not null default false;

comment on column public.questions.is_pyq is
  'True only for verified previous-year exam questions. Original practice questions remain false.';
