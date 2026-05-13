class CloudSyncConfig {
  const CloudSyncConfig({required this.url, required this.anonKey});

  factory CloudSyncConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return const CloudSyncConfig(url: url, anonKey: anonKey);
  }

  final String url;
  final String anonKey;

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
