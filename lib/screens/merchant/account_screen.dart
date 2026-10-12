import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/merchant_bottom_nav.dart';
import 'analytics_screen.dart';
import 'catalog_screen.dart';
import 'dashboard_screen.dart';

/// MSME Merchant Account & Compliance Screen
/// Matches Stitch frame: market_tab_4_account
class MerchantAccountScreen extends StatefulWidget {
  final Business? business;

  const MerchantAccountScreen({
    super.key,
    this.business,
  });

  @override
  State<MerchantAccountScreen> createState() => _MerchantAccountScreenState();
}

class _MerchantAccountScreenState extends State<MerchantAccountScreen> {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  Business? _business;
  Profile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _business = widget.business;
    _loadMerchantData();
  }

  Future<void> _loadMerchantData() async {
    setState(() => _isLoading = true);
    try {
      final uid = _authService.currentUserId;
      if (uid != null) {
        _profile = await _authService.fetchCurrentProfile();
        _business ??= await _dataService.fetchMerchantBusiness(uid);
      }
    } catch (_) {
      // Handled gracefully
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == 3) return; // Already on account
    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantDashboardScreen(business: _business),
        ),
      );
    } else if (index == 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantCatalogScreen(business: _business),
        ),
      );
    } else if (index == 2) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MerchantAnalyticsScreen(business: _business),
        ),
      );
    }
  }


  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/role-selection',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final biz = _business;
    final ownerName = _profile?.fullName ?? 'Business Owner';
    final email = _authService.currentUser?.email ?? 'No email set';
    final phone = _profile?.phone ?? biz?.phone ?? 'No phone set';

    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppBar(
        backgroundColor: MarketColors.surface,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.shield_outlined, color: MarketColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'MSME Trust & Legal Hub',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MarketColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: MarketSpacing.screenMargin,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Screen Title
                    const Text(
                      'Account & Compliance',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: MarketColors.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage merchant credentials, statutory permits, and shop preferences.',
                      style: TextStyle(
                        fontSize: 13,
                        color: MarketColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Merchant Profile Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: MarketColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x080F172A),
                            offset: Offset(0, 4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: MarketColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  size: 30,
                                  color: MarketColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ownerName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: MarketColors.onSurface,
                                      ),
                                    ),
                                    Text(
                                      biz?.name ?? 'My Business',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: MarketColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFBAE6FD)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.verified_rounded,
                                              size: 13, color: Color(0xFF0284C7)),
                                          SizedBox(width: 4),
                                          Text(
                                            'Verified MSME Merchant',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0284C7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Contact rows
                          _buildDetailRow(
                            icon: Icons.call_outlined,
                            text: phone.startsWith('+63') ? phone : '+63 $phone',
                            tag: 'Verified',
                            tagColor: MarketColors.success,
                          ),
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.mail_outline_rounded,
                            text: email,
                            tag: 'Primary',
                            tagColor: MarketColors.outline,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Sensitive Fields Re-Verification Notice
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.lock_outline_rounded,
                              size: 20, color: Color(0xFFD97706)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Verification Integrity Notice',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Editing Business Legal Name, Registered Documents, or GPS Location requires re-verification by MARKet administrators.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB45309),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Compliance Vault Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: MarketColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.verified_user_outlined,
                                      size: 20, color: MarketColors.primary),
                                  SizedBox(width: 8),
                                  Text(
                                    'Compliance Vault',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: MarketColors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'RA 10173 Data Privacy Encrypted Storage',
                            style: TextStyle(fontSize: 11, color: MarketColors.outline),
                          ),
                          const SizedBox(height: 14),

                          _buildVaultItem('DTI Registration Certificate', 'Valid • BN No. 4920194'),
                          const SizedBox(height: 8),
                          _buildVaultItem('BIR Form 2303 Certificate', 'TIN 492-109-844-000'),
                          const SizedBox(height: 8),
                          _buildVaultItem("Mayor's / Business Permit", 'LGU San Jose de Buenavista'),
                          const SizedBox(height: 8),
                          _buildVaultItem('PhilSys National ID', 'Verified Government Identity'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. GPS & Geofence Diagnostics
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MarketColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.my_location_rounded,
                                  size: 18, color: MarketColors.primary),
                              SizedBox(width: 8),
                              Text(
                                'Store Location & Geofence',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: MarketColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Address: ${biz?.address ?? "Address not set"}',
                            style: const TextStyle(fontSize: 12, color: MarketColors.onSurfaceVariant),
                          ),
                          Text(
                            'GPS: ${biz != null ? "${biz.lat.toStringAsFixed(6)}, ${biz.lng.toStringAsFixed(6)}" : "Not set"}',
                            style: const TextStyle(fontSize: 12, color: MarketColors.outline),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Log Out Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: MarketColors.error),
                        foregroundColor: MarketColors.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: _logout,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: MerchantBottomNav(
        currentIndex: 3,
        onTap: _onBottomNavTapped,
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String text,
    required String tag,
    required Color tagColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: MarketColors.outline),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MarketColors.onSurface,
                ),
              ),
            ],
          ),
          Text(
            tag,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tagColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultItem(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 18, color: MarketColors.primary),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: MarketColors.outline),
                  ),
                ],
              ),
            ],
          ),
          const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
        ],
      ),
    );
  }
}
