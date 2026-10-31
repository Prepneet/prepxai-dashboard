-- The dashboard now uses the exam-scoped leaderboard RPC.
-- Keep the legacy global leaderboard RPC available only to trusted server-side callers.
revoke all on function public.weekly_top_students() from public, anon, authenticated;
grant execute on function public.weekly_top_students() to service_role;
