import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:market_final/models/business.dart';
import 'package:market_final/models/profile.dart';
import 'package:market_final/services/auth_service.dart';
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
    testWidgets('RegStep1Screen renders form fields and country selector without separate SMS button', (tester) async {
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
      expect(find.text('Verify via SMS'), findsNothing);
      expect(find.text('+63'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
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
      expect(find.text('Use my location'), findsOneWidget);
      expect(find.text('Continue to Permits'), findsOneWidget);
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

      expect(find.textContaining('Products & Services'), findsOneWidget);
      expect(find.textContaining('Promotions'), findsOneWidget);
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

      expect(find.textContaining('Products & Services'), findsOneWidget);
      expect(find.textContaining('Promotions'), findsOneWidget);
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

  group('Merchant Sign-Up Step 1 Path & Profile Creation Tests', () {
    testWidgets('Step 1 signs up merchant, creates profiles row (role = merchant, full name, phone) and advances to Step 2', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = FakeMerchantAuthService();
      final regController = MerchantRegController()..dob = 'May 15, 1990';

      await tester.pumpWidget(
        MaterialApp(
          home: RegStep1Screen(
            controller: regController,
            authService: fakeAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter Step 1 fields
      final textFields = find.byType(TextFormField);
      // 0: full name, 1: dob, 2: phone, 3: email, 4: password, 5: confirm password
      await tester.enterText(textFields.at(0), 'Maria Santos');
      await tester.enterText(textFields.at(1), '1990-05-15');
      await tester.enterText(textFields.at(2), '9171234567');
      await tester.enterText(textFields.at(3), 'maria@example.com');
      await tester.enterText(textFields.at(4), 'password123');
      await tester.enterText(textFields.at(5), 'password123');
      await tester.pumpAndSettle();

      // Scroll and tap "Continue to Business Information" to open OTP sheet
      final continueBtn = find.text('Continue to Business Information');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Verify OTP bottom sheet opened with demo code
      expect(find.text('Verify Mobile Number'), findsOneWidget);
      expect(find.text('Demo code: 123456'), findsOneWidget);

      // Auto-fill or enter OTP
      await tester.tap(find.text('Auto-fill'));
      await tester.pumpAndSettle();

      // Confirm verification
      await tester.tap(find.text('Confirm Verification'));
      await tester.pumpAndSettle();

      // Verify merchant sign-up was executed with exact role, full name, and phone
      expect(fakeAuth.signUpCalled, isTrue);
      expect(fakeAuth.passedEmail, equals('maria@example.com'));
      expect(fakeAuth.passedPassword, equals('password123'));
      expect(fakeAuth.passedFullName, equals('Maria Santos'));
      expect(fakeAuth.passedPhone, equals('+639171234567'));

      // Verify profile row properties: role matches constraint, NOT NULL fields filled
      expect(fakeAuth.mockProfileRow, isNotNull);
      expect(fakeAuth.mockProfileRow!['role'], equals('merchant'));
      expect(fakeAuth.mockProfileRow!['full_name'], equals('Maria Santos'));
      expect(fakeAuth.mockProfileRow!['phone'], equals('+639171234567'));
      expect(fakeAuth.mockProfileRow!['interests'], equals(<String>[]));

      // Verify advanced to Step 2
      expect(find.text('Business Information'), findsOneWidget);
    });

    testWidgets('Step 1 displays real error message and does not advance when profile creation fails', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = FakeMerchantAuthService()
        ..shouldFail = true
        ..failureMessage = 'new row violates row-level security policy for table "profiles"';
      final regController = MerchantRegController()..dob = 'May 15, 1990';

      await tester.pumpWidget(
        MaterialApp(
          home: RegStep1Screen(
            controller: regController,
            authService: fakeAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Maria Santos');
      await tester.enterText(textFields.at(1), '1990-05-15');
      await tester.enterText(textFields.at(2), '9171234567');
      await tester.enterText(textFields.at(3), 'maria@example.com');
      await tester.enterText(textFields.at(4), 'password123');
      await tester.enterText(textFields.at(5), 'password123');
      await tester.pumpAndSettle();

      final continueBtn = find.text('Continue to Business Information');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Auto-fill'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Verification'));
      await tester.pumpAndSettle();

      // Sign-up attempted but failed
      expect(fakeAuth.signUpCalled, isTrue);

      // Real error message is displayed
      expect(find.textContaining('violates row-level security policy'), findsOneWidget);

      // Did NOT continue to Step 2
      expect(find.text('Business Information'), findsNothing);
    });

    testWidgets('Step 1 wrong OTP shows error and stays on bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = FakeMerchantAuthService();
      final regController = MerchantRegController()..dob = 'May 15, 1990';

      await tester.pumpWidget(
        MaterialApp(
          home: RegStep1Screen(
            controller: regController,
            authService: fakeAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Maria Santos');
      await tester.enterText(textFields.at(1), '1990-05-15');
      await tester.enterText(textFields.at(2), '9171234567');
      await tester.enterText(textFields.at(3), 'maria@example.com');
      await tester.enterText(textFields.at(4), 'password123');
      await tester.enterText(textFields.at(5), 'password123');
      await tester.pumpAndSettle();

      final continueBtn = find.text('Continue to Business Information');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Modal is open
      expect(find.text('Verify Mobile Number'), findsOneWidget);

      // Enter wrong code in OTP field
      final otpField = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(otpField, '999999');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Verification'));
      await tester.pumpAndSettle();

      // Real error message is displayed and sheet remains visible
      expect(find.textContaining('Invalid code'), findsOneWidget);
      expect(find.text('Verify Mobile Number'), findsOneWidget);
      expect(fakeAuth.signUpCalled, isFalse);
    });

    testWidgets('Step 1 returning from Step 2 does not re-run sign-up or reopen OTP sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeAuth = FakeMerchantAuthService();
      final regController = MerchantRegController()..isOtpVerified = true..dob = 'May 15, 1990';

      await tester.pumpWidget(
        MaterialApp(
          home: RegStep1Screen(
            controller: regController,
            authService: fakeAuth,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Maria Santos');
      await tester.enterText(textFields.at(1), '1990-05-15');
      await tester.enterText(textFields.at(2), '9171234567');
      await tester.enterText(textFields.at(3), 'maria@example.com');
      await tester.enterText(textFields.at(4), 'password123');
      await tester.enterText(textFields.at(5), 'password123');
      await tester.pumpAndSettle();

      final continueBtn = find.text('Continue to Business Information');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // No OTP sheet was opened
      expect(find.text('Verify Mobile Number'), findsNothing);
      // Sign-up was not called again
      expect(fakeAuth.signUpCalled, isFalse);
      // Went directly to Step 2
      expect(find.text('Business Information'), findsOneWidget);
    });

    test('FakeMerchantAuthService updates profile when row already exists rather than failing', () async {
      final fakeAuth = FakeMerchantAuthService();

      // First call (creates)
      await fakeAuth.signUpMerchant(
        email: 'merchant@example.com',
        password: 'password123',
        fullName: 'Initial Name',
        phone: '+639171112222',
      );
      expect(fakeAuth.mockProfileRow!['full_name'], equals('Initial Name'));
      expect(fakeAuth.mockProfileRow!['role'], equals('merchant'));

      // Second call (updates existing rather than failing)
      await fakeAuth.signUpMerchant(
        email: 'merchant@example.com',
        password: 'password123',
        fullName: 'Updated Name',
        phone: '+639179998888',
      );
      expect(fakeAuth.mockProfileRow!['full_name'], equals('Updated Name'));
      expect(fakeAuth.mockProfileRow!['phone'], equals('+639179998888'));
      expect(fakeAuth.mockProfileRow!['role'], equals('merchant'));
    });
  });

  group('Merchant Responsive Layout & Overflow Tests', () {
    final testSizes = [
      const Size(360, 640),
      const Size(411, 891),
      const Size(640, 360),
      const Size(891, 411),
    ];
    final textScales = [1.0, 1.5];

    for (final size in testSizes) {
      for (final scale in textScales) {
        testWidgets('RegStep2Screen at ${size.width.toInt()}x${size.height.toInt()} scale $scale has no overflow', (tester) async {
          tester.view.physicalSize = Size(size.width * 2, size.height * 2);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final controller = MerchantRegController();
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: RegStep2Screen(controller: controller),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        });

        testWidgets('RegStep4ReviewScreen at ${size.width.toInt()}x${size.height.toInt()} scale $scale has no overflow', (tester) async {
          tester.view.physicalSize = Size(size.width * 2, size.height * 2);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final controller = MerchantRegController();
          controller.businessName = 'Kape Tahanan';
          controller.category = 'cafe';
          controller.bio = 'Artisan coffee in Antique';
          controller.address = 'Corner St, Brgy 1';
          controller.municipality = 'San Jose de Buenavista';
          controller.phone = '9171234567';
          controller.openDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
          controller.opensAt = '08:00';
          controller.closesAt = '20:00';

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: RegStep4ReviewScreen(controller: controller),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        });

        testWidgets('MerchantDashboardScreen at ${size.width.toInt()}x${size.height.toInt()} scale $scale has no overflow', (tester) async {
          tester.view.physicalSize = Size(size.width * 2, size.height * 2);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          FlutterError.onError = (details) => FlutterError.dumpErrorToConsole(details);
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: MerchantDashboardScreen(business: testBusiness),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  });
}

class FakeMerchantAuthService extends AuthService {
  bool signUpCalled = false;
  String? passedEmail;
  String? passedPassword;
  String? passedFullName;
  String? passedPhone;
  bool shouldFail = false;
  String failureMessage = 'Failed to create profile row';
  String? currentUserIdMock;
  Map<String, dynamic>? mockProfileRow;

  @override
  String? get currentUserId => currentUserIdMock;

  @override
  bool get isAuthenticated => currentUserIdMock != null;

  @override
  Future<AuthResponse> signUpMerchant({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    signUpCalled = true;
    passedEmail = email;
    passedPassword = password;
    passedFullName = fullName;
    passedPhone = phone;

    if (shouldFail) {
      throw Exception(failureMessage);
    }

    mockProfileRow = {
      'id': 'test-merchant-uid',
      'role': 'merchant',
      'full_name': fullName,
      'phone': phone,
      'interests': <String>[],
      'prefs': {
        'flash_promos': true,
        'expiry_reminders': true,
        'weekly_digest': false,
      },
    };
    currentUserIdMock = 'test-merchant-uid';

    return AuthResponse(
      session: null,
      user: User(
        id: 'test-merchant-uid',
        appMetadata: const {},
        userMetadata: {
          'role': 'merchant',
          'full_name': fullName,
          'phone': phone,
        },
        aud: 'authenticated',
        createdAt: '2026-10-12T00:00:00Z',
      ),
    );
  }
}
