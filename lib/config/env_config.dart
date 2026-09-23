class EnvConfig {
  // Satu-satunya project Supabase aplikasi: pnlxugnwevvepagzdxkr.
  // Publishable key aman di client (otorisasi via RLS). Jangan taruh
  // service_role/secret di sini.
  static const String supabaseUrl = 'https://pnlxugnwevvepagzdxkr.supabase.co';
  static const String supabasePublishableKey = 'sb_publishable_qSDLScLssG4t6Fxz5kRwoQ_BVsQEViR';

  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '5265f904-6f40-41db-acf7-b7c07558dd7d',
  );
}
