import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../services/geofence_service.dart';
import '../../widgets/app_buttons.dart';

/// PermissionExplainerScreen guides the shopper through 3 permission steps:
/// 1. Foreground Location (While in use)
/// 2. Background Location ("Allow all the time")
/// 3. Notifications (Android 13+)
class PermissionExplainerScreen extends StatefulWidget {
  final bool fromBanner;

  const PermissionExplainerScreen({
    super.key,
    this.fromBanner = false,
  });

  @override
  State<PermissionExplainerScreen> createState() =>
      _PermissionExplainerScreenState();
}

class _PermissionExplainerScreenState extends State<PermissionExplainerScreen> {
  int _currentStep = 1;
  bool _isRequesting = false;
  String? _stepMessage;

  Future<void> _handleStepAction() async {
    setState(() {
      _isRequesting = true;
      _stepMessage = null;
    });

    try {
      if (_currentStep == 1) {
        // Step 1: Foreground Location
        final status = await Permission.locationWhenInUse.request();
        if (status.isGranted) {
          setState(() {
            _currentStep = 2;
            _stepMessage = 'Foreground location granted. Next: background access.';
          });
        } else if (status.isPermanentlyDenied) {
          setState(() {
            _stepMessage = 'Location permission is permanently denied. Please enable in Settings.';
          });
        } else {
          setState(() {
            _stepMessage = 'Please grant location access while using the app to continue.';
          });
        }
      } else if (_currentStep == 2) {
        // Step 2: Background Location ("Allow all the time")
        final status = await Permission.locationAlways.request();
        if (status.isGranted) {
          setState(() {
            _currentStep = 3;
            _stepMessage = 'Background geofencing enabled. Next: notifications.';
          });
        } else {
          // Android 11+ requires opening App Settings for background location
          final opened = await openAppSettings();
          if (opened) {
            setState(() {
              _currentStep = 3;
              _stepMessage = 'Select "Allow all the time" in Settings, then return.';
            });
          }
        }
      } else if (_currentStep == 3) {
        // Step 3: Notifications
        await Permission.notification.request();
        await GeofenceService.instance.start();
        if (mounted) {
          _navigateForward(permissionsGranted: true);
        }
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  void _navigateForward({required bool permissionsGranted}) {
    if (widget.fromBanner && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(permissionsGranted);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/shopper-home', (route) => false);
    }
  }

  void _onSkip() {
    _navigateForward(permissionsGranted: false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.fromBanner,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateForward(permissionsGranted: false);
      },
      child: Scaffold(
        backgroundColor: MarketColors.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _onSkip,
              child: const Text(
                'Not now',
                style: TextStyle(
                  color: MarketColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MarketSpacing.screenMargin,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Enable Hyperlocal Alerts',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: MarketColors.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'MARKet uses geofencing to alert you to secret local MSME promos when you arrive in San Jose de Buenavista.',
                style: TextStyle(
                  fontSize: 14,
                  color: MarketColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Step Cards
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildStepCard(
                        stepNumber: 1,
                        title: '1. While-In-Use Location',
                        description:
                            'Discovers nearby shops, calculates live walking distance, and maps verified MSMEs on Roam.',
                        icon: Icons.my_location_rounded,
                        isActive: _currentStep == 1,
                        isCompleted: _currentStep > 1,
                      ),
                      const SizedBox(height: 14),
                      _buildStepCard(
                        stepNumber: 2,
                        title: '2. "Allow all the time"',
                        description:
                            'Essential for the background geofence service. Detects when you enter town even when your phone is locked or screen is off.',
                        icon: Icons.radar_rounded,
                        isActive: _currentStep == 2,
                        isCompleted: _currentStep > 2,
                      ),
                      const SizedBox(height: 14),
                      _buildStepCard(
                        stepNumber: 3,
                        title: '3. Lockscreen Promo Alerts',
                        description:
                            'Delivers instant notifications like "Promos near you in San Jose" with 1-tap claim vouchers.',
                        icon: Icons.notifications_active_rounded,
                        isActive: _currentStep == 3,
                        isCompleted: false,
                      ),
                      if (_stepMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: MarketColors.primaryContainer.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: MarketColors.primaryContainer.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _stepMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MarketColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              PrimaryButton(
                width: double.infinity,
                height: 52,
                label: _currentStep == 3
                    ? 'Finish & Enable Alerts'
                    : 'Allow Step $_currentStep of 3',
                isLoading: _isRequesting,
                onPressed: _handleStepAction,
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _onSkip,
                  child: const Text(
                    'I will enable this later in Account Settings',
                    style: TextStyle(
                      fontSize: 12,
                      color: MarketColors.outline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? MarketColors.success
              : isActive
                  ? MarketColors.primaryContainer
                  : const Color(0xFFCBD5E1),
          width: isActive || isCompleted ? 2.0 : 1.0,
        ),
        boxShadow: isActive ? MarketElevation.level2 : MarketElevation.level1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFFDCFCE7)
                  : isActive
                      ? MarketColors.primaryContainer.withValues(alpha: 0.2)
                      : MarketColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle_rounded : icon,
              color: isCompleted
                  ? MarketColors.success
                  : isActive
                      ? MarketColors.primary
                      : MarketColors.outline,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: MarketColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
