import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Custom painter for dashed rounded border
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    this.dashWidth = 4.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        final extract = metric.extractPath(distance, next > metric.length ? metric.length : next);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}

/// PromoBadge displays discount tags and deal highlights with a dashed border
/// (#BAE6FD), soft ice blue fill (#F0F9FF), and deep cyan text (#0369A1).
class PromoBadge extends StatelessWidget {
  final String label;
  final Widget? icon;
  final bool isSmall;

  const PromoBadge({
    super.key,
    required this.label,
    this.icon,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 8.0;

    return CustomPaint(
      painter: _DashedBorderPainter(
        color: MarketColors.promoBadgeBorder,
        strokeWidth: 1.2,
        radius: radius,
        dashWidth: 4,
        dashSpace: 3,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 8 : 10,
          vertical: isSmall ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: MarketColors.promoBadgeBg,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 4),
            ] else ...[
              const Icon(
                Icons.local_offer_rounded,
                size: 13,
                color: MarketColors.promoBadgeText,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: isSmall ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: MarketColors.promoBadgeText,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
