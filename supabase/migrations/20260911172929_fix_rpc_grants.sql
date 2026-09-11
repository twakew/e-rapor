-- Cabut EXECUTE anon berlebih (advisors WARN): anon hanya utk pre-login + RPC
-- scoped exact-NIS. delete/stats/verify: authenticated saja (guard di body).
REVOKE ALL ON FUNCTION public.delete_user_by_admin(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.get_student_stats_summary() FROM anon;
REVOKE ALL ON FUNCTION public.verify_user_by_admin(uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM anon, authenticated;
REVOKE ALL ON FUNCTION public.is_staff() FROM anon;
REVOKE ALL ON FUNCTION public.is_admin() FROM anon;
