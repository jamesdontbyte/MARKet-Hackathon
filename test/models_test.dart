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

    test('Business round-trip with cover_url', () {
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
        'created_at': '2026-10-12T00:00:00.000Z',
      };

      final biz = Business.fromJson(json);
      expect(biz.id, '22222222-2222-2222-2222-222222222222');
      expect(biz.name, 'Kape Tahanan');
      expect(biz.category, 'cafe');
      expect(biz.lat, closeTo(10.7547, 0.001));
      expect(biz.verified, isTrue);
      expect(biz.coverUrl, 'https://example.com/cover.jpg');

      final outJson = biz.toJson();
      expect(outJson['name'], 'Kape Tahanan');
      expect(outJson['cover_url'], 'https://example.com/cover.jpg');
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
  });
}
