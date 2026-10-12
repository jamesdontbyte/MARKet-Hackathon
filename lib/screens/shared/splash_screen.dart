import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';

/// 2-second branded splash screen matching the Stitch market_splash_screen.
/// Evaluates Supabase session and user profile, routing accordingly.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startRoutingTimer();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
              nextRoute = '/shopper-home';
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
      Navigator.of(context).pushReplacementNamed(nextRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      body: Stack(
        children: [
          // Ambient decorative soft gradients matching Stitch frame
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MarketColors.primaryContainer.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MarketColors.surfaceContainerHigh.withValues(alpha: 0.4),
              ),
            ),
          ),

          // Main Hero Center Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MarketSpacing.screenMargin,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Elevated Soft Modern Tile with Logo
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 130,
                        height: 130,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: MarketColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: MarketColors.surfaceContainer,
                            width: 1.5,
                          ),
                          boxShadow: MarketElevation.level2,
                        ),
                        child: Image.asset(
                          'assets/logos/market_icon.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.storefront_rounded,
                            size: 64,
                            color: MarketColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dual-Tone Wordmark (MARK in cyan & et in deep slate navy)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: const [
                        Text(
                          'MARK',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.primaryContainer,
                            letterSpacing: -1.0,
                          ),
                        ),
                        Text(
                          'et',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.onSurface,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Category Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: MarketColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(MarketRadii.pill),
                        border: Border.all(
                          color: MarketColors.primaryContainer.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: MarketColors.primaryContainer,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'MSME HYPERLOCAL DISCOVERY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: MarketColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tagline
                    const Text(
                      'Connecting MSMEs to Potential Customers',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: MarketColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),

                    const Spacer(),

                    // Minimalist Progress Bar Loading State
                    SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(MarketRadii.pill),
                        child: const LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: MarketColors.surfaceContainer,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            MarketColors.primaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
