import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/env.dart';
import '../core/supabase.dart';
import '../models/profile.dart';
import 'geofence_service.dart';

/// AuthService handles user authentication, session streaming,
/// profile management, and one-tap demo logins.
class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client}) : _client = client ?? supabase;

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => _client.auth.currentUser?.id;
  bool get isAuthenticated => _client.auth.currentUser != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up a new Shopper user and create their profile row
  Future<AuthResponse> signUpShopper({
    required String email,
    required String password,
    String? fullName,
    String? phone,
    List<String> interests = const [],
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'role': 'shopper',
        if (fullName != null) 'full_name': fullName.trim(),
        if (phone != null) 'phone': phone.trim(),
      },
    );

    final user = response.user;
    if (user != null) {
      await _client.from('profiles').upsert({
        'id': user.id,
        'role': 'shopper',
        'full_name': fullName?.trim(),
        'phone': phone?.trim(),
        'interests': interests,
      });
    }

    return response;
  }

  /// Sign up a new Merchant user and create their profile row
  Future<AuthResponse> signUpMerchant({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'role': 'merchant',
        if (fullName != null) 'full_name': fullName.trim(),
        if (phone != null) 'phone': phone.trim(),
      },
    );

    final user = response.user;
    if (user != null) {
      await _client.from('profiles').upsert({
        'id': user.id,
        'role': 'merchant',
        'full_name': fullName?.trim(),
        'phone': phone?.trim(),
      });
    }

    return response;
  }

  /// Standard email & password sign-in
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// One-tap demo shortcut for Shopper login
  Future<AuthResponse> signInDemoShopper() async {
    return await signInWithEmail(
      email: demoShopperEmail,
      password: demoShopperPassword,
    );
  }

  /// One-tap demo shortcut for Merchant login (Kape Tahanan)
  Future<AuthResponse> signInDemoMerchant() async {
    return await signInWithEmail(
      email: demoMerchantEmail,
      password: demoMerchantPassword,
    );
  }

  /// Fetch the profile of the currently logged-in user
  Future<Profile?> fetchCurrentProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  /// Update the current profile (e.g. interest chips, phone, full name)
  Future<Profile> updateProfile(Profile profile) async {
    final data = await _client
        .from('profiles')
        .update(profile.toJson())
        .eq('id', profile.id)
        .select()
        .single();

    return Profile.fromJson(data);
  }

  /// Update shopper's interest slugs
  Future<void> updateInterests(List<String> interests) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _client.from('profiles').update({
      'interests': interests,
    }).eq('id', uid);
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await GeofenceService.instance.stop();
    } catch (_) {}
    await _client.auth.signOut();
  }
}
