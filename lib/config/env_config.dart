class EnvConfig {
  // --- KEAMANAN PENTING ---
  // Pastikan Row Level Security (RLS) diaktifkan di Dashboard Supabase.
  // Anon Key ini aman dipublikasikan HANYA JIKA RLS sudah dikonfigurasi dengan benar.
  static const String supabaseUrl = 'https://yfqocjqrwyrgapspnarp.supabase.co';
  static const String supabasePublishableKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlmcW9janFyd3lyZ2Fwc3BuYXJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyMzI0NzYsImV4cCI6MjA5MjgwODQ3Nn0.MnkRpj2p0Jfzv78pD_DKcazjIT28hSKMgNJy8-qe2cI';
  
  static const String oneSignalAppId = '5265f904-6f40-41db-acf7-b7c07558dd7d';
}
