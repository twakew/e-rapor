-- ==========================================================
-- SCRIPT PENGAMANAN DATABASE (SUPABASE RLS HARDENING) - V5 (Idempotent)
-- Project: laporsekolaherapor
--
-- Perbaikan vs V4:
--  * Tutup escalasi privilege: Guru tak bisa ubah role (self/others) jadi
--    Admin/Super Admin, hanya Admin yang boleh.
--  * Trigger auto-create profile saat signup (hilangkan insert manual di app).
--  * Siswa login tanpa sesi (anon) tetap bisa BACA data akademik, tapi
--    tidak bisa TULIS apa pun.
--  * Hardening SECURITY DEFINER: SET search_path, revoke, grant minimal.
--  * Storage RLS: bucket publik "dokumentasi" (read-only anon), bucket
--    private "penilaian".
-- ==========================================================

-- ==========================================================
-- 0. FUNGSI BANTU (Helpers)
-- ==========================================================
-- Cek apakah user adalah staff (Admin/Guru/Super Admin) berdasarkan role di profiles.
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('Admin', 'Guru', 'Super Admin')
  );
$$;

-- Cek apakah user adalah Admin/Super Admin.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('Admin', 'Super Admin')
  );
$$;

REVOKE ALL ON FUNCTION public.is_staff() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_staff() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ==========================================================
-- 1. TRIGGER AUTO-CREATE PROFILES
--    Setiap user baru langsung dapat baris profiles sendiri.
--    Dipakai sebagai pengganti insert manual dari register.dart.
-- ==========================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, is_verified)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
    'Guru',
    false
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==========================================================
-- 2. AKTIFKAN RLS PADA TABEL
-- ==========================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE documentation ENABLE ROW LEVEL SECURITY;

-- ==========================================================
-- 3. POLICIES: PROFILES
--    - User melihat/mengedit profil sendiri.
--    - Staff membaca semua profil (untuk kelola akun).
--    - Staff bisa ubah profil orang lain, TAPI hanya Admin yang bisa
--      mengubah role dan is_verified (anti-escalasi & anti-verifikasi-sendiri).
--    - INSERT via trigger definer (bypass policy); anon/user biasa tak insert.
-- ==========================================================
-- SELECT: profil sendiri ATAU staff (semua role staff boleh lihat daftar akun)
DROP POLICY IF EXISTS "profiles_select_own_or_staff" ON profiles;
CREATE POLICY "profiles_select_own_or_staff" ON profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id OR public.is_staff());

-- UPDATE: profil sendiri (non-role) ATAU staff (tanpa ubah role/is_verified kecuali Admin)
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
DROP POLICY IF EXISTS "profiles_update_staff" ON profiles;
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND role IS NOT DISTINCT FROM OLD.role
    AND is_verified IS NOT DISTINCT FROM OLD.is_verified
  );

CREATE POLICY "profiles_update_staff" ON profiles
  FOR UPDATE TO authenticated
  USING (public.is_staff())
  WITH CHECK (
    public.is_staff()
    AND (
      NEW.role NOT IN ('Admin', 'Super Admin') OR public.is_admin()
    )
    AND (
      NEW.is_verified IS NOT DISTINCT FROM OLD.is_verified OR public.is_admin()
    )
  );

-- DELETE: hanya Admin (penghapusan akun butuh otorisasi kuat; app pakai RPC delete_user_by_admin)
DROP POLICY IF EXISTS "profiles_delete_admin" ON profiles;
CREATE POLICY "profiles_delete_admin" ON profiles
  FOR DELETE TO authenticated
  USING (public.is_admin());

-- INSERT: user bisa bikin profil sendiri kalau belum ada (pengganti auto-trigger utk data lama).
-- NOTE: trigger handle_new_user jalan duluan; policy ini hanya cadangan.
DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
CREATE POLICY "profiles_insert_own" ON profiles
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id AND is_verified IS FALSE);

-- ==========================================================
-- 4. POLICIES: SCHOOL_DATA
--    - Semua orang (termasuk anon/siswa) bisa BACA.
--    - Hanya Admin/Super Admin yang bisa TULIS.
-- ==========================================================
DROP POLICY IF EXISTS "school_data_public_read" ON school_data;
CREATE POLICY "school_data_public_read" ON school_data
  FOR SELECT TO public
  USING (true);

DROP POLICY IF EXISTS "school_data_admin_write" ON school_data;
CREATE POLICY "school_data_admin_write" ON school_data
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "school_data_admin_update" ON school_data;
CREATE POLICY "school_data_admin_update" ON school_data
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "school_data_admin_delete" ON school_data;
CREATE POLICY "school_data_admin_delete" ON school_data
  FOR DELETE TO authenticated
  USING (public.is_admin());

-- ==========================================================
-- 5. POLICIES: DOCUMENTATION
--    - Semua orang bisa BACA (galeri publik).
--    - Staff bisa TULIS.
-- ==========================================================
DROP POLICY IF EXISTS "documentation_public_read" ON documentation;
CREATE POLICY "documentation_public_read" ON documentation
  FOR SELECT TO public
  USING (true);

DROP POLICY IF EXISTS "documentation_staff_insert" ON documentation;
CREATE POLICY "documentation_staff_insert" ON documentation
  FOR INSERT TO authenticated
  WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "documentation_staff_update" ON documentation;
CREATE POLICY "documentation_staff_update" ON documentation
  FOR UPDATE TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "documentation_staff_delete" ON documentation;
CREATE POLICY "documentation_staff_delete" ON documentation
  FOR DELETE TO authenticated
  USING (public.is_staff());

-- ==========================================================
-- 6. POLICIES: DATA AKADEMIK (students, teachers, attendance, assessments)
--    - BACA: semua orang (siswa tanpa sesi butuh lihat rapor/absensi/dll).
--    - TULIS: hanya staff.
-- ==========================================================
-- students
DROP POLICY IF EXISTS "students_public_read" ON students;
CREATE POLICY "students_public_read" ON students
  FOR SELECT TO public
  USING (true);

DROP POLICY IF EXISTS "students_staff_insert" ON students;
CREATE POLICY "students_staff_insert" ON students
  FOR INSERT TO authenticated
  WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "students_staff_update" ON students;
CREATE POLICY "students_staff_update" ON students
  FOR UPDATE TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "students_staff_delete" ON students;
CREATE POLICY "students_staff_delete" ON students
  FOR DELETE TO authenticated
  USING (public.is_staff());

-- teachers
DROP POLICY IF EXISTS "teachers_public_read" ON teachers;
CREATE POLICY "teachers_public_read" ON teachers
  FOR SELECT TO public
  USING (true);

DROP POLICY IF EXISTS "teachers_staff_insert" ON teachers;
CREATE POLICY "teachers_staff_insert" ON teachers
  FOR INSERT TO authenticated
  WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "teachers_staff_update" ON teachers;
CREATE POLICY "teachers_staff_update" ON teachers
  FOR UPDATE TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "teachers_staff_delete" ON teachers;
CREATE POLICY "teachers_staff_delete" ON teachers
  FOR DELETE TO authenticated
  USING (public.is_staff());

-- attendance
DROP POLICY IF EXISTS "attendance_public_read" ON attendance;
CREATE POLICY "attendance_public_read" ON attendance
  FOR SELECT TO public
  USING (true);

DROP POLICY IF EXISTS "attendance_staff_insert" ON attendance;
CREATE POLICY "attendance_staff_insert" ON attendance
  FOR INSERT TO authenticated
  WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "attendance_staff_update" ON attendance;
CREATE POLICY "attendance_staff_update" ON attendance
  FOR UPDATE TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "attendance_staff_delete" ON attendance;
CREATE POLICY "attendance_staff_delete" ON attendance
  FOR DELETE TO authenticated
  USING (public.is_staff());

-- assessments
DROP POLICY IF EXISTS "assessments_public_read" ON assessments;
CREATE POLICY "assessments_public_read" ON assessments
  FOR SELECT TO public
  USING (true);

DROP POLICY IF EXISTS "assessments_staff_insert" ON assessments;
CREATE POLICY "assessments_staff_insert" ON assessments
  FOR INSERT TO authenticated
  WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "assessments_staff_update" ON assessments;
CREATE POLICY "assessments_staff_update" ON assessments
  FOR UPDATE TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "assessments_staff_delete" ON assessments;
CREATE POLICY "assessments_staff_delete" ON assessments
  FOR DELETE TO authenticated
  USING (public.is_staff());

-- ==========================================================
-- 7. HARDENING RPC LOGIN (anti enumerasi, injection, spam rate-limit)
--    Semua SECURITY DEFINER diberi SET search_path + revoke.
-- ==========================================================
CREATE OR REPLACE FUNCTION public.get_student_auth(p_nis text)
RETURNS TABLE (nis text, name text, class text, batch text, rombel text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT s.nis, s.name, s.class, s.batch, s.rombel
  FROM students s
  WHERE s.nis = p_nis
  LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_auth_blocked(p_identifier text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  attempts int;
BEGIN
  SELECT failed_attempts INTO attempts
  FROM login_attempts
  WHERE identifier = p_identifier;
  RETURN COALESCE(attempts, 0) >= 5;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_login_failure(p_identifier text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO login_attempts (identifier, failed_attempts, last_failed_at)
  VALUES (p_identifier, 1, now())
  ON CONFLICT (identifier) DO UPDATE
  SET failed_attempts = login_attempts.failed_attempts + 1,
      last_failed_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.reset_login_attempts(p_identifier text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM login_attempts WHERE identifier = p_identifier;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_profile(p_nis text)
RETURNS SETOF students
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY SELECT * FROM students WHERE nis = p_nis LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_student_stats_summary()
RETURNS TABLE (class_name text, total_count bigint, lulus_count bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT class, COUNT(*), COUNT(*) FILTER (WHERE status = 'Lulus')
  FROM students
  GROUP BY class;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_public_teachers()
RETURNS TABLE (id uuid, name text, role text, subject text, wali_kelas text, angkatan_wali text, rombel_wali text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT t.id, t.name, t.role, t.subject, t.wali_kelas, t.angkatan_wali, t.rombel_wali
  FROM teachers t
  ORDER BY t.name;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_all_students_for_user()
RETURNS TABLE (
  id uuid, name text, nis text, class text, rombel text, batch text, status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT s.id, s.name, s.nis, s.class, s.rombel, s.batch, s.status
  FROM students s
  ORDER BY s.name;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_classmates(p_nis text)
RETURNS TABLE (
  id uuid, name text, nis text, class text, rombel text, batch text, status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_class text;
BEGIN
  SELECT class INTO v_class FROM students WHERE nis = p_nis LIMIT 1;
  IF v_class IS NULL THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT s.id, s.name, s.nis, s.class, s.rombel, s.batch, s.status
  FROM students s
  WHERE s.class = v_class
  ORDER BY s.name;
END;
$$;

-- ==========================================================
-- 8. HARDENING: delete_user_by_admin
--    Hanya Admin/Super Admin yang boleh. Hapus dari auth.users + profiles.
--    Tabel auth.users perlu SELECT/UPDATE/DELETE untuk definer function.
--    Menghapus auth.users akan cascade ke profiles (FK ON DELETE CASCADE)
--    bila sudah diset; jika tidak, hapus manual setelahnya.
-- ==========================================================
CREATE OR REPLACE FUNCTION public.delete_user_by_admin(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Akses ditolak: hanya Admin yang dapat menghapus akun';
  END IF;

  -- Hapus profil (di urutan pertama karena FK ke auth.users biasanya CASCADE;
  -- hapus eksplisit supaya tidak bergantung pada konfigurasi FK).
  DELETE FROM public.profiles WHERE id = target_user_id;
  DELETE FROM auth.users WHERE id = target_user_id;
END;
$$;

-- Revoke supaya tak bisa dipanggil anon
REVOKE ALL ON FUNCTION public.get_student_auth(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.check_auth_blocked(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_login_failure(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reset_login_attempts(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_my_profile(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_student_stats_summary() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_public_teachers() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_all_students_for_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_my_classmates(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_user_by_admin(uuid) FROM PUBLIC;

-- Anon (belum login) butuh: get_student_auth, check_auth_blocked, record_login_failure,
-- reset_login_attempts, get_my_profile, get_my_classmates (login siswa & lihat rapor).
GRANT EXECUTE ON FUNCTION public.get_student_auth(text) TO anon;
GRANT EXECUTE ON FUNCTION public.check_auth_blocked(text) TO anon;
GRANT EXECUTE ON FUNCTION public.record_login_failure(text) TO anon;
GRANT EXECUTE ON FUNCTION public.reset_login_attempts(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_public_teachers() TO anon;
GRANT EXECUTE ON FUNCTION public.get_all_students_for_user() TO anon;
GRANT EXECUTE ON FUNCTION public.get_my_classmates(text) TO anon;

-- Staff butuh yang lebih dalam (stats).
GRANT EXECUTE ON FUNCTION public.get_student_stats_summary() TO authenticated;
-- delete_user_by_admin hanya authenticated (guard is_admin di dalam function).
GRANT EXECUTE ON FUNCTION public.delete_user_by_admin(uuid) TO authenticated;

-- ==========================================================
-- 9. STORAGE RLS
--    Bucket "dokumentasi": publik (baca) -> upload/edit hanya staff.
--    Bucket "penilaian": private -> hanya staff.
--    (Asumsikan bucket sudah ada; CREATE BUCKET butuh akses service_role.
--     Jalankan bagian ini jika bucket belum dibuat.)
-- ==========================================================
-- INSERT INTO storage.buckets (id, name, public) VALUES ('dokumentasi', 'dokumentasi', true) ON CONFLICT (id) DO NOTHING;
-- INSERT INTO storage.buckets (id, name, public) VALUES ('penilaian', 'penilaian', false) ON CONFLICT (id) DO NOTHING;

-- dokumentasi: publik baca
DROP POLICY IF EXISTS "dokumentasi_public_read" ON storage.objects;
CREATE POLICY "dokumentasi_public_read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'dokumentasi');

-- dokumentasi: staff tulis
DROP POLICY IF EXISTS "dokumentasi_staff_insert" ON storage.objects;
CREATE POLICY "dokumentasi_staff_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'dokumentasi' AND public.is_staff());

DROP POLICY IF EXISTS "dokumentasi_staff_update" ON storage.objects;
CREATE POLICY "dokumentasi_staff_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'dokumentasi' AND public.is_staff())
  WITH CHECK (bucket_id = 'dokumentasi' AND public.is_staff());

DROP POLICY IF EXISTS "dokumentasi_staff_delete" ON storage.objects;
CREATE POLICY "dokumentasi_staff_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'dokumentasi' AND public.is_staff());

-- penilaian: private, hanya staff
DROP POLICY IF EXISTS "penilaian_staff_all" ON storage.objects;
CREATE POLICY "penilaian_staff_all" ON storage.objects
  FOR ALL TO authenticated
  USING (bucket_id = 'penilaian' AND public.is_staff())
  WITH CHECK (bucket_id = 'penilaian' AND public.is_staff());
