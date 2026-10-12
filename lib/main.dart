import 'package:flutter/material.dart';
import 'core/config.dart';
import 'core/supabase.dart';
import 'core/theme.dart';
import 'services/notification_service.dart';
import 'screens/merchant/account_screen.dart';
import 'screens/merchant/analytics_screen.dart';
import 'screens/merchant/catalog_screen.dart';
import 'screens/merchant/dashboard_screen.dart';
import 'screens/merchant/merchant_reg_controller.dart';
import 'screens/merchant/merchant_reg_entry_screen.dart';
import 'screens/merchant/promotions_screen.dart';
import 'screens/merchant/reg_step1_screen.dart';
import 'screens/merchant/reg_step2_screen.dart';
import 'screens/merchant/reg_step3_screen.dart';
import 'screens/merchant/reg_step4_review_screen.dart';
import 'screens/merchant/scan_screen.dart';
import 'screens/merchant/verified_screen.dart';
import 'screens/merchant/waiting_screen.dart';
import 'screens/shared/login_screen.dart';
import 'screens/shared/permission_explainer_screen.dart';
import 'screens/shared/role_selection_screen.dart';
import 'screens/shared/splash_screen.dart';
import 'screens/shopper/account_screen.dart';
import 'screens/shopper/dashboard_screen.dart';
import 'screens/shopper/interests_screen.dart';
import 'screens/shopper/promo_detail_screen.dart';
import 'screens/shopper/register_screen.dart';
import 'screens/shopper/roam_screen.dart';
import 'screens/shopper/stash_screen.dart';
import 'spike/geofence_spike_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications with global tap routing to PromoDetailScreen
  await NotificationService.instance.init(
    onTapped: (payload) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => PromoDetailScreen(
            promoId: payload,
            fromNotification: true,
          ),
        ),
      );
    },
  );

  // Initialize Supabase (graceful if placeholder keys in env.dart)
  try {
    await initSupabase();
  } catch (_) {
    // Continue even if placeholder credentials
  }

  runApp(const MarketApp());
}

class MarketApp extends StatelessWidget {
  const MarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MARKet',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildMarketTheme(),
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/role-selection': (_) => const RoleSelectionScreen(),
        '/login': (_) => const LoginScreen(),
        '/register-shopper': (_) => const ShopperRegisterScreen(),
        '/interests': (_) => const InterestsScreen(),
        '/shopper-home': (_) => const DashboardScreen(),
        '/roam': (_) => const RoamScreen(),
        '/stash': (_) => const StashScreen(),
        '/account': (_) => const AccountScreen(),
        '/permission-explainer': (_) => const PermissionExplainerScreen(),
        '/merchant-reg': (_) => const MerchantRegEntryScreen(),
        '/merchant-step1': (_) => const RegStep1Screen(),
        '/merchant-step2': (_) => RegStep2Screen(controller: MerchantRegController()),
        '/merchant-step3': (_) => RegStep3Screen(controller: MerchantRegController()),
        '/merchant-step4': (_) => RegStep4ReviewScreen(controller: MerchantRegController()),
        '/merchant-waiting': (_) => const WaitingScreen(),
        '/merchant-verified': (_) => const VerifiedScreen(),
        '/merchant-home': (_) => const MerchantDashboardScreen(),
        '/merchant-dashboard': (_) => const MerchantDashboardScreen(),
        '/merchant-catalog': (_) => const MerchantCatalogScreen(),
        '/merchant-promotions': (_) => const MerchantPromotionsScreen(),
        '/merchant-analytics': (_) => const MerchantAnalyticsScreen(),
        '/merchant-scan': (_) => const MerchantScanScreen(),
        '/merchant-account': (_) => const MerchantAccountScreen(),
        '/spike': (_) => demoMode ? const GeofenceSpikeScreen() : const SplashScreen(),
      },
    );
  }
}
