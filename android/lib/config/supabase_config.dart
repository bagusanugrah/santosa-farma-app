class SupabaseConfig {
  static const String url = 'https://nykoitxkyyhwvtrndyrb.supabase.co';
  static const String publishableKey = 'sb_publishable_c2EG8EOdDmUiPDZkd1ymXg_nW5DIP-M';
  static const String productsBucket = 'products';

  static String getProductImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final cleanPath = path.replaceFirst(RegExp(r'^products/'), '').replaceFirst(RegExp(r'^/'), '');
    return '$url/storage/v1/object/public/$productsBucket/$cleanPath';
  }
}
