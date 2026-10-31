create or replace function public.award_xp_for_pyq_attempt() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.xp_events(user_id,source_type,source_id,points) values(new.user_id,'pyq',new.question_id,2) on conflict(user_id,source_type,source_id) do nothing; return new; end; $$;
revoke all on function public.award_xp_for_pyq_attempt() from public, anon, authenticated;
drop trigger if exists pyq_attempt_award_xp on public.pyq_attempts;
create trigger pyq_attempt_award_xp after insert on public.pyq_attempts for each row execute function public.award_xp_for_pyq_attempt();
