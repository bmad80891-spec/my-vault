
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  static const _url = String.fromEnvironment('SUPABASE_URL');

  static const _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured =>
      _url.isNotEmpty && _publishableKey.isNotEmpty;

  static Future<bool> initializeIfConfigured() async {
    if (!isConfigured) return false;

    await Supabase.initialize(
      url: _url,
      publishableKey: _publishableKey,
    );

    return true;
  }
}
