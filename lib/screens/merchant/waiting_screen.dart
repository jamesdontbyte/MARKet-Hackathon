import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import 'verified_screen.dart';
import 'widgets/merchant_reg_stepper.dart';

/// WaitingScreen matches Stitch frame: market_waiting_for_verification
/// Starts a demoAutoVerifySeconds (10s) timer, then sets businesses.verified = true
/// and navigates to VerifiedScreen.
class WaitingScreen extends StatefulWidget {
  final Business? business;

  const WaitingScreen({
    super.key,
    this.business,
  });

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  Timer? _countdownTimer;
  int _secondsRemaining = demoAutoVerifySeconds;
  bool _isVerifying = false;
  String? _error;
  Business? _currentBusiness;

  @override
  void initState() {
    super.initState();
    _currentBusiness = widget.business;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initBusinessAndTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initBusinessAndTimer() async {
    try {
      if (_currentBusiness == null) {
        final uid = _authService.currentUserId;
        if (uid != null) {
          _currentBusiness = await _dataService.fetchMerchantBusiness(uid);
        }
      }

      if (_currentBusiness != null && _currentBusiness!.verified) {
        // Already verified; navigate straight to verified screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => VerifiedScreen(business: _currentBusiness),
              ),
            );
          }
        });
        return;
      }
    } catch (_) {
      // Continue with timer anyway
    }

    if (demoMode) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _secondsRemaining = 0;
          timer.cancel();
          _performAutoVerify();
        }
      });
    });
  }

  Future<void> _performAutoVerify() async {
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      Business? biz = _currentBusiness;
      if (biz == null) {
        final uid = _authService.currentUserId;
        if (uid != null) {
          biz = await _dataService.fetchMerchantBusiness(uid);
        }
      }

      if (biz != null) {
        final updated = await _dataService.updateBusiness(biz.copyWith(verified: true));
        biz = updated;
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VerifiedScreen(business: biz),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _error = 'Auto-verification error: ${e.toString().replaceAll("Exception:", "").trim()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Application Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MarketColors.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MarketSpacing.screenMargin,
            vertical: 12,
          ),
          child: Column(
            children: [
              // 4-Step Stepper
              const MerchantRegStepper(currentStep: 4),
              const SizedBox(height: 16),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: MarketColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A0F172A),
                            offset: Offset(0, 8),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Status Pill Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: MarketColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: MarketColors.primaryContainer.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: MarketColors.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'APPLICATION SUBMITTED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: MarketColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Layered Animated Pulsing Icon Badge
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: MarketColors.primaryContainer.withValues(
                                    alpha: 0.15 + (_pulseController.value * 0.15),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: MarketColors.surfaceContainerLowest,
                                    border: Border.all(
                                      color: MarketColors.primaryContainer,
                                      width: 2.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x140F172A),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.pending_actions_rounded,
                                    size: 36,
                                    color: MarketColors.primary,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Headline
                          const Text(
                            'Waiting for verification',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: MarketColors.onSurface,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // Description
                          const Text(
                            'Your business is being reviewed. Please wait until your business is verified before you can use MARKet.',
                            style: TextStyle(
                              fontSize: 13,
                              color: MarketColors.onSurfaceVariant,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // Demo Auto-Verify Countdown Pill
                          if (demoMode) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF8FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _secondsRemaining > 0
                                        ? 'Demo: Auto-verifying in $_secondsRemaining s...'
                                        : 'Demo: Verifying account now...',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          if (_error != null) ...[
                            Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: MarketColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Turnaround info box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: MarketColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: MarketColors.outlineVariant.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.schedule_rounded,
                                        size: 18, color: MarketColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Turnaround Time',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: MarketColors.onSurface,
                                            ),
                                          ),
                                          Text(
                                            'Processed within the day (Instant for Demo)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: MarketColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.notifications_active_outlined,
                                        size: 18, color: MarketColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Live Status Updates',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: MarketColors.onSurface,
                                            ),
                                          ),
                                          Text(
                                            "You'll receive a notification once DTI, BIR, and Mayor's Permit documents are approved.",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: MarketColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Actions
              const SizedBox(height: 12),
              PrimaryButton(
                width: double.infinity,
                height: 50,
                label: _isVerifying ? 'Verifying...' : 'Verify Now (Demo Bypass)',
                isLoading: _isVerifying,
                icon: const Icon(Icons.verified_rounded, size: 20),
                onPressed: _isVerifying ? null : _performAutoVerify,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/role-selection');
                },
                child: const Text(
                  'Switch Account or Role',
                  style: TextStyle(
                    fontSize: 13,
                    color: MarketColors.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
