import 'package:flutter_test/flutter_test.dart';
import 'package:market_final/models/business.dart';
import 'package:market_final/models/product.dart';
import 'package:market_final/models/profile.dart';
import 'package:market_final/models/promo.dart';
import 'package:market_final/models/redemption.dart';
import 'package:market_final/models/merchant_analytics.dart';

void main() {
  group('Models Serialization & Deserialization', () {
    test('Profile round-trip', () {
      final json = {
        'id': '11111111-1111-1111-1111-111111111111',
        'role': 'shopper',
        'full_name': 'Juan Dela Cruz',
        'phone': '09171234567',
        'interests': ['cafe', 'food'],
        'prefs': {'flash_promos': true, 'expiry_reminders': false},
        'created_at': '2026-10-12T00:00:00.000Z',
      };

      final profile = Profile.fromJson(json);
      expect(profile.id, '11111111-1111-1111-1111-111111111111');
      expect(profile.role, 'shopper');
      expect(profile.isShopper, isTrue);
      expect(profile.isMerchant, isFalse);
      expect(profile.fullName, 'Juan Dela Cruz');
      expect(profile.interests, contains('cafe'));
      expect(profile.prefs['flash_promos'], isTrue);

      final outJson = profile.toJson();
      expect(outJson['role'], 'shopper');
      expect(outJson['full_name'], 'Juan Dela Cruz');
      expect(outJson['interests'], contains('food'));
    });

    test('Business round-trip with media and operating hours', () {
      final json = {
        'id': '22222222-2222-2222-2222-222222222222',
        'owner_id': '33333333-3333-3333-3333-333333333333',
        'name': 'Kape Tahanan',
        'category': 'cafe',
        'subtitle': 'Specialty Coffee in San Jose',
        'bio': 'Locally sourced coffee beans from Antique farmers',
        'address': 'Bancal, San Jose de Buenavista',
        'phone': '09281234567',
        'hours': 'Mon-Sun: 7am - 8pm',
        'lat': 10.754707481558897,
        'lng': 121.93442817768808,
        'radius_m': 1500.0,
        'rating': 4.8,
        'verified': true,
        'cover_url': 'https://example.com/cover.jpg',
        'logo_url': 'https://example.com/logo.jpg',
        'interior_urls': ['https://example.com/int1.jpg', 'https://example.com/int2.jpg'],
        'open_days': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        'opens_at': '08:00',
        'closes_at': '18:00',
        'created_at': '2026-10-12T00:00:00.000Z',
      };

      final biz = Business.fromJson(json);
      expect(biz.id, '22222222-2222-2222-2222-222222222222');
      expect(biz.name, 'Kape Tahanan');
      expect(biz.category, 'cafe');
      expect(biz.lat, closeTo(10.7547, 0.001));
      expect(biz.verified, isTrue);
      expect(biz.coverUrl, 'https://example.com/cover.jpg');
      expect(biz.logoUrl, 'https://example.com/logo.jpg');
      expect(biz.interiorUrls, hasLength(2));
      expect(biz.openDays, contains('Mon'));
      expect(biz.opensAt, '08:00');
      expect(biz.closesAt, '18:00');

      final outJson = biz.toJson();
      expect(outJson['name'], 'Kape Tahanan');
      expect(outJson['cover_url'], 'https://example.com/cover.jpg');
      expect(outJson['logo_url'], 'https://example.com/logo.jpg');
      expect(outJson['interior_urls'], hasLength(2));
      expect(outJson['open_days'], contains('Mon'));
      expect(outJson['opens_at'], '08:00');
      expect(outJson['closes_at'], '18:00');
    });

    test('Business isOpenNow and openStatusText computation', () {
      final openBiz = Business(
        id: 'open-biz',
        name: 'Always Open',
        category: 'retail',
        bio: 'Open shop',
        address: 'San Jose',
        phone: '9171234567',
        hours: 'Daily',
        lat: 10.7,
        lng: 121.9,
        verified: true,
        openDays: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        opensAt: '00:00',
        closesAt: '23:59',
        createdAt: DateTime.now(),
      );
      expect(openBiz.isOpenNow, isTrue);
      expect(openBiz.openStatusText, startsWith('Open'));

      final closedBiz = Business(
        id: 'closed-biz',
        name: 'Closed Biz',
        category: 'retail',
        bio: 'Closed shop',
        address: 'San Jose',
        phone: '9171234567',
        hours: 'Never',
        lat: 10.7,
        lng: 121.9,
        verified: true,
        openDays: const [],
        opensAt: '00:00',
        closesAt: '00:01',
        createdAt: DateTime.now(),
      );
      expect(closedBiz.isOpenNow, isFalse);
      expect(closedBiz.openStatusText, startsWith('Closed'));
    });

    test('Product round-trip', () {
      final json = {
        'id': '44444444-4444-4444-4444-444444444444',
        'business_id': '22222222-2222-2222-2222-222222222222',
        'name': 'Barako Pour Over',
        'price': 120.50,
        'category': 'beverages',
        'description': 'Single origin native Liberica',
        'created_at': '2026-10-12T00:00:00.000Z',
      };

      final product = Product.fromJson(json);
      expect(product.name, 'Barako Pour Over');
      expect(product.price, 120.50);

      final outJson = product.toJson();
      expect(outJson['price'], 120.50);
      expect(outJson['name'], 'Barako Pour Over');
    });

    test('Promo validity and progress fractions', () {
      final now = DateTime.now();
      final activePromo = Promo(
        id: '55555555-5555-5555-5555-555555555555',
        businessId: '22222222-2222-2222-2222-222222222222',
        title: 'BOGO Afternoon Coffee',
        promoType: 'bogo',
        valueLabel: 'BOGO',
        startsAt: now.subtract(const Duration(days: 1)),
        endsAt: now.add(const Duration(days: 3)),
        redeemLimit: 50,
        redeemedCount: 10,
        active: true,
        createdAt: now.subtract(const Duration(days: 1)),
      );

      expect(activePromo.isCurrentlyValid, isTrue);
      expect(activePromo.progressFraction, 0.2);

      final expiredPromo = activePromo.copyWith(
        endsAt: now.subtract(const Duration(hours: 1)),
      );
      expect(expiredPromo.isCurrentlyValid, isFalse);

      final limitReachedPromo = activePromo.copyWith(
        redeemedCount: 50,
      );
      expect(limitReachedPromo.isCurrentlyValid, isFalse);
    });

    test('Redemption status and 8-char uppercase code normalization', () {
      final json = {
        'id': '66666666-6666-6666-6666-666666666666',
        'promo_id': '55555555-5555-5555-5555-555555555555',
        'user_id': '11111111-1111-1111-1111-111111111111',
        'code': '  kt8x29q1  ',
        'status': 'issued',
        'created_at': '2026-10-12T00:00:00.000Z',
      };

      final redemption = Redemption.fromJson(json);
      expect(redemption.code, 'KT8X29Q1');
      expect(redemption.isIssued, isTrue);
      expect(redemption.isRedeemed, isFalse);

      final redeemed = redemption.copyWith(
        status: 'redeemed',
        redeemedAt: DateTime.now(),
      );
      expect(redeemed.isRedeemed, isTrue);
      expect(redeemed.status, 'redeemed');
    });

    test('MerchantAnalyticsData.zero initializes all counts to 0 and empty state', () {
      final data = MerchantAnalyticsData.zero();
      expect(data.pingsSent.count, equals(0));
      expect(data.deliveredAndOpened.count, equals(0));
      expect(data.storeAndPromoViews.count, equals(0));
      expect(data.claimsGenerated.count, equals(0));
      expect(data.counterRedemptions.count, equals(0));
      expect(data.hasActivity, isFalse);
    });

    test('Promo created at local time has starts_at <= now UTC and ends_at after it, ending in Z', () {
      final localNow = DateTime.now();
      final startsAt = DateTime.now().toUtc();
      final localExpiryDate = localNow.add(const Duration(days: 7));
      final localEndsAt = DateTime(
        localExpiryDate.year,
        localExpiryDate.month,
        localExpiryDate.day,
        23,
        59,
        59,
      );
      final endsAt = localEndsAt.toUtc();

      final promo = Promo(
        id: 'promo-local-time-test',
        businessId: 'biz-123',
        title: 'Flash Coffee Discount',
        promoType: 'percent',
        valueLabel: '20% OFF',
        startsAt: startsAt,
        endsAt: endsAt,
        redeemLimit: 100,
        redeemedCount: 0,
        active: true,
        createdAt: startsAt,
      );

      final nowUtc = DateTime.now().toUtc();
      expect(promo.startsAt.isBefore(nowUtc) || promo.startsAt.isAtSameMomentAs(nowUtc), isTrue);
      expect(promo.endsAt.isAfter(nowUtc), isTrue);
      expect(promo.isCurrentlyValid, isTrue);

      final json = promo.toJson();
      expect(json['starts_at'], endsWith('Z'));
      expect(json['ends_at'], endsWith('Z'));
      expect(json['created_at'], endsWith('Z'));

      final roundTrip = Promo.fromJson(json);
      expect(roundTrip.startsAt.isUtc, isTrue);
      expect(roundTrip.endsAt.isUtc, isTrue);
      expect(roundTrip.startsAt.isBefore(DateTime.now().toUtc()) || roundTrip.startsAt.isAtSameMomentAs(DateTime.now().toUtc()), isTrue);
      expect(roundTrip.endsAt.isAfter(DateTime.now().toUtc()), isTrue);
      expect(roundTrip.isCurrentlyValid, isTrue);
    });

    test('Promo created for 2026-10-13 09:00 local Manila time produces starts_at 2026-10-13T01:00:00Z and end date 23:59:59 becomes 15:59:59Z', () {
      final manilaOffset = const Duration(hours: 8);

      // 1. Timezone-explicit test using +08:00 offset
      final manilaStarts = DateTime.parse('2026-10-13T09:00:00+08:00');
      final manilaEnds = DateTime.parse('2026-10-13T23:59:59+08:00');

      final promoIso = Promo(
        id: 'promo-manila-iso-test',
        businessId: 'biz-123',
        title: 'Manila 9AM Promo',
        startsAt: manilaStarts.toUtc(),
        endsAt: manilaEnds.toUtc(),
        createdAt: manilaStarts.toUtc(),
      );

      final jsonIso = promoIso.toJson();
      expect(jsonIso['starts_at'], startsWith('2026-10-13T01:00:00'));
      expect(jsonIso['starts_at'], endsWith('Z'));
      expect(jsonIso['ends_at'], startsWith('2026-10-13T15:59:59'));
      expect(jsonIso['ends_at'], endsWith('Z'));

      // 2. Local picker constructor test when running in Manila timezone (+08:00)
      if (DateTime.now().timeZoneOffset == manilaOffset) {
        final localPickerStarts = DateTime(2026, 10, 13, 9, 0, 0);
        final localPickerEnds = DateTime(2026, 10, 13, 23, 59, 59);

        final promoLocal = Promo(
          id: 'promo-manila-local-test',
          businessId: 'biz-123',
          title: 'Manila Local Picker Promo',
          startsAt: localPickerStarts.toUtc(),
          endsAt: localPickerEnds.toUtc(),
          createdAt: localPickerStarts.toUtc(),
        );

        final jsonLocal = promoLocal.toJson();
        expect(jsonLocal['starts_at'], startsWith('2026-10-13T01:00:00'));
        expect(jsonLocal['starts_at'], endsWith('Z'));
        expect(jsonLocal['ends_at'], startsWith('2026-10-13T15:59:59'));
        expect(jsonLocal['ends_at'], endsWith('Z'));

        final readBack = Promo.fromJson(jsonLocal);
        expect(readBack.startsAt.toLocal().hour, equals(9));
        expect(readBack.startsAt.toLocal().minute, equals(0));
        expect(readBack.endsAt.toLocal().hour, equals(23));
        expect(readBack.endsAt.toLocal().minute, equals(59));
        expect(readBack.endsAt.toLocal().second, equals(59));
      }
    });
  });
}
