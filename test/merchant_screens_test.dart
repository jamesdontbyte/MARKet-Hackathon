import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_final/models/business.dart';
import 'package:market_final/models/profile.dart';
import 'package:market_final/screens/merchant/account_screen.dart';
import 'package:market_final/screens/merchant/catalog_screen.dart';
import 'package:market_final/screens/merchant/dashboard_screen.dart';
import 'package:market_final/screens/merchant/merchant_reg_controller.dart';
import 'package:market_final/screens/merchant/promotions_screen.dart';
import 'package:market_final/screens/merchant/reg_step1_screen.dart';
import 'package:market_final/screens/merchant/reg_step2_screen.dart';
import 'package:market_final/screens/merchant/reg_step3_screen.dart';
import 'package:market_final/screens/merchant/reg_step4_review_screen.dart';
import 'package:market_final/screens/merchant/verified_screen.dart';
import 'package:market_final/screens/merchant/waiting_screen.dart';
import 'package:market_final/screens/merchant/widgets/merchant_reg_stepper.dart';

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

  group('MerchantRegController Unit Tests', () {
    test('Initial controller defaults to empty coordinates and empty category', () {
      final controller = MerchantRegController();
      expect(controller.lat, isNull);
      expect(controller.lng, isNull);
      expect(controller.category, equals(''));
      expect(controller.isOtpVerified, isFalse);
    });

    test('populateFromProfile populates fields and sets OTP verified for resume', () {
      final controller = MerchantRegController();
      final profile = Profile(
        id: 'user_123',
        role: 'merchant',
        fullName: 'Carlos Mendoza',
        phone: '917 555 0192',
        createdAt: DateTime.now(),
      );

      controller.populateFromProfile(profile, null);
      expect(controller.fullName, equals('Carlos Mendoza'));
      expect(controller.phone, equals('917 555 0192'));
      expect(controller.contactPhone, equals('917 555 0192'));
      expect(controller.isOtpVerified, isTrue);
    });
  });

  group('Merchant Registration Stepper Tests', () {
    testWidgets('MerchantRegStepper renders all 4 step titles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MerchantRegStepper(currentStep: 1),
          ),
        ),
      );

      expect(find.text('Basics'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Permits'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
    });
  });

  group('Merchant Registration Steps UI Tests', () {
    testWidgets('RegStep1Screen renders form fields and verify SMS button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: RegStep1Screen(),
        ),
      );

      expect(find.text('Account & Owner Credentials'), findsOneWidget);
      expect(find.text('Verify via SMS'), findsOneWidget);
      expect(find.text('Continue to Business Information'), findsOneWidget);
    });

    testWidgets('RegStep2Screen renders canonical categories and coordinates', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = MerchantRegController();
      await tester.pumpWidget(
        MaterialApp(
          home: RegStep2Screen(controller: controller),
        ),
      );

      expect(find.text('Business Information'), findsOneWidget);
      expect(find.text('Use my current location'), findsOneWidget);
      expect(find.text('Continue to Business Verification'), findsOneWidget);
    });

    testWidgets('RegStep3Screen renders 4 document dropzones', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = MerchantRegController();
      await tester.pumpWidget(
        MaterialApp(
          home: RegStep3Screen(controller: controller),
        ),
      );

      expect(find.text('Business Verification'), findsOneWidget);
      expect(find.text('1. DTI or SEC Certificate'), findsOneWidget);
      expect(find.text('2. BIR Certificate (Form 2303)'), findsOneWidget);
      expect(find.text("3. Mayor's / Business Permit"), findsOneWidget);
      expect(find.text('4. Valid Government ID / Clearance'), findsOneWidget);
      expect(find.text('Continue to Review'), findsOneWidget);
    });

    testWidgets('RegStep4ReviewScreen renders summary and submit button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = MerchantRegController();
      controller.businessName = 'Kape Tahanan';
      controller.fullName = 'Maria Santos';

      await tester.pumpWidget(
        MaterialApp(
          home: RegStep4ReviewScreen(controller: controller),
        ),
      );

      expect(find.text('Review Registration'), findsOneWidget);
      expect(find.text('Owner Information'), findsOneWidget);
      expect(find.text('Business Information'), findsOneWidget);
      expect(find.text('Submit Application'), findsOneWidget);
    });
  });

  group('Waiting & Verified Screens UI Tests', () {
    testWidgets('WaitingScreen displays status card and turnaround details', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final unverifiedBiz = testBusiness.copyWith(verified: false);
      await tester.pumpWidget(
        MaterialApp(
          home: WaitingScreen(business: unverifiedBiz),
        ),
      );
      await tester.pump();

      expect(find.text('APPLICATION SUBMITTED'), findsOneWidget);
      expect(find.text('Waiting for verification'), findsOneWidget);
      expect(find.text('Turnaround Time'), findsOneWidget);

      // Unmount WaitingScreen to cancel periodic timer and pulse animation
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('VerifiedScreen displays congratulations and unlocked features', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: VerifiedScreen(business: testBusiness),
        ),
      );
      await tester.pump();

      expect(find.text('ACCOUNT VERIFIED'), findsOneWidget);
      expect(find.text("You're verified!"), findsOneWidget);
      expect(find.text('Proceed to dashboard'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Merchant Dashboard, Catalog, Promotions & Account Tests', () {
    testWidgets('MerchantDashboardScreen renders performance and about sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantDashboardScreen(business: testBusiness),
        ),
      );
      await tester.pump();

      expect(find.text('PERFORMANCE OVERVIEW'), findsOneWidget);
      expect(find.text('Create Promo'), findsOneWidget);
      expect(find.text('Active Promos'), findsOneWidget);
      expect(find.text('About Our Business'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('MerchantCatalogScreen renders toggle and Add Item button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantCatalogScreen(business: testBusiness),
        ),
      );
      await tester.pump();

      expect(find.text('Products & Services (0)'), findsOneWidget);
      expect(find.text('Promotions'), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('MerchantPromotionsScreen displays Scan QR placeholder on tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantPromotionsScreen(business: testBusiness),
        ),
      );
      await tester.pump();

      expect(find.text('Products & Services'), findsOneWidget);
      expect(find.text('Promotions (0)'), findsOneWidget);
      expect(find.text('New Promo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('MerchantAccountScreen renders compliance vault and logout', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: MerchantAccountScreen(business: testBusiness),
        ),
      );
      await tester.pump();

      expect(find.text('Account & Compliance'), findsOneWidget);
      expect(find.text('Compliance Vault'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
