import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../services/geofence_service.dart';
import '../../services/notification_service.dart';
import '../shopper/promo_detail_screen.dart';

/// 2-second branded splash screen matching the Stitch market_splash_screen.
/// Evaluates Supabase session and user profile, routing accordingly.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _startRoutingTimer();
  }

  Future<void> _startRoutingTimer() async {
    final stopwatch = Stopwatch()..start();

    String nextRoute = '/role-selection';
    try {
      if (_authService.isAuthenticated) {
        final profile = await _authService.fetchCurrentProfile();
        if (profile != null) {
          if (profile.role == 'shopper') {
            if (profile.interests.isEmpty) {
              nextRoute = '/interests';
            } else {
              final locInUse = await Permission.locationWhenInUse.isGranted;
              final locAlways = await Permission.locationAlways.isGranted;
              final notif = await Permission.notification.isGranted;
              if (!locInUse || !locAlways || !notif) {
                nextRoute = '/permission-explainer';
              } else {
                await GeofenceService.instance.start();
                nextRoute = '/shopper-home';
              }
            }
          } else if (profile.role == 'merchant') {
            final business = await _dataService.fetchMerchantBusiness(profile.id);
            if (business == null) {
              nextRoute = '/merchant-reg';
            } else if (business.verified) {
              nextRoute = '/merchant-home';
            } else {
              nextRoute = '/merchant-waiting';
            }
          }
        }
      }
    } catch (_) {
      // Graceful fallback to role selection on connection or auth issue
      nextRoute = '/role-selection';
    }

    final elapsedMs = stopwatch.elapsedMilliseconds;
    final remainingDelay = 2000 - elapsedMs;
    if (remainingDelay > 0) {
      await Future<void>.delayed(Duration(milliseconds: remainingDelay));
    }

    if (mounted) {
      final initialPromo = NotificationService.instance.initialPayload;
      if (initialPromo != null && initialPromo.isNotEmpty) {
        NotificationService.instance.initialPayload = null;
        Navigator.of(context).pushReplacementNamed(nextRoute);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PromoDetailScreen(
              promoId: initialPromo,
              fromNotification: true,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacementNamed(nextRoute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      body: Center(
        child: Image.asset(
          'assets/logos/logo_icon.png',
          width: 104,
          height: 104,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.storefront_rounded,
            size: 80,
            color: MarketColors.primary,
          ),
        ),
      ),
    );
  }
}
