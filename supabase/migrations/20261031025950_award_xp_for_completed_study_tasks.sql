create or replace function public.award_xp_for_study_task() returns trigger language plpgsql security definer set search_path=public as $$ begin if new.status = 'completed' then insert into public.xp_events(user_id,source_type,source_id,points) values(new.user_id,'study_task',new.id,10) on conflict(user_id,source_type,source_id) do nothing; end if; return new; end; $$;
revoke all on function public.award_xp_for_study_task() from public, anon, authenticated;
drop trigger if exists study_task_award_xp on public.study_tasks;
create trigger study_task_award_xp after insert or update of status on public.study_tasks for each row execute function public.award_xp_for_study_task();
