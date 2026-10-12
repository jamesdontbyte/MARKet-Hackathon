import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/app_buttons.dart';

/// Placeholder for Merchant Registration (scheduled for Phase 5).
/// Directs the user to login or explore the demo.
class MerchantRegPlaceholderScreen extends StatelessWidget {
  const MerchantRegPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: MarketColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MarketSpacing.screenMargin),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 36,
                  color: MarketColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Merchant Registration',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: MarketColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'MSME Merchant 4-step registration will be unlocked in Phase 5. In the meantime, use the pre-seeded "Demo Merchant" one-tap login.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: MarketColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                width: double.infinity,
                label: 'Go to Log In (Demo Shortcuts)',
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                width: double.infinity,
                label: 'Back to Role Selection',
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/role-selection');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
