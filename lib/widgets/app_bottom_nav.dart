import 'package:flutter/material.dart';
import '../core/theme.dart';

enum AppNavRole { shopper, merchant }

class _NavItemData {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

/// AppBottomNav provides the unified floating pill bottom navigation bar for all roles.
/// Conforms to specs 3, 4, 7:
/// - Floating rounded pill with level 2 elevation.
/// - Cyan active pill indicator, icon above label.
/// - Exact same size, spacing, elevation, and animations across all screens.
/// - Shopper tabs: Discover, Roam, Stash, Account.
/// - Merchant tabs: Dashboard, Catalog, Analytics, Account.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final AppNavRole role;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.role = AppNavRole.shopper,
  });

  List<_NavItemData> get _items {
    if (role == AppNavRole.shopper) {
      return const [
        _NavItemData(
          label: 'Discover',
          icon: Icons.explore_outlined,
          activeIcon: Icons.explore_rounded,
        ),
        _NavItemData(
          label: 'Roam',
          icon: Icons.map_outlined,
          activeIcon: Icons.map_rounded,
        ),
        _NavItemData(
          label: 'Stash',
          icon: Icons.bookmark_border_rounded,
          activeIcon: Icons.bookmark_rounded,
        ),
        _NavItemData(
          label: 'Account',
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
        ),
      ];
    } else {
      return const [
        _NavItemData(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
        ),
        _NavItemData(
          label: 'Catalog',
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2_rounded,
        ),
        _NavItemData(
          label: 'Analytics',
          icon: Icons.insights_outlined,
          activeIcon: Icons.insights_rounded,
        ),
        _NavItemData(
          label: 'Account',
          icon: Icons.shield_outlined,
          activeIcon: Icons.shield_rounded,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: MarketColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(MarketRadii.pill),
            border: Border.all(
              color: MarketColors.cardBorder,
              width: 1.0,
            ),
            boxShadow: MarketElevation.level2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(MarketRadii.pill),
                    onTap: () => onTap(index),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? MarketColors.primaryContainer.withValues(alpha: 0.22)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(MarketRadii.pill),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.icon,
                              size: 22,
                              color: isSelected
                                  ? MarketColors.primary
                                  : MarketColors.outline,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? MarketColors.onSurface
                                    : MarketColors.outline,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
