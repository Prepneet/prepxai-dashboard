-- Keep signup metadata aligned with the dashboard profile fields, and make XP / leaderboard behavior consistent.
-- Applied to production on 2026-10-31; this migration records the deployed database changes.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  nm text;
  lang text;
  exam_key text;
  target_year_value text;
begin
  nm := coalesce(
    nullif(trim(new.raw_user_meta_data->>'name'), ''),
    nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
    'Student'
  );
  if char_length(nm) < 2 then nm := 'Student'; end if;
  nm := left(nm, 80);

  lang := coalesce(nullif(new.raw_user_meta_data->>'language',''),'en');
  exam_key := nullif(new.raw_user_meta_data->>'target_exam','');
  target_year_value := nullif(new.raw_user_meta_data->>'target_year','');

  insert into public.profiles (
    id,name,email,phone,student_status,target_exam,target_year,exam_date,
    stage,weakness,daily_hours,language,preferred_language,attempt_year,
    selected_exams,target_exams
  )
  values (
    new.id,nm,coalesce(new.email,''),nullif(new.raw_user_meta_data->>'phone',''),
    nullif(new.raw_user_meta_data->>'student_status',''),exam_key,target_year_value,
    nullif(new.raw_user_meta_data->>'exam_date','')::date,
    new.raw_user_meta_data->>'stage',new.raw_user_meta_data->>'weakness',
    new.raw_user_meta_data->>'daily_hours',lang,lang,
    case when target_year_value ~ '^[0-9]{4}$' then target_year_value::integer else null end,
    case when exam_key is null then '{}'::text[] else array[exam_key] end,
    case when exam_key is null then '{}'::text[] else array[exam_key] end
  )
  on conflict (id) do nothing;
  return new;
end
$function$;

update public.profiles
set preferred_language = language
where preferred_language is null and language is not null;

update public.profiles
set attempt_year = target_year::integer
where attempt_year is null and target_year ~ '^[0-9]{4}$';

create or replace function public.award_xp_for_study_task()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
begin
  if new.status = 'completed' then
    insert into public.xp_events(user_id,source_type,source_id,points)
    values(new.user_id,'study_task',new.id,10)
    on conflict(user_id,source_type,source_id) do nothing;
  end if;
  return new;
end;
$function$;

create or replace function public.award_xp_for_mock_attempt()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
begin
  if old.submitted_at is null and new.submitted_at is not null
     and (coalesce(new.correct,0)+coalesce(new.incorrect,0)) > 0 then
    insert into public.xp_events(user_id,source_type,source_id,points)
    values(new.user_id,'mock_test',new.id,25)
    on conflict(user_id,source_type,source_id) do nothing;
  end if;
  return new;
end;
$function$;

create or replace function public.weekly_top_students_for_exam(exam_key text)
returns table(rank bigint, display_name text, target_exam text, xp integer)
language sql
stable
security definer
set search_path = public
as $function$
  select
    row_number() over(order by sum(x.points) desc, min(x.created_at) asc) as rank,
    coalesce(nullif(p.name,''),'Student') as display_name,
    p.target_exam,
    sum(x.points)::integer as xp
  from public.xp_events x
  join public.profiles p on p.id=x.user_id
  where x.created_at >= date_trunc('week',now())
    and x.created_at < date_trunc('week',now()) + interval '7 days'
    and lower(case lower(coalesce(p.target_exam,''))
      when 'neet' then 'neet ug' when 'neet-ug' then 'neet ug'
      when 'jee' then 'jee main' when 'jee-main' then 'jee main' when 'jee mains' then 'jee main' when 'jeem' then 'jee main'
      when 'jee advanced' then 'jee advanced' when 'jee-advanced' then 'jee advanced' when 'jeea' then 'jee advanced'
      when 'upsc' then 'upsc cse' when 'upsc-cse' then 'upsc cse' when 'ias' then 'upsc cse'
      when 'cuet' then 'cuet ug' when 'cuet-ug' then 'cuet ug'
      when 'ssc' then 'ssc exams' when 'ssc-cgl' then 'ssc exams' when 'ssc cgl' then 'ssc exams'
      when 'rrb' then 'railways (rrb)' when 'rrb-ntpc' then 'railways (rrb)' when 'railways' then 'railways (rrb)' when 'railway' then 'railways (rrb)' when 'ntpc' then 'railways (rrb)'
      when 'bihar-police' then 'bihar police'
      when 'bpsc' then 'bpsc'
      when 'nda-cds' then 'nda' when 'nda / cds' then 'nda'
      when 'ibps-sbi-banking' then 'banking exams' when 'banking' then 'banking exams' when 'ibps' then 'banking exams' when 'sbi' then 'banking exams' when 'bank' then 'banking exams'
      else coalesce(p.target_exam,'')
    end) = lower(coalesce(exam_key,''))
  group by p.id,p.name,p.target_exam
  order by sum(x.points) desc, min(x.created_at) asc
  limit 20
$function$;

revoke all on function public.weekly_top_students_for_exam(text) from public, anon;
grant execute on function public.weekly_top_students_for_exam(text) to authenticated, service_role;
