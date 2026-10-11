import 'package:flutter/material.dart';
import '../core/theme.dart';

/// StatusPill displays status badges such as "Verified MSME",
/// "Open Now", "Pending", or "Redeemed".
class StatusPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final bool isSmall;

  const StatusPill({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    this.isSmall = false,
  });

  /// Factory for the canonical "Verified MSME" badge
  factory StatusPill.verifiedMsme({bool isSmall = false}) {
    return StatusPill(
      label: 'Verified MSME',
      backgroundColor: const Color(0xFFD1FAE5), // soft emerald bg
      textColor: const Color(0xFF065F46), // dark emerald text
      icon: Icons.verified_rounded,
      isSmall: isSmall,
    );
  }

  /// Factory for "Open Now" or "Closed" badge
  factory StatusPill.openStatus({required bool isOpen, bool isSmall = false}) {
    return StatusPill(
      label: isOpen ? 'Open Now' : 'Closed',
      backgroundColor: isOpen
          ? const Color(0xFFDCFCE7)
          : MarketColors.outlineVariant.withValues(alpha: 0.3),
      textColor: isOpen ? const Color(0xFF166534) : MarketColors.outline,
      icon: isOpen ? Icons.circle : Icons.circle_outlined,
      isSmall: isSmall,
    );
  }

  /// Factory for voucher/redemption status
  factory StatusPill.voucherStatus({required String status, bool isSmall = false}) {
    switch (status.toLowerCase()) {
      case 'issued':
      case 'active':
        return StatusPill(
          label: 'Active',
          backgroundColor: const Color(0xFFE0F2FE),
          textColor: const Color(0xFF0369A1),
          icon: Icons.check_circle_outline,
          isSmall: isSmall,
        );
      case 'redeemed':
        return StatusPill(
          label: 'Redeemed',
          backgroundColor: const Color(0xFFF1F5F9),
          textColor: const Color(0xFF475569),
          icon: Icons.done_all,
          isSmall: isSmall,
        );
      case 'expired':
        return StatusPill(
          label: 'Expired',
          backgroundColor: const Color(0xFFFEE2E2),
          textColor: const Color(0xFF991B1B),
          icon: Icons.highlight_off,
          isSmall: isSmall,
        );
      case 'pending':
      default:
        return StatusPill(
          label: 'Pending',
          backgroundColor: const Color(0xFFFEF3C7),
          textColor: const Color(0xFF92400E),
          icon: Icons.hourglass_top,
          isSmall: isSmall,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 10,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(MarketRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: isSmall ? 12 : 14,
              color: textColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
