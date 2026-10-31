create or replace function public.award_xp_for_mock_attempt() returns trigger language plpgsql security definer set search_path=public as $$ begin if old.submitted_at is null and new.submitted_at is not null then insert into public.xp_events(user_id,source_type,source_id,points) values(new.user_id,'mock_test',new.id,25) on conflict(user_id,source_type,source_id) do nothing; end if; return new; end; $$;
revoke all on function public.award_xp_for_mock_attempt() from public, anon, authenticated;
drop trigger if exists mock_attempt_award_xp on public.mock_attempts;
create trigger mock_attempt_award_xp after update of submitted_at on public.mock_attempts for each row execute function public.award_xp_for_mock_attempt();
