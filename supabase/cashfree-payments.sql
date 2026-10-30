-- PrepX Ai Cashfree payments: run once in Supabase SQL Editor.
-- No client-side policies are intentionally added. Only server-side service-role APIs may access this table.

create table if not exists public.payment_orders (
  order_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  plan text not null check (plan in ('plus','pro')),
  amount_paise integer not null check (amount_paise in (900,3900,6900)),
  status text not null default 'CREATED' check (status in ('CREATED','PAID','FAILED')),
  cf_order_id text,
  payment_session_id text,
  cf_payment_id text unique,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

alter table public.payment_orders enable row level security;
revoke all on public.payment_orders from anon, authenticated;
grant all on public.payment_orders to service_role;

create or replace function public.activate_cashfree_order(p_order_id text, p_cf_payment_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  payment_row public.payment_orders%rowtype;
  next_expiry timestamptz;
begin
  select * into payment_row
  from public.payment_orders
  where order_id = p_order_id
  for update;

  if not found then
    raise exception 'Payment order not found';
  end if;

  if payment_row.status = 'PAID' then
    return jsonb_build_object('ok', true, 'already_paid', true);
  end if;

  if payment_row.status <> 'CREATED' then
    raise exception 'Payment order is not payable';
  end if;

  if exists (select 1 from public.payment_orders where cf_payment_id = p_cf_payment_id) then
    raise exception 'Payment already used';
  end if;

  next_expiry := now() + interval '30 days';

  update public.profiles
  set plan = payment_row.plan,
      plan_expires_at = next_expiry
  where id = payment_row.user_id;

  if not found then
    raise exception 'Student profile not found';
  end if;

  update public.payment_orders
  set status = 'PAID',
      cf_payment_id = p_cf_payment_id,
      paid_at = now()
  where order_id = p_order_id;

  return jsonb_build_object('ok', true, 'plan', payment_row.plan, 'expires_at', next_expiry);
end;
$$;

revoke all on function public.activate_cashfree_order(text,text) from public, anon, authenticated;
grant execute on function public.activate_cashfree_order(text,text) to service_role;
