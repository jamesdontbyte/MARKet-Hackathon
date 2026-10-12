import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

Future<void> initSupabase() async {
  if (supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseUrl != 'YOUR_SUPABASE_URL') {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
    );
  }
}

SupabaseClient? _fallbackClient;

SupabaseClient get supabase {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return _fallbackClient ??= SupabaseClient(
      'https://mock.supabase.co',
      'mock-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }
}
