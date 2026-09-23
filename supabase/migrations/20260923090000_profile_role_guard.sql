-- Guard: hanya admin yang boleh mengubah role / is_verified di profiles.
-- Menutup celah profiles_update_own yang mengizinkan user menaikkan
-- role dirinya sendiri (USING/WITH CHECK hanya cek auth.uid() = id).
-- Enforce HANYA saat ada identitas request (auth.uid() terisi, yaitu jalur
-- PostgREST/Supabase). Koneksi service langsung (backend Express, script
-- migrasi) tidak punya GUC identitas — dianggap trusted, lolos; jalur anon
-- tetap diblokir RLS (policy profiles_* TO authenticated) sebelum trigger ini.
CREATE OR REPLACE FUNCTION public.protect_profile_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role
     OR NEW.is_verified IS DISTINCT FROM OLD.is_verified THEN
    IF (SELECT auth.uid()) IS NOT NULL AND NOT public.is_admin() THEN
      RAISE EXCEPTION 'Hanya admin yang boleh mengubah role/verifikasi';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_profile_role ON public.profiles;
CREATE TRIGGER trg_protect_profile_role
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_profile_role();

REVOKE ALL ON FUNCTION public.protect_profile_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.protect_profile_role() TO authenticated;
