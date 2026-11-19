class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String productsBucket = String.fromEnvironment(
    'SUPABASE_PRODUCTS_BUCKET',
    defaultValue: 'products',
  );

  /// Memeriksa apakah kredensial Supabase sudah terisi saat build/run
  static bool get isConfigured =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;

  static String getProductImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final cleanPath = path.replaceFirst(RegExp(r'^products/'), '').replaceFirst(RegExp(r'^/'), '');
    return '$url/storage/v1/object/public/$productsBucket/$cleanPath';
  }
}
