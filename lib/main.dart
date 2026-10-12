import 'package:flutter/material.dart';
import 'core/supabase.dart';
import 'core/theme.dart';
import 'services/notification_service.dart';
import 'screens/merchant/merchant_home_screen.dart';
import 'screens/merchant/merchant_reg_placeholder.dart';
import 'screens/merchant/merchant_waiting_screen.dart';
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
        '/merchant-reg': (_) => const MerchantRegPlaceholderScreen(),
        '/merchant-home': (_) => const MerchantHomeScreen(),
        '/merchant-waiting': (_) => const MerchantWaitingScreen(),
        '/spike': (_) => const GeofenceSpikeScreen(),
      },
    );
  }
}
