-- Seed demo minimal: 1 sekolah, 2 kelas, 2 guru, 2 siswa + absensi + nilai.
-- Idempotent: ON CONFLICT DO NOTHING utk nis; guard NOT EXISTS utk sisanya.

INSERT INTO public.school_data
  (name, npsn, accreditation, curriculum, headmaster_name, headmaster_nip, email, phone, address)
SELECT 'TK Pelita Bangsa', '12345678', 'A', 'Merdeka',
  'Siti Rahayu', '196501011990032001',
  'info@tkpelita.sch.id', '081234567890', 'Jl. Pendidikan No. 1'
WHERE NOT EXISTS (SELECT 1 FROM public.school_data);

INSERT INTO public.classes (name, rombel, batch)
SELECT 'TKA', 'A', '2024'
WHERE NOT EXISTS (SELECT 1 FROM public.classes WHERE name = 'TKA' AND rombel = 'A');
INSERT INTO public.classes (name, rombel, batch)
SELECT 'TKB', 'A', '2024'
WHERE NOT EXISTS (SELECT 1 FROM public.classes WHERE name = 'TKB' AND rombel = 'A');

INSERT INTO public.teachers
  (name, nip, gender, role, subject, wali_kelas, rombel_wali, angkatan_wali, status)
SELECT 'Siti Rahayu', '196501011990032001', 'Perempuan',
  'Wali Kelas', 'Tematik', 'TKA', 'A', '2024', 'Aktif'
WHERE NOT EXISTS (SELECT 1 FROM public.teachers WHERE nip = '196501011990032001');
INSERT INTO public.teachers (name, nip, gender, role, subject, status)
SELECT 'Budi Hartono', '197803152005011002', 'Laki-laki',
  'Guru Mapel', 'Agama', 'Aktif'
WHERE NOT EXISTS (SELECT 1 FROM public.teachers WHERE nip = '197803152005011002');

INSERT INTO public.students
  (id, nis, name, gender, class, rombel, batch, curriculum, status,
   father_name, mother_name, parent_phone)
VALUES
  ('11111111-1111-1111-1111-111111111111', '1001', 'Ahmad Fauzi', 'Laki-laki',
   'TKA', 'A', '2024', 'Merdeka', 'Aktif',
   'Joko Susilo', 'Dewi Lestari', '081111111111'),
  ('22222222-2222-2222-2222-222222222222', '1002', 'Aisyah Putri', 'Perempuan',
   'TKA', 'A', '2024', 'Merdeka', 'Aktif',
   'Agus Wijaya', 'Rina Marlina', '082222222222')
ON CONFLICT (nis) DO NOTHING;

INSERT INTO public.attendance (student_id, date, status)
SELECT '11111111-1111-1111-1111-111111111111', CURRENT_DATE, 'Hadir'
WHERE NOT EXISTS (
  SELECT 1 FROM public.attendance
  WHERE student_id = '11111111-1111-1111-1111-111111111111' AND date = CURRENT_DATE);
INSERT INTO public.attendance (student_id, date, status)
SELECT '22222222-2222-2222-2222-222222222222', CURRENT_DATE, 'Sakit'
WHERE NOT EXISTS (
  SELECT 1 FROM public.attendance
  WHERE student_id = '22222222-2222-2222-2222-222222222222' AND date = CURRENT_DATE);

INSERT INTO public.assessments
  (student_id, category, score, notes, material, semester, report_date, is_published)
SELECT '11111111-1111-1111-1111-111111111111', c.category, 'Berkembang Baik',
  'Anak menunjukkan perkembangan baik pada ' || c.category,
  'Materi semester 1', 1, now(), true
FROM (VALUES
  ('Nilai Agama dan Budi Pekerti'),
  ('Jati Diri'),
  ('Dasar Literasi, Sains, Teknologi, Rekayasa, & Seni')
) AS c(category)
WHERE NOT EXISTS (
  SELECT 1 FROM public.assessments a
  WHERE a.student_id = '11111111-1111-1111-1111-111111111111'
    AND a.category = c.category AND a.semester = 1);

INSERT INTO public.documentation (title, description)
SELECT 'Kegiatan Belajar Semester 1', 'Dokumentasi kegiatan belajar mengajar semester 1'
WHERE NOT EXISTS (SELECT 1 FROM public.documentation);
