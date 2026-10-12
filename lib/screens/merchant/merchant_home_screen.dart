import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../models/business.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_card.dart';

/// MerchantHomeScreen placeholder destination after merchant login.
/// Shows merchant profile, business status, geofence spike shortcut, and logout.
class MerchantHomeScreen extends StatefulWidget {
  const MerchantHomeScreen({super.key});

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();
  Business? _business;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMerchantData();
  }

  Future<void> _loadMerchantData() async {
    try {
      final uid = _authService.currentUserId;
      if (uid != null) {
        final b = await _dataService.fetchMerchantBusiness(uid);
        if (mounted) {
          setState(() {
            _business = b;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: const [
            Text(
              'MARK',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: MarketColors.primaryContainer,
              ),
            ),
            Text(
              'et',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: MarketColors.onSurface,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Merchant',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: MarketColors.outline,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: MarketColors.onSurfaceVariant),
            tooltip: 'Log Out',
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(MarketSpacing.screenMargin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCardElevated(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  color: MarketColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _business?.name ?? 'MSME Business',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: MarketColors.onSurface,
                                      ),
                                    ),
                                    Text(
                                      _authService.currentUser?.email ?? 'Merchant Account',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: MarketColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (_business?.verified ?? false)
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(MarketRadii.pill),
                                ),
                                child: Text(
                                  (_business?.verified ?? false)
                                      ? 'Verified MSME'
                                      : 'Verification Pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: (_business?.verified ?? false)
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Hardware & Geofence Spike Action
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.radar_rounded, color: MarketColors.primary, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Hardware & Geofence Verification',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: MarketColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Access the device verification harness to test background location updates and notification triggers.',
                            style: TextStyle(
                              fontSize: 13,
                              color: MarketColors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            width: double.infinity,
                            label: 'Open Geofence Spike Screen',
                            icon: const Icon(Icons.explore_rounded, size: 18),
                            onPressed: () {
                              Navigator.of(context).pushNamed('/spike');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    SecondaryButton(
                      width: double.infinity,
                      label: 'Log Out',
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
