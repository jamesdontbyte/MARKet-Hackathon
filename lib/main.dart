import 'package:flutter/material.dart';
import 'core/supabase.dart';
import 'core/theme.dart';
import 'services/notification_service.dart';
import 'spike/geofence_spike_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications with global tap routing
  await NotificationService.instance.init(
    onTapped: (payload) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => SpikePromoDetailScreen(payload: payload),
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
      home: const GeofenceSpikeScreen(),
    );
  }
}
