import 'dart:math' as math;
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/supabase.dart';
import '../models/business.dart';
import '../models/merchant_analytics.dart';
import '../models/product.dart';
import '../models/promo.dart';
import '../models/redemption.dart';
import 'geofence_service.dart';

/// DataService handles database queries, mutations, atomic RPC redemption,
/// geofence event logging, and MSME analytics.
class DataService {
  final SupabaseClient _client;

  DataService({SupabaseClient? client}) : _client = client ?? supabase;

  // -------------------------------------------------------------
  // Businesses
  // -------------------------------------------------------------

  /// Fetch verified businesses (visible to shoppers)
  Future<List<Business>> fetchVerifiedBusinesses({String? category}) async {
    var query = _client.from('businesses').select().eq('verified', true);
    if (category != null && category != 'all') {
      query = query.eq('category', category);
    }
    final data = await query.order('name');
    return (data as List<dynamic>)
        .map((e) => Business.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single business by ID
  Future<Business?> fetchBusinessById(String businessId) async {
    final data = await _client
        .from('businesses')
        .select()
        .eq('id', businessId)
        .maybeSingle();

    if (data == null) return null;
    return Business.fromJson(data);
  }

  /// Fetch business owned by the authenticated merchant
  Future<Business?> fetchMerchantBusiness(String ownerId) async {
    final data = await _client
        .from('businesses')
        .select()
        .eq('owner_id', ownerId)
        .maybeSingle();

    if (data == null) return null;
    return Business.fromJson(data);
  }

  /// Create a new unverified business during merchant registration
  Future<Business> createBusiness(Business business) async {
    final data = await _client
        .from('businesses')
        .insert(business.toJson()..remove('id'))
        .select()
        .single();

    return Business.fromJson(data);
  }

  /// Update business details
  Future<Business> updateBusiness(Business business) async {
    final data = await _client
        .from('businesses')
        .update(business.toJson())
        .eq('id', business.id)
        .select()
        .single();

    return Business.fromJson(data);
  }

  // -------------------------------------------------------------
  // Products & Catalog
  // -------------------------------------------------------------

  /// Fetch products for a specific business
  Future<List<Product>> fetchProducts(String businessId) async {
    final data = await _client
        .from('products')
        .select()
        .eq('business_id', businessId)
        .order('name');

    return (data as List<dynamic>)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create product in merchant catalog
  Future<Product> createProduct(Product product) async {
    final data = await _client
        .from('products')
        .insert(product.toJson()..remove('id'))
        .select()
        .single();

    return Product.fromJson(data);
  }

  /// Delete product from catalog
  Future<void> deleteProduct(String productId) async {
    await _client.from('products').delete().eq('id', productId);
  }

  /// Update product in merchant catalog
  Future<Product> updateProduct(Product product) async {
    final data = await _client
        .from('products')
        .update(product.toJson()..remove('id'))
        .eq('id', product.id)
        .select()
        .single();

    return Product.fromJson(data);
  }

  // -------------------------------------------------------------
  // Promotions
  // -------------------------------------------------------------

  /// Fetch active promos matching optional interest category slugs
  Future<List<Promo>> fetchActivePromos({List<String>? interests}) async {
    final data = await _client
        .from('promos')
        .select('*, businesses!inner(category, verified)')
        .eq('active', true)
        .order('created_at', ascending: false);

    var promos = (data as List<dynamic>).map((e) {
      final map = Map<String, dynamic>.from(e as Map<String, dynamic>);
      return Promo.fromJson(map);
    }).where((p) => p.isCurrentlyValid).toList();

    if (interests != null && interests.isNotEmpty) {
      final filtered = (data as List<dynamic>).where((e) {
        final biz = e['businesses'] as Map<String, dynamic>?;
        final cat = biz?['category'] as String?;
        return cat != null && interests.contains(cat);
      }).map((e) => Promo.fromJson(e as Map<String, dynamic>)).toList();

      return filtered;
    }

    return promos;
  }

  /// Fetch promos for a specific business
  Future<List<Promo>> fetchPromosForBusiness(String businessId) async {
    final data = await _client
        .from('promos')
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map((e) => Promo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single promo by ID.
  Future<Promo?> fetchPromoById(String promoId) async {
    try {
      final data = await _client
          .from('promos')
          .select()
          .eq('id', promoId)
          .maybeSingle();

      if (data != null) {
        return Promo.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Create a new promo
  Future<Promo> createPromo(Promo promo) async {
    final data = await _client
        .from('promos')
        .insert(promo.toJson()..remove('id'))
        .select()
        .single();

    return Promo.fromJson(data);
  }

  /// Update promo in merchant catalog
  Future<Promo> updatePromo(Promo promo) async {
    final data = await _client
        .from('promos')
        .update(promo.toJson()..remove('id'))
        .eq('id', promo.id)
        .select()
        .single();

    return Promo.fromJson(data);
  }

  /// Delete promo from catalog
  Future<void> deletePromo(String promoId) async {
    await _client.from('promos').delete().eq('id', promoId);
  }

  // -------------------------------------------------------------
  // Stash
  // -------------------------------------------------------------

  /// Fetch promos saved to shopper's stash
  Future<List<Promo>> fetchStash(String userId) async {
    final data = await _client
        .from('stash')
        .select('promos(*)')
        .eq('user_id', userId)
        .order('saved_at', ascending: false);

    final list = <Promo>[];
    for (final item in data as List<dynamic>) {
      final promoData = item['promos'] as Map<String, dynamic>?;
      if (promoData != null) {
        list.add(Promo.fromJson(promoData));
      }
    }
    return list;
  }

  /// Check if a promo is already in shopper's stash
  Future<bool> isPromoInStash(String userId, String promoId) async {
    final data = await _client
        .from('stash')
        .select('id')
        .eq('user_id', userId)
        .eq('promo_id', promoId)
        .maybeSingle();

    return data != null;
  }

  /// Save promo to stash (writes only to stash table)
  Future<void> saveToStash(String userId, String promoId) async {
    await _client.from('stash').upsert({
      'user_id': userId,
      'promo_id': promoId,
    });
  }

  /// Remove promo from stash
  Future<void> removeFromStash(String userId, String promoId) async {
    await _client
        .from('stash')
        .delete()
        .eq('user_id', userId)
        .eq('promo_id', promoId);
  }

  // -------------------------------------------------------------
  // Redemptions & Vouchers
  // -------------------------------------------------------------

  /// Fetch all redemptions for a user
  Future<List<Redemption>> fetchUserRedemptions(String userId) async {
    final data = await _client
        .from('redemptions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map((e) => Redemption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Helper generating unique 8-character uppercase voucher code
  static String generateVoucherCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = math.Random();
    return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Opens voucher: returns existing redemption or creates a new one idempotently.
  /// Logs 'claimed' event in geofence_events only when a new voucher row is created.
  Future<Redemption> getOrCreateVoucher({
    required String userId,
    required String promoId,
    String? businessId,
  }) async {
    final existing = await _client
        .from('redemptions')
        .select()
        .eq('user_id', userId)
        .eq('promo_id', promoId)
        .maybeSingle();

    if (existing != null) {
      return Redemption.fromJson(existing);
    }

    final code = generateVoucherCode();
    final inserted = await _client
        .from('redemptions')
        .insert({
          'user_id': userId,
          'promo_id': promoId,
          'code': code,
          'status': 'issued',
        })
        .select()
        .single();

    // Log claimed event on first issue
    await logGeofenceEvent(
      eventType: 'claimed',
      userId: userId,
      promoId: promoId,
      businessId: businessId,
    );

    return Redemption.fromJson(inserted);
  }

  /// Atomic Merchant Redemption: calls rpc('redeem_voucher', params: {'p_code': code})
  /// Never updates tables directly.
  /// Status codes: ok | invalid | not_your_promo | already_redeemed | expired | limit_reached
  Future<String> redeemVoucher(String code) async {
    final cleanCode = code.toUpperCase().trim();
    final result = await _client.rpc(
      'redeem_voucher',
      params: {'p_code': cleanCode},
    );
    return (result ?? 'invalid').toString().trim();
  }

  // -------------------------------------------------------------
  // Geofence Events
  // -------------------------------------------------------------

  /// Log geofence interactions: ping_sent, opened, viewed, claimed, redeemed
  Future<void> logGeofenceEvent({
    required String eventType,
    String? userId,
    String? businessId,
    String? promoId,
  }) async {
    try {
      await _client.from('geofence_events').insert({
        'event_type': eventType,
        'user_id': ?userId,
        'business_id': ?businessId,
        'promo_id': ?promoId,
      });
    } catch (_) {
      // Non-blocking telemetry
    }
  }

  // -------------------------------------------------------------
  // Merchant Analytics
  // -------------------------------------------------------------

  /// Fetch 7-day conversion funnel counts for merchant dashboard
  Future<Map<String, int>> fetchMerchantAnalytics(String businessId) async {
    try {
      final sevenDaysAgo =
          DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String();

      final data = await _client
          .from('geofence_events')
          .select('event_type')
          .eq('business_id', businessId)
          .gte('created_at', sevenDaysAgo);

      final counts = <String, int>{
        'ping_sent': 0,
        'viewed': 0,
        'opened': 0,
        'claimed': 0,
        'redeemed': 0,
      };

      for (final row in data as List<dynamic>) {
        final type = row['event_type'] as String?;
        if (type != null && counts.containsKey(type)) {
          counts[type] = (counts[type] ?? 0) + 1;
        }
      }

      return counts;
    } catch (_) {
      return {
        'ping_sent': 0,
        'opened': 0,
        'viewed': 0,
        'claimed': 0,
        'redeemed': 0,
      };
    }
  }

  /// Fetch 7-day conversion funnel metrics with real counts from geofence_events.
  Future<MerchantAnalyticsData> fetchMerchantFunnel(String businessId) async {
    try {
      final sevenDaysAgo =
          DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String();

      final data = await _client
          .from('geofence_events')
          .select('event_type')
          .eq('business_id', businessId)
          .gte('created_at', sevenDaysAgo);

      int realPings = 0;
      int realOpened = 0;
      int realViews = 0;
      int realClaims = 0;
      int realRedeemed = 0;

      for (final row in data as List<dynamic>) {
        final type = row['event_type'] as String?;
        if (type == 'ping_sent') realPings++;
        if (type == 'opened') realOpened++;
        if (type == 'viewed') realViews++;
        if (type == 'claimed') realClaims++;
        if (type == 'redeemed') realRedeemed++;
      }

      // Cross-check redemptions from promos.redeemed_count
      if (realRedeemed == 0) {
        final promos = await fetchPromosForBusiness(businessId);
        final promoRedeemed =
            promos.fold<int>(0, (sum, p) => sum + p.redeemedCount);
        if (promoRedeemed > 0) {
          realRedeemed = promoRedeemed;
        }
      }

      return MerchantAnalyticsData.fromCounts(
        realPings: realPings,
        realOpened: realOpened,
        realViews: realViews,
        realClaims: realClaims,
        realRedeemed: realRedeemed,
      );
    } catch (_) {
      return MerchantAnalyticsData.zero();
    }
  }

  // -------------------------------------------------------------
  // Document Storage Upload
  // -------------------------------------------------------------

  /// Upload merchant verification permit to 'merchant-docs' bucket
  Future<String> uploadMerchantPermit({
    required String ownerId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final filePath = '$ownerId/$sanitizedName';

    await _client.storage.from('merchant-docs').uploadBinary(
          filePath,
          fileBytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('merchant-docs').getPublicUrl(filePath);
  }

  // -------------------------------------------------------------
  // Geofence Zones
  // -------------------------------------------------------------

  /// Fetch geofence zones for verified businesses that have at least one active promo
  Future<List<GeofenceZone>> fetchGeofenceZones() async {
    final businesses = await fetchVerifiedBusinesses();
    if (businesses.isEmpty) return [];

    final activePromos = await fetchActivePromos();
    if (activePromos.isEmpty) return [];

    final Map<String, List<Promo>> promosByBiz = {};
    for (final promo in activePromos) {
      promosByBiz.putIfAbsent(promo.businessId, () => []).add(promo);
    }

    final List<GeofenceZone> zones = [];
    for (final biz in businesses) {
      final bizPromos = promosByBiz[biz.id];
      if (bizPromos == null || bizPromos.isEmpty) continue;

      final bestPromo = bizPromos.first;
      final radius = (biz.radiusMeters != null && biz.radiusMeters! > 0)
          ? biz.radiusMeters!
          : defaultBusinessRadiusMeters;

      zones.add(GeofenceZone(
        id: biz.id,
        name: biz.name,
        category: biz.category,
        lat: biz.lat,
        lng: biz.lng,
        radiusMeters: radius,
        promoTitle: '${biz.name} has a promo near you',
        promoBody: bestPromo.title,
        promoId: bestPromo.id,
      ));
    }
    return zones;
  }
}
