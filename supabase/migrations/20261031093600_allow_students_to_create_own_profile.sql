grant insert on public.profiles to authenticated;
drop policy if exists "own profile insert" on public.profiles;
create policy "own profile insert" on public.profiles
for insert to authenticated
with check ((select auth.uid()) = id);
