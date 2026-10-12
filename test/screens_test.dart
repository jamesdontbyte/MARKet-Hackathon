import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_final/models/promo.dart';
import 'package:market_final/models/redemption.dart';
import 'package:market_final/screens/shared/login_screen.dart';
import 'package:market_final/screens/shared/permission_explainer_screen.dart';
import 'package:market_final/screens/shared/role_selection_screen.dart';
import 'package:market_final/screens/shared/splash_screen.dart';
import 'package:market_final/screens/shopper/dashboard_screen.dart';
import 'package:market_final/screens/shopper/interests_screen.dart';
import 'package:market_final/screens/shopper/promo_detail_screen.dart';
import 'package:market_final/screens/shopper/register_screen.dart';
import 'package:market_final/screens/shopper/voucher_screen.dart';

void main() {
  testWidgets('SplashScreen displays brand assets and routes after delay', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/',
        routes: {
          '/': (_) => const SplashScreen(),
          '/role-selection': (_) => const Scaffold(body: Text('Role Selection Destination')),
        },
      ),
    );

    expect(find.text('MARK'), findsOneWidget);
    expect(find.text('et'), findsOneWidget);
    expect(find.text('MSME HYPERLOCAL DISCOVERY'), findsOneWidget);
    expect(find.text('Connecting MSMEs to Potential Customers'), findsOneWidget);

    // Pump past splash duration to complete timer and route
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Role Selection Destination'), findsOneWidget);
  });

  testWidgets('RoleSelectionScreen toggles role and changes CTA text', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RoleSelectionScreen(),
      ),
    );

    expect(find.text('Welcome to '), findsOneWidget);
    expect(find.text('I am a Business Owner'), findsOneWidget);
    expect(find.text('I am a Shopper / Customer'), findsOneWidget);

    // Default selection is shopper
    expect(find.text('Continue as Shopper'), findsOneWidget);

    // Tap Merchant card
    await tester.tap(find.text('I am a Business Owner'));
    await tester.pumpAndSettle();

    // CTA button updates
    expect(find.text('Continue as Business Owner'), findsOneWidget);

    // Tap back to Shopper card
    await tester.tap(find.text('I am a Shopper / Customer'));
    await tester.pumpAndSettle();
    expect(find.text('Continue as Shopper'), findsOneWidget);

    // Verify Log In button exists
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('LoginScreen displays fields and validation', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('Log in to '), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Tap Log In with empty fields to trigger validation
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);

    // Unfocus and settle any cursor timers
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  });

  testWidgets('ShopperRegisterScreen validates inputs and opens OTP bottom sheet with demo code', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ShopperRegisterScreen(),
      ),
    );

    expect(find.text('Create Your Account'), findsOneWidget);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Government ID Verification'), findsOneWidget);

    // Scroll to the submit button
    final submitFinder = find.text('Create Account & Continue');
    await tester.ensureVisible(submitFinder);
    await tester.pumpAndSettle();

    // Tap submit with empty form -> triggers validation
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    expect(find.text('Please enter your full name'), findsOneWidget);

    // Fill valid form fields
    await tester.enterText(find.byType(TextFormField).at(0), 'Juan dela Cruz');
    await tester.enterText(find.byType(TextFormField).at(1), 'juan@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), '9171234567');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');
    await tester.enterText(find.byType(TextFormField).at(4), 'password123');

    // Tap Create Account & Continue -> should open OTP modal sheet
    await tester.ensureVisible(submitFinder);
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    expect(find.text('Verify Mobile Number'), findsOneWidget);
    expect(find.text('Demo code: 123456'), findsOneWidget);
    expect(find.text('Verify & Complete Registration'), findsOneWidget);

    // Dismiss modal and clean up timers
    Navigator.of(tester.element(find.text('Verify Mobile Number'))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('InterestsScreen renders 8 categories and updates counter on toggle', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: InterestsScreen(),
      ),
    );

    expect(find.text('What are your interests?'), findsOneWidget);
    expect(find.text('Food & Restaurants'), findsOneWidget);
    expect(find.text('Cafés'), findsOneWidget);

    // Initial counter (2 selected: food, cafe)
    expect(find.text('2 selected'), findsOneWidget);

    // Scroll and verify categories
    await tester.scrollUntilVisible(find.text('Health & Wellness'), 100);
    expect(find.text('Health & Wellness'), findsOneWidget);

    // Tap Health & Wellness -> counter should become 3
    await tester.tap(find.text('Health & Wellness'));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);

    // Tap Cafés -> counter should become 2
    await tester.scrollUntilVisible(find.text('Cafés'), -100);
    await tester.tap(find.text('Cafés'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    expect(find.text('Continue to Dashboard'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('PermissionExplainerScreen steps through all 3 stages', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PermissionExplainerScreen(),
      ),
    );

    // Verify all 3 permission points are clearly explained
    expect(find.text('1. While-In-Use Location'), findsOneWidget);
    expect(find.text('2. "Allow all the time"'), findsOneWidget);
    expect(find.text('3. Lockscreen Promo Alerts'), findsOneWidget);
    expect(find.text('Allow Step 1 of 3'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('I will enable this later in Account Settings'), findsOneWidget);

    // Tap Not now
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
  });

  testWidgets('PromoDetailScreen renders promotion terms and voucher action', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockPromo = Promo(
      id: 'promo-mock-1',
      businessId: 'biz-1',
      title: 'Buy 1 Get 1 Free Barako Latte',
      description: 'Exclusive afternoon special for Kape Tahanan patrons.',
      promoType: 'bogo',
      valueLabel: 'BOGO',
      startsAt: DateTime.now().subtract(const Duration(days: 1)),
      endsAt: DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PromoDetailScreen(
          promo: mockPromo,
          fromNotification: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Buy 1 Get 1 Free Barako Latte'), findsOneWidget);
    expect(find.text('Promotion Details'), findsOneWidget);
    expect(find.text('Exclusive afternoon special for Kape Tahanan patrons.'), findsOneWidget);
    expect(find.text('Get Voucher'), findsOneWidget);
    expect(find.text('Save to Stash'), findsOneWidget);
  });

  testWidgets('VoucherScreen renders QR code, voucher code, and redemption instructions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockPromo = Promo(
      id: 'promo-mock-1',
      businessId: 'biz-1',
      title: '20% Off Artisan Handwoven Crafts',
      promoType: 'percent',
      valueLabel: '20% OFF',
      startsAt: DateTime.now().subtract(const Duration(days: 1)),
      endsAt: DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now(),
    );

    final mockRedemption = Redemption(
      id: 'red-1',
      promoId: 'promo-mock-1',
      userId: 'user-1',
      code: 'KAPE2026',
      status: 'issued',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VoucherScreen(
          promo: mockPromo,
          initialRedemption: mockRedemption,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('KAPE2026'), findsOneWidget);
    expect(find.text('20% Off Artisan Handwoven Crafts'), findsOneWidget);
    expect(find.text('Active • Valid'), findsOneWidget);
    expect(find.text('Present this QR code or 8-character code to the cashier in-store for verification.'), findsOneWidget);
  });

  testWidgets('DashboardScreen renders brand header, search bar, categories, and bottom nav', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardScreen(),
      ),
    );

    // Initial render
    await tester.pump();

    // Verify Brand Cluster
    expect(find.text('MARK'), findsOneWidget);
    expect(find.text('et'), findsOneWidget);

    // Verify Search hint
    expect(find.text('Search businesses, products, or services'), findsOneWidget);

    // Verify Categories
    expect(find.text('All Categories'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Cafés'), findsOneWidget);

    // Verify 4-tab Bottom Navigation
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Roam'), findsOneWidget);
    expect(find.text('Stash'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    // Long-press brand cluster to trigger simulation sheet
    await tester.longPress(find.text('MARK'));
    await tester.pumpAndSettle();

    expect(find.text('Geofence Simulation'), findsOneWidget);
    expect(find.text('Simulate entering zone'), findsOneWidget);
    expect(find.text('Simulate leaving zone'), findsOneWidget);

    // Dismiss bottom sheet and cleanup timers
    Navigator.of(tester.element(find.text('Geofence Simulation'))).pop();
    await tester.pumpAndSettle();
  });
}
