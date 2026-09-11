class EnvConfig {
  // DB baru: pnlxugnwevvepagzdxkr ("terbaru").
  // Publishable key aman di client (otorisasi via RLS). JANGAN taruh
  // service_role/secret di sini. Lebih baik inject via --dart-define.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pnlxugnwevvepagzdxkr.supabase.co',
  );
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue:
        'sb_publishable_qSDLScLssG4t6Fxz5kRwoQ_BVsQEViR',
  );

  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '5265f904-6f40-41db-acf7-b7c07558dd7d',
  );
}
