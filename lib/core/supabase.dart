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

SupabaseClient get supabase => Supabase.instance.client;
