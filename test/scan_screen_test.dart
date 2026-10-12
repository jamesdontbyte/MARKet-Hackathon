import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_final/core/config.dart';
import 'package:market_final/models/business.dart';
import 'package:market_final/screens/merchant/analytics_screen.dart';
import 'package:market_final/screens/merchant/scan_screen.dart';
import 'package:market_final/services/data_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hand-written fake for PostgrestFilterBuilder completing with custom RPC response
class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  final T _value;

  FakePostgrestFilterBuilder(this._value);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future<T>.value(_value).then(onValue, onError: onError);
  }
}

/// Hand-written fake SupabaseClient capturing RPC calls without external mocking packages
class FakeSupabaseClient extends Fake implements SupabaseClient {
  String? capturedFunction;
  Map<String, dynamic>? capturedParams;
  dynamic rpcResult = 'ok';

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get,
  }) {
    capturedFunction = fn;
    capturedParams = params;
    return FakePostgrestFilterBuilder<T>(rpcResult as T);
  }
}

void main() {
  final testBusiness = Business(
    id: '00000000-0000-0000-0000-000000000001',
    name: 'Kape Tahanan',
    category: 'cafe',
    bio: 'Artisan Philippine specialty coffee and pastries',
    address: 'Corner Tradisyonal St., Brgy. San Pedro',
    phone: '917 842 5521',
    hours: 'Mon – Sun: 7:00 AM – 9:00 PM',
    lat: demoShopLat,
    lng: demoShopLng,
    verified: true,
    coverUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24',
    createdAt: DateTime.now(),
  );

  group('MerchantScanScreen Unit & Widget Tests', () {
    late FakeSupabaseClient fakeClient;
    late DataService dataService;

    setUp(() {
      fakeClient = FakeSupabaseClient();
      dataService = DataService(client: fakeClient);
    });

    testWidgets('Validates manual input and submits code through RPC',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantScanScreen(
            business: testBusiness,
            dataService: dataService,
          ),
        ),
      );
      await tester.pump();

      // Switch to manual mode
      await tester.tap(find.text('Enter Code'));
      await tester.pumpAndSettle();

      expect(find.text('Manual Code Verification'), findsOneWidget);

      // Attempt submit with empty code
      await tester.tap(find.text('Verify & Redeem'));
      await tester.pumpAndSettle();
      expect(find.text('Voucher code is required'), findsOneWidget);

      // Enter valid code
      await tester.enterText(
          find.byType(TextFormField).first, 'kt8x29q1');
      await tester.pumpAndSettle();

      fakeClient.rpcResult = 'ok';
      await tester.tap(find.text('Verify & Redeem'));
      await tester.pumpAndSettle();

      // Verify RPC was called with uppercase trimmed code
      expect(fakeClient.capturedFunction, equals('redeem_voucher'));
      expect(fakeClient.capturedParams, equals({'p_code': 'KT8X29Q1'}));

      // Verify success result card
      expect(find.text('Voucher Redeemed!'), findsOneWidget);
      expect(find.text('KT8X29Q1'), findsOneWidget);
      expect(find.text('Scan Next Voucher'), findsOneWidget);

      // Tap reset and verify input screen returns
      await tester.tap(find.text('Scan Next Voucher'));
      await tester.pumpAndSettle();
      expect(find.text('Voucher Redeemed!'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Renders distinct result card for already_redeemed',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeClient.rpcResult = 'already_redeemed';

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantScanScreen(
            business: testBusiness,
            dataService: dataService,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Enter Code'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'ALREADY1');
      await tester.tap(find.text('Verify & Redeem'));
      await tester.pumpAndSettle();

      expect(find.text('Voucher Already Redeemed'), findsOneWidget);
      expect(find.text('Scan Another Code'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Renders distinct result card for not_your_promo',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeClient.rpcResult = 'not_your_promo';

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantScanScreen(
            business: testBusiness,
            dataService: dataService,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Enter Code'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'OTHERBIZ');
      await tester.tap(find.text('Verify & Redeem'));
      await tester.pumpAndSettle();

      expect(find.text('Different Merchant Promotion'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Renders distinct result card for expired', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeClient.rpcResult = 'expired';

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantScanScreen(
            business: testBusiness,
            dataService: dataService,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Enter Code'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'EXPIRED1');
      await tester.tap(find.text('Verify & Redeem'));
      await tester.pumpAndSettle();

      expect(find.text('Promotion Has Expired'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Renders distinct result card for limit_reached',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeClient.rpcResult = 'limit_reached';

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantScanScreen(
            business: testBusiness,
            dataService: dataService,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Enter Code'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'MAXQUOTA');
      await tester.tap(find.text('Verify & Redeem'));
      await tester.pumpAndSettle();

      expect(find.text('Redemption Limit Reached'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Renders distinct result card for invalid code',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeClient.rpcResult = 'invalid';

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantScanScreen(
            business: testBusiness,
            dataService: dataService,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Enter Code'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'BADCODE1');
      await tester.tap(find.text('Verify & Redeem'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid Voucher Code'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('MerchantAnalyticsScreen Widget Tests', () {
    testWidgets(
        'Renders header, radar range card, 5 funnel steps, and peak insights',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantAnalyticsScreen(business: testBusiness),
        ),
      );
      await tester.pump();

      // Brand and store name
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('MARKet'),
        ),
        findsWidgets,
      );
      expect(find.text('Kape Tahanan'), findsWidgets);
      expect(find.text('San Jose de Buenavista'), findsOneWidget);

      // Radar Visualizer
      expect(find.text('Geofence Range'), findsOneWidget);
      expect(find.text('Active Discovery Radius'), findsOneWidget);

      // 5-Step Funnel with fallback numbers
      expect(find.text('Conversion Funnel'), findsOneWidget);
      expect(find.text('Geofence Pings Sent'), findsOneWidget);
      expect(find.text('Delivered & Opened Notifications'), findsOneWidget);
      expect(find.text('Store & Promo Views'), findsOneWidget);
      expect(find.text('Promo Claims Generated'), findsOneWidget);
      expect(find.text('Counter QR Scanned / Redeemed'), findsOneWidget);

      // Verify "Sample data" labels appear on unpopulated metrics
      expect(find.text('Sample data'), findsWidgets);

      // Peak Footfall Insights
      expect(find.text('Peak Footfall Insights'), findsOneWidget);
      expect(find.text('Schedule Footfall Promo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
