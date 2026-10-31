-- Evaluate auth/staff helper calls once per statement for the high-traffic dashboard policies.
alter policy "own feedback insert" on public.feedback_submissions
  with check ((select auth.uid()) = user_id);
alter policy "own feedback read" on public.feedback_submissions
  using ((select auth.uid()) = user_id);

alter policy "own mock attempts select" on public.mock_attempts
  using ((select auth.uid()) = user_id);
alter policy "staff read student mock attempts" on public.mock_attempts
  using ((select has_staff_role(array['owner'::text,'super_admin'::text,'academic'::text])));

alter policy "own bookmarks all" on public.note_bookmarks
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

alter policy "own profile read" on public.profiles
  using ((id = (select auth.uid())) or (select is_staff()));
alter policy "own profile update" on public.profiles
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
alter policy "staff update profiles" on public.profiles
  using ((select is_staff()))
  with check ((select is_staff()));

alter policy "students insert own syllabus progress" on public.student_syllabus_progress
  with check ((select auth.uid()) = user_id);
alter policy "students read own syllabus progress" on public.student_syllabus_progress
  using ((select auth.uid()) = user_id);
alter policy "students update own syllabus progress" on public.student_syllabus_progress
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "staff read student syllabus progress" on public.student_syllabus_progress
  using ((select is_staff()));

alter policy "own tasks delete" on public.study_tasks
  using ((select auth.uid()) = user_id);
alter policy "own tasks insert" on public.study_tasks
  with check ((select auth.uid()) = user_id);
alter policy "own tasks select" on public.study_tasks
  using ((select auth.uid()) = user_id);
alter policy "own tasks update" on public.study_tasks
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "staff read student study tasks" on public.study_tasks
  using ((select has_staff_role(array['owner'::text,'super_admin'::text,'academic'::text])));

alter policy "own checklist all" on public.revision_checklist
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

alter policy "students read own pyq attempts" on public.pyq_attempts
  using ((select auth.uid()) = user_id);
alter policy "staff read student pyq attempts" on public.pyq_attempts
  using ((select has_staff_role(array['owner'::text,'super_admin'::text,'academic'::text])));

alter policy "students read own xp" on public.xp_events
  using ((select auth.uid()) = user_id);
alter policy "staff read xp" on public.xp_events
  using ((select has_staff_role(array['owner'::text,'super_admin'::text,'academic'::text])));
