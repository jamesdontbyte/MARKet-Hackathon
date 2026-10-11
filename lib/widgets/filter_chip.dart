import 'package:flutter/material.dart';
import '../core/theme.dart';

/// AppFilterChip provides a themed pill chip for category selection,
/// interest onboarding, and status filters.
/// Ensures min 48dp interactive touch target and distinct active/inactive states.
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final Widget? icon;
  final bool showCheckmark;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onSelected,
    this.icon,
    this.showCheckmark = false,
  });

  @override
  Widget build(BuildContext context) {
    final isInteractive = onSelected != null;

    final bgColor = isSelected
        ? MarketColors.primary
        : MarketColors.surfaceContainerLowest;
    final fgColor = isSelected ? Colors.white : MarketColors.onSurface;
    final borderColor = isSelected
        ? MarketColors.primary
        : MarketColors.outlineVariant;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(MarketRadii.pill),
            onTap: isInteractive ? () => onSelected!(!isSelected) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isInteractive
                    ? bgColor
                    : bgColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(MarketRadii.pill),
                border: Border.all(
                  color: isInteractive
                      ? borderColor
                      : borderColor.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                boxShadow: isSelected ? MarketElevation.level1 : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 6),
                  ] else if (showCheckmark && isSelected) ...[
                    const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isInteractive
                          ? fgColor
                          : fgColor.withValues(alpha: 0.5),
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
  }
}
