import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Horizontal 4-step wizard progress component matching Stitch frames
/// (market_msme_registration_step_1_basics, etc.)
class MerchantRegStepper extends StatelessWidget {
  final int currentStep; // 1 to 4

  const MerchantRegStepper({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarketColors.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final stepLabels = ['Basics', 'Business', 'Permits', 'Review'];

          return Stack(
            alignment: Alignment.center,
            children: [
              // Background track
              Positioned(
                top: 15,
                left: 20,
                right: 20,
                child: Container(
                  height: 2,
                  color: MarketColors.surfaceContainerHigh,
                ),
              ),
              // Active fill line
              Positioned(
                top: 15,
                left: 20,
                child: Container(
                  height: 2,
                  width: totalWidth > 40
                      ? ((totalWidth - 40) * ((currentStep - 1) / 3)).clamp(0.0, totalWidth - 40)
                      : 0,
                  color: MarketColors.primaryContainer,
                ),
              ),
              // 4 Step Nodes
              Row(
                children: List.generate(4, (index) {
                  final stepNum = index + 1;
                  final isCompleted = stepNum < currentStep;
                  final isCurrent = stepNum == currentStep;

                  return Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? MarketColors.primary
                                : isCurrent
                                    ? MarketColors.primaryContainer
                                    : MarketColors.surfaceContainer,
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color: MarketColors.primaryContainer.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : Text(
                                    '$stepNum',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                      color: isCurrent
                                          ? MarketColors.onSurface
                                          : MarketColors.outline,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              stepLabels[index],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                color: isCurrent
                                    ? MarketColors.primary
                                    : isCompleted
                                        ? MarketColors.onSurface
                                        : MarketColors.outline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
