import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_final/screens/shared/login_screen.dart';
import 'package:market_final/screens/shared/role_selection_screen.dart';
import 'package:market_final/screens/shared/splash_screen.dart';
import 'package:market_final/screens/shopper/interests_screen.dart';
import 'package:market_final/screens/shopper/register_screen.dart';

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

  testWidgets('LoginScreen displays fields, validation and demo quick login shortcuts', (tester) async {
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

    // Verify demoMode buttons exist
    expect(find.text('Demo Shopper'), findsOneWidget);
    expect(find.text('Demo Merchant (Kape Tahanan)'), findsOneWidget);

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
}
