import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_buttons.dart';

/// MerchantWaitingScreen placeholder for merchants awaiting verification.
class MerchantWaitingScreen extends StatelessWidget {
  const MerchantWaitingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
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
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 36,
                  color: Color(0xFFB45309),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Verification in Progress',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: MarketColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your business documents are being reviewed for Antique MSME accreditation. Auto-verification will complete shortly.',
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
                label: 'Check Status / Proceed to Home',
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/merchant-home');
                },
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                width: double.infinity,
                label: 'Log Out',
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/role-selection', (route) => false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
