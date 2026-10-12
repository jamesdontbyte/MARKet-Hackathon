import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:market_final/core/config.dart';
import 'package:market_final/services/geofence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeofenceService Phase 7B Engine Tests', () {
    const cafeZone = GeofenceZone(
      id: 'biz_cafe_1',
      name: 'Kape Tahanan',
      category: 'cafe',
      lat: 10.754707,
      lng: 121.934428,
      radiusMeters: 200.0,
      promoTitle: 'Kape Tahanan has a promo near you',
      promoBody: 'Buy 1 Take 1 Afternoon Coffee Hour',
      promoId: 'promo_cafe_1',
    );

    const retailZone = GeofenceZone(
      id: 'biz_retail_2',
      name: 'Antique Crafts & Souvenirs',
      category: 'retail',
      lat: 10.760000,
      lng: 121.940000,
      radiusMeters: 200.0,
      promoTitle: 'Antique Crafts & Souvenirs has a promo near you',
      promoBody: '20% OFF Patadyong Weaves',
      promoId: 'promo_retail_2',
    );

    test('Initializes with default empty zones and custom zones', () {
      final service = GeofenceService(zones: [cafeZone, retailZone]);
      expect(service.zones.length, 2);
      expect(service.zones.first.id, 'biz_cafe_1');
      expect(service.zones.first.radiusMeters, defaultBusinessRadiusMeters);
    });

    test('Identifies nearest zone correctly based on position', () {
      final service = GeofenceService(zones: [cafeZone, retailZone]);

      // Position right next to Kape Tahanan
      final nearCafe = Position(
        latitude: 10.754800,
        longitude: 121.934500,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final nearest = service.getNearestZone(nearCafe);
      expect(nearest?.id, 'biz_cafe_1');

      // Position right next to Antique Crafts
      final nearRetail = Position(
        latitude: 10.760100,
        longitude: 121.940100,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final nearestRetail = service.getNearestZone(nearRetail);
      expect(nearestRetail?.id, 'biz_retail_2');
    });

    test('Entering business radius triggers onZoneEntered', () {
      final enteredZones = <GeofenceZone>[];
      final service = GeofenceService(
        zones: [cafeZone],
        onZoneEntered: (z) => enteredZones.add(z),
      );

      // Outside radius (more than 200m away)
      service.feedManualPosition(Position(
        latitude: 10.765000,
        longitude: 121.945000,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));

      expect(enteredZones.isEmpty, isTrue);

      // Inside radius (< 200m away, exact lat/lng)
      service.feedManualPosition(Position(
        latitude: 10.754707,
        longitude: 121.934428,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));

      expect(enteredZones.length, 1);
      expect(enteredZones.first.id, 'biz_cafe_1');
    });

    test('Exit buffer prevents premature exit flapping', () {
      var insideMap = <String, bool>{};
      final service = GeofenceService(
        zones: [cafeZone],
        onPosition: (pos, inside, src) => insideMap = inside,
        exitBufferMeters: 30.0,
      );

      // 1. Move inside zone (distance = 0m <= 200m)
      service.feedManualPosition(Position(
        latitude: 10.754707,
        longitude: 121.934428,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));
      expect(insideMap['biz_cafe_1'], isTrue);

      // 2. Move to distance ~215m (which is > 200m, but <= 200m + 30m buffer)
      // 0.0019 degrees latitude is ~210m
      service.feedManualPosition(Position(
        latitude: 10.754707 + 0.0019,
        longitude: 121.934428,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));
      expect(insideMap['biz_cafe_1'], isTrue);

      // 3. Move clearly outside (distance > 230m)
      // 0.005 degrees latitude is ~550m
      service.feedManualPosition(Position(
        latitude: 10.754707 + 0.0050,
        longitude: 121.934428,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));
      expect(insideMap['biz_cafe_1'], isFalse);
    });

    test('Simulate enter and exit use unified _handlePosition code path', () {
      final entered = <GeofenceZone>[];
      var lastInside = false;

      final service = GeofenceService(
        zones: [cafeZone],
        onZoneEntered: (z) => entered.add(z),
        onPosition: (pos, inside, src) {
          lastInside = inside['biz_cafe_1'] ?? false;
        },
      );

      // Simulate enter
      service.simulateEnter(zone: cafeZone);
      expect(entered.length, 1);
      expect(entered.first.id, 'biz_cafe_1');
      expect(lastInside, isTrue);

      // Simulate exit
      service.simulateExit(zone: cafeZone);
      expect(lastInside, isFalse);
    });

    test('Shopper interest filter matches only relevant categories when interests exist', () {
      final logs = <String>[];
      final service = GeofenceService(
        zones: [cafeZone, retailZone],
        shopperInterests: ['cafe'], // only cafe
        onLog: (m) => logs.add(m),
      );

      // Enter retail zone (category 'retail')
      service.feedManualPosition(Position(
        latitude: 10.760000,
        longitude: 121.940000,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));

      // Retail was entered, but notification skipped due to interest mismatch
      expect(service.getLastEntered('biz_retail_2'), isNotNull);
      expect(service.getLastNotified('biz_retail_2'), isNull);

      // Enter cafe zone (category 'cafe')
      service.feedManualPosition(Position(
        latitude: 10.754707,
        longitude: 121.934428,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));

      // Cafe matches shopper interests: notification fired
      expect(service.getLastEntered('biz_cafe_1'), isNotNull);
      expect(service.getLastNotified('biz_cafe_1'), isNotNull);
    });

    test('Shopper with zero interests receives alerts for all categories', () {
      final service = GeofenceService(
        zones: [cafeZone, retailZone],
        shopperInterests: [], // zero interests
      );

      // Enter retail zone
      service.feedManualPosition(Position(
        latitude: 10.760000,
        longitude: 121.940000,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));

      expect(service.getLastNotified('biz_retail_2'), isNotNull);

      // Enter cafe zone
      service.feedManualPosition(Position(
        latitude: 10.754707,
        longitude: 121.934428,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));

      expect(service.getLastNotified('biz_cafe_1'), isNotNull);
    });

    test('Per-business cooldown tracks independently and skips re-notification', () {
      final logs = <String>[];
      final service = GeofenceService(
        zones: [cafeZone, retailZone],
        cooldown: const Duration(minutes: 3),
        onLog: (m) => logs.add(m),
      );

      // 1. Enter cafe
      service.feedManualPosition(Position(
        latitude: 10.754707,
        longitude: 121.934428,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));
      final firstNotifiedTime = service.getLastNotified('biz_cafe_1');
      expect(firstNotifiedTime, isNotNull);

      // 2. Exit cafe
      service.feedManualPosition(Position(
        latitude: 10.754707 + 0.01,
        longitude: 121.934428,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));

      // 3. Re-enter cafe immediately (within 3m cooldown)
      service.feedManualPosition(Position(
        latitude: 10.754707,
        longitude: 121.934428,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));

      // Timestamp did not change because cooldown was active
      expect(service.getLastNotified('biz_cafe_1'), equals(firstNotifiedTime));
      expect(logs.any((m) => m.contains('cooldown active')), isTrue);

      // 4. Enter retail - retail has its own independent cooldown state
      service.feedManualPosition(Position(
        latitude: 10.760000,
        longitude: 121.940000,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      ));
      expect(service.getLastNotified('biz_retail_2'), isNotNull);
    });
  });
}
