-- Restore the atomic daily doubt counter RPCs used by /api/doubt.
-- These functions are callable only by the server-side service_role.

create or replace function public.consume_doubt(uid uuid, lim integer)
returns boolean
language plpgsql
set search_path = public
as $$
declare
  updated_used integer;
begin
  if uid is null or lim is null or lim < 1 then
    return false;
  end if;

  insert into public.doubt_usage (user_id, day, used)
  values (uid, current_date, 0)
  on conflict (user_id, day) do nothing;

  update public.doubt_usage
     set used = used + 1
   where user_id = uid
     and day = current_date
     and used < lim
  returning used into updated_used;

  return updated_used is not null;
end;
$$;

create or replace function public.refund_doubt(uid uuid)
returns void
language sql
set search_path = public
as $$
  update public.doubt_usage
     set used = greatest(used - 1, 0)
   where user_id = uid
     and day = current_date
     and used > 0;
$$;

alter table public.doubt_usage enable row level security;
grant usage on schema public to service_role;
grant select, insert, update on public.doubt_usage to service_role;

revoke all on function public.consume_doubt(uuid, integer) from public, anon, authenticated;
revoke all on function public.refund_doubt(uuid) from public, anon, authenticated;
grant execute on function public.consume_doubt(uuid, integer) to service_role;
grant execute on function public.refund_doubt(uuid) to service_role;
