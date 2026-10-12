import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import 'widgets/merchant_reg_stepper.dart';

/// VerifiedScreen matches Stitch frame: market_verified_page_mobile
/// Celebratory screen shown after merchant application is approved / auto-verified.
class VerifiedScreen extends StatefulWidget {
  final Business? business;

  const VerifiedScreen({
    super.key,
    this.business,
  });

  @override
  State<VerifiedScreen> createState() => _VerifiedScreenState();
}

class _VerifiedScreenState extends State<VerifiedScreen> {
  Business? _business;
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _business = widget.business;
    if (_business == null) {
      _loadBusiness();
    }
  }

  Future<void> _loadBusiness() async {
    final uid = _authService.currentUserId;
    if (uid != null) {
      final biz = await _dataService.fetchMerchantBusiness(uid);
      if (mounted) {
        setState(() {
          _business = biz;
        });
      }
    }
  }

  void _proceedToDashboard() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/merchant-home',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bizName = _business?.name.isNotEmpty == true
        ? _business!.name
        : 'Kape Tahanan';

    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Verification Approved',
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
                              color: const Color(0xFFEFF8FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFBAE6FD)),
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
                                  'ACCOUNT VERIFIED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Celebratory Icon Graphic
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                                ),
                              ),
                              Container(
                                width: 76,
                                height: 76,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: MarketColors.primaryContainer,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x263EC4FF),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF59E0B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.celebration_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0284C7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.storefront_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Title
                          const Text(
                            "You're verified!",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: MarketColors.onSurface,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // Subtitle with Business Name
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                color: MarketColors.onSurfaceVariant,
                              ),
                              children: [
                                const TextSpan(text: 'Welcome to MARKet, '),
                                TextSpan(
                                  text: bizName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: MarketColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Unlocked Features Summary Box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: MarketColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: MarketColors.outlineVariant.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'UNLOCKED FOR YOUR SHOP',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: MarketColors.outline,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildFeatureItem(
                                  icon: Icons.near_me_rounded,
                                  title: 'Live on local customer map with geofence alert feature',
                                ),
                                const SizedBox(height: 10),
                                _buildFeatureItem(
                                  icon: Icons.qr_code_scanner_rounded,
                                  title: 'Publish flash promotions & scan customer QR vouchers',
                                ),
                                const SizedBox(height: 10),
                                _buildFeatureItem(
                                  icon: Icons.verified_rounded,
                                  title: 'Official Verified MSME storefront trust badge',
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
                height: 52,
                label: 'Proceed to dashboard',
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                onPressed: _proceedToDashboard,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.support_agent_rounded,
                    size: 16, color: MarketColors.outline),
                label: const Text(
                  'Need assistance? Contact Support',
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFEFF8FF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: const Color(0xFF0284C7)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MarketColors.onSurface,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
