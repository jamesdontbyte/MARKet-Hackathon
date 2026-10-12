import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/app_buttons.dart';

/// RoleSelectionScreen matches the Stitch market_role_selection frame.
/// Allows selecting between Merchant and Shopper roles before continuing.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // 'shopper' or 'merchant'
  String _selectedRole = 'shopper';

  void _onContinue() {
    if (_selectedRole == 'shopper') {
      Navigator.of(context).pushNamed('/register-shopper');
    } else {
      Navigator.of(context).pushNamed('/merchant-reg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isShopper = _selectedRole == 'shopper';
    final isMerchant = _selectedRole == 'merchant';

    return Scaffold(
      backgroundColor: MarketColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: MarketSpacing.screenMargin,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Title Header with Logo and Dual-Tone Wordmark
                    Image.asset(
                      'assets/logos/logo_icon.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: const [
                        Text(
                          'Welcome to ',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'MARK',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.primaryContainer,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'et',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    const Text(
                      'Select your role to get started with localized discovery and community commerce.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: MarketColors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Option 1: MSME Merchant
                    _buildRoleCard(
                      isSelected: isMerchant,
                      roleId: 'merchant',
                      iconData: Icons.storefront_rounded,
                      iconBgColor: const Color(0xFFE0F2FE),
                      iconColor: MarketColors.primary,
                      badgeText: 'MSME Merchant',
                      badgeBgColor: MarketColors.primaryContainer.withValues(alpha: 0.18),
                      badgeTextColor: const Color(0xFF0284C7),
                      title: 'I am a Business Owner',
                      description:
                          'Promote your shop, launch geofenced promos, verify walk-in redemptions, and grow local foot traffic.',
                      highlights: const [
                        _HighlightItem(icon: Icons.verified_outlined, label: 'Free listing'),
                        _HighlightItem(icon: Icons.qr_code_scanner_rounded, label: 'Instant QR verification'),
                        _HighlightItem(icon: Icons.near_me_outlined, label: 'Local discovery'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Option 2: Shopper / Consumer
                    _buildRoleCard(
                      isSelected: isShopper,
                      roleId: 'shopper',
                      iconData: Icons.local_mall_outlined,
                      iconBgColor: MarketColors.surfaceContainerHigh,
                      iconColor: MarketColors.onSurface,
                      badgeText: 'Local Discovery',
                      badgeBgColor: MarketColors.surfaceContainerHigh,
                      badgeTextColor: MarketColors.onSurfaceVariant,
                      title: 'I am a Shopper / Customer',
                      description:
                          'Discover nearby neighborhood gems, exclusive local promos, and secret daily discounts near you.',
                      highlights: const [
                        _HighlightItem(icon: Icons.percent_rounded, label: 'Nearby deals'),
                        _HighlightItem(icon: Icons.notifications_active_outlined, label: 'Real-time alerts'),
                        _HighlightItem(icon: Icons.favorite_border_rounded, label: 'Support local'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom CTA Area
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MarketSpacing.screenMargin,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: MarketColors.surface,
                border: Border(
                  top: BorderSide(
                    color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    offset: Offset(0, -4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    width: double.infinity,
                    height: 52,
                    label: isShopper ? 'Continue as Shopper' : 'Continue as Business Owner',
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    onPressed: _onContinue,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account?',
                        style: TextStyle(
                          fontSize: 14,
                          color: MarketColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.padded,
                        ),
                        onPressed: () {
                          Navigator.of(context).pushNamed('/login');
                        },
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: MarketColors.link,
                          ),
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
    );
  }

  Widget _buildRoleCard({
    required bool isSelected,
    required String roleId,
    required IconData iconData,
    required Color iconBgColor,
    required Color iconColor,
    required String badgeText,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required String title,
    required String description,
    required List<_HighlightItem> highlights,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = roleId;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: MarketColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? MarketColors.primaryContainer : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected ? MarketElevation.level2 : MarketElevation.level1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Badge + Check Indicator
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(iconData, color: iconColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeBgColor,
                          borderRadius: BorderRadius.circular(MarketRadii.pill),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.onSurface,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                // Radio/Check Indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? MarketColors.primaryContainer
                        : MarketColors.surfaceContainerLowest,
                    border: Border.all(
                      color: isSelected
                          ? MarketColors.primaryContainer
                          : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: MarketColors.onSurface,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Description
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: MarketColors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),

            // Divider & Highlights
            Divider(color: const Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: highlights.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (idx > 0) ...[
                      const Text(
                        '•',
                        style: TextStyle(color: MarketColors.outlineVariant, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(item.icon, size: 14, color: const Color(0xFF0369A1)),
                    const SizedBox(width: 4),
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MarketColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightItem {
  final IconData icon;
  final String label;

  const _HighlightItem({required this.icon, required this.label});
}
