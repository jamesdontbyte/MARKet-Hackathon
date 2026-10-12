import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_final/models/business.dart';
import 'package:market_final/models/promo.dart';
import 'package:market_final/screens/merchant/analytics_screen.dart';
import 'package:market_final/screens/merchant/store_qr_screen.dart';
import 'package:market_final/screens/shopper/redeem_store_screen.dart';
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
    lat: 10.7674886,
    lng: 121.9428977,
    verified: true,
    coverUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24',
    createdAt: DateTime.now(),
  );

  final testPromo = Promo(
    id: '00000000-0000-0000-0000-000000000010',
    businessId: '00000000-0000-0000-0000-000000000001',
    title: 'Buy 1 Take 1 Muscovado Cold Brew',
    description: 'Refreshing local cold brew infused with Antique muscovado',
    promoType: 'bogo',
    valueLabel: 'BOGO',
    startsAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
    endsAt: DateTime.now().toUtc().add(const Duration(days: 6)),
    redeemLimit: 100,
    redeemedCount: 14,
    active: true,
    createdAt: DateTime.now().toUtc(),
  );

  group('Merchant StoreQrScreen Tests', () {
    testWidgets('StoreQrScreen renders QR code, 60s countdown, and today counter',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: StoreQrScreen(
            business: testBusiness,
            initialPromo: testPromo,
          ),
        ),
      );
      await tester.pump();

      // Screen Header
      expect(find.text('Store Checkout QR'), findsOneWidget);
      expect(find.text('Kape Tahanan'), findsOneWidget);

      // Promo info
      expect(find.text('BOGO'), findsOneWidget);
      expect(find.text('Buy 1 Take 1 Muscovado Cold Brew'), findsOneWidget);

      // 60-second countdown
      expect(find.textContaining('Refreshes in'), findsOneWidget);

      // Store Code Section
      expect(find.text('STORE CODE (60-SECOND WINDOW)'), findsOneWidget);
      expect(find.text('00000000'), findsOneWidget);

      // Live Redeemed Today counter
      expect(find.text('Redeemed Today'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Shopper RedeemStoreScreen Unit & Widget Tests', () {
    late FakeSupabaseClient fakeClient;
    late DataService dataService;

    setUp(() {
      fakeClient = FakeSupabaseClient();
      dataService = DataService(client: fakeClient);
    });

    testWidgets('Validates manual input and submits code through RPC redeem_at_store',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: RedeemStoreScreen(
            promo: testPromo,
            dataService: dataService,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Redeem at Store'), findsOneWidget);
      expect(find.text('Upload QR from Gallery'), findsOneWidget);
      expect(find.text('Type 8-Character Code'), findsOneWidget);

      // Switch to manual mode
      await tester.tap(find.text('Type 8-Character Code'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Store Code'), findsOneWidget);

      // Attempt submit with empty code
      await tester.tap(find.text('Redeem Code'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid 8-character code'), findsOneWidget);

      // Enter valid code
      await tester.enterText(
          find.byType(TextFormField).first, 'kt8x29q1');
      await tester.pumpAndSettle();

      fakeClient.rpcResult = 'ok';
      await tester.tap(find.text('Redeem Code'));
      await tester.pumpAndSettle();

      // Verify RPC was called with trimmed code
      expect(fakeClient.capturedFunction, equals('redeem_at_store'));
      expect(fakeClient.capturedParams, equals({'p_code': 'kt8x29q1'}));

      // Verify success result card
      expect(find.text('Voucher Redeemed!'), findsOneWidget);
      expect(find.text('Code: KT8X29Q1'), findsOneWidget);
      expect(find.text('View Redeemed Voucher'), findsOneWidget);

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
          home: RedeemStoreScreen(
            promo: testPromo,
            dataService: dataService,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Type 8-Character Code'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'ALREADY1');
      await tester.tap(find.text('Redeem Code'));
      await tester.pumpAndSettle();

      expect(find.text('Already Redeemed'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Renders distinct result card for expired_code',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeClient.rpcResult = 'expired_code';

      await tester.pumpWidget(
        MaterialApp(
          home: RedeemStoreScreen(
            promo: testPromo,
            dataService: dataService,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Type 8-Character Code'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'EXPCODE1');
      await tester.tap(find.text('Redeem Code'));
      await tester.pumpAndSettle();

      expect(find.text('Store Code Expired'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Renders distinct result card for expired promotion', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeClient.rpcResult = 'expired';

      await tester.pumpWidget(
        MaterialApp(
          home: RedeemStoreScreen(
            promo: testPromo,
            dataService: dataService,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Type 8-Character Code'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'EXPIRED1');
      await tester.tap(find.text('Redeem Code'));
      await tester.pumpAndSettle();

      expect(find.text('Promotion Expired'), findsOneWidget);

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
          home: RedeemStoreScreen(
            promo: testPromo,
            dataService: dataService,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Type 8-Character Code'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'MAXQUOTA');
      await tester.tap(find.text('Redeem Code'));
      await tester.pumpAndSettle();

      expect(find.text('Campaign Limit Reached'), findsOneWidget);

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
          home: RedeemStoreScreen(
            promo: testPromo,
            dataService: dataService,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Type 8-Character Code'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'BADCODE1');
      await tester.tap(find.text('Redeem Code'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid Store Code'), findsOneWidget);

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

      // 5-Step Funnel with real counts and empty state when unpopulated
      expect(find.text('Conversion Funnel'), findsOneWidget);
      expect(find.text('Geofence Pings Sent'), findsOneWidget);
      expect(find.text('Delivered & Opened Notifications'), findsOneWidget);
      expect(find.text('Store & Promo Views'), findsOneWidget);
      expect(find.text('Promo Claims Generated'), findsOneWidget);
      expect(find.text('Counter QR Scanned / Redeemed'), findsOneWidget);

      // Verify no "Sample data" labels and that empty state appears when zero
      expect(find.text('Sample data'), findsNothing);
      expect(find.text('No activity yet this week'), findsOneWidget);

      // Peak Footfall Insights
      expect(find.text('Peak Footfall Insights'), findsOneWidget);
      expect(find.text('Schedule Footfall Promo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
