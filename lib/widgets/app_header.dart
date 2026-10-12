import 'package:flutter/material.dart';
import '../core/theme.dart';

/// AppHeader provides the unified header across all screens in MARKet.
/// Conforms to specs 3, 4, 5, 8:
/// - Logo (`assets/logos/logo_icon.png`) + "MARKet" dual-tone wordmark on the left.
/// - Long-press on "MARK" retained for shopper simulation/debug launcher.
/// - Optional subtitle slot for screen-specific title (e.g. "Stash") keeping header height fixed at 56dp.
/// - Bell icon and optional role-specific trailing action on the right.
/// - Optional back button for pushed detail screens; omitted on tab screens.
/// - Fixed height, padding, elevation, background, and safe-area handling on every screen.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBackPressed;
  final VoidCallback? onMarkLongPress;
  final VoidCallback? onBellPressed;
  final Widget? trailing;

  const AppHeader({
    super.key,
    this.subtitle,
    this.showBack = false,
    this.onBackPressed,
    this.onMarkLongPress,
    this.onBellPressed,
    this.trailing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      decoration: const BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: MarketColors.cardBorder,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: SizedBox(
            height: preferredSize.height,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MarketSpacing.screenMargin,
              ),
              child: Row(
              children: [
                // Back arrow for detail screens
                if (showBack) ...[
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: MarketColors.onSurface,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: onBackPressed ?? () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                ],

                // Logo icon
                Image.asset(
                  'assets/logos/logo_icon.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.storefront_rounded,
                    size: 24,
                    color: MarketColors.primary,
                  ),
                ),
                const SizedBox(width: 8),

                // Dual-tone wordmark "MARKet"
                GestureDetector(
                  onLongPress: onMarkLongPress,
                  behavior: HitTestBehavior.opaque,
                  child: const Text(
                    'MARK',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: MarketColors.primaryContainer,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const Text(
                  'et',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: MarketColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),

                // Optional subtitle slot (e.g., "Stash", "Catalog", etc.)
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 16,
                    color: MarketColors.cardBorder,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MarketColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  const Spacer(),
                ],

                // Notification Bell
                IconButton(
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: MarketColors.onSurfaceVariant,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  tooltip: 'Notifications',
                  onPressed: onBellPressed ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Hyperlocal promo notifications are delivered directly to your device.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                ),

                // Optional role-specific trailing widget
                if (trailing != null) ...[
                  const SizedBox(width: 4),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
