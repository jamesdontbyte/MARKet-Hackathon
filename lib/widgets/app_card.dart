import 'package:flutter/material.dart';
import '../core/theme.dart';

/// AppCard implements the standard Level 1 elevation container
/// from design/DESIGN.md: white background, border #F1F5F9,
/// soft diffused shadow, and 16px radius.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Border? border;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MarketSpacing.cardPadding),
    this.margin,
    this.onTap,
    this.color,
    this.border,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(MarketRadii.card);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: content,
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? MarketColors.surfaceContainerLowest,
        borderRadius: borderRadius,
        border: border ?? Border.all(color: MarketColors.cardBorder, width: 1.0),
        boxShadow: MarketElevation.level1,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: content,
      ),
    );
  }
}

/// AppCardElevated implements Level 2 elevation container for prominent
/// cards, modal sheets, and floating highlights.
class AppCardElevated extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double? width;
  final double? height;

  const AppCardElevated({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MarketSpacing.cardPadding),
    this.margin,
    this.onTap,
    this.color,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(MarketRadii.card);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: content,
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? MarketColors.surfaceContainerLowest,
        borderRadius: borderRadius,
        border: Border.all(color: MarketColors.cardBorder, width: 1.0),
        boxShadow: MarketElevation.level2,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: content,
      ),
    );
  }
}
