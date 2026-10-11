import 'package:flutter/material.dart';
import '../core/theme.dart';

/// MerchantBottomNav provides the 4-tab bottom navigation bar for merchants:
/// Dashboard (0), Catalog (1), Scan (2), Analytics (3).
/// Every item satisfies the 48x48dp minimum target with clear active styling.
class MerchantBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MerchantBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    bool isSpecial = false,
  }) {
    final isSelected = currentIndex == index;
    final color = isSelected ? MarketColors.primary : MarketColors.outline;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSpecial) ...[
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MarketColors.primaryContainer
                          : MarketColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      color: isSelected
                          ? MarketColors.onSurface
                          : MarketColors.primary,
                      size: 20,
                    ),
                  ),
                ] else ...[
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: color,
                    size: 24,
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        border: const Border(
          top: BorderSide(color: MarketColors.cardBorder, width: 1.0),
        ),
        boxShadow: MarketElevation.level1,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: 'Dashboard',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2_rounded,
                label: 'Catalog',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.qr_code_scanner_rounded,
                activeIcon: Icons.qr_code_scanner_rounded,
                label: 'Scan',
                isSpecial: true,
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.analytics_outlined,
                activeIcon: Icons.analytics_rounded,
                label: 'Analytics',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
