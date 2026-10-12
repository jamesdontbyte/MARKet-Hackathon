import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme.dart';
import '../../models/promo.dart';
import '../../models/redemption.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_card.dart';

/// VoucherScreen renders the 8-character promo code and big QR code.
/// Idempotently creates/fetches the redemption row and logs 'claimed' on first issue.
class VoucherScreen extends StatefulWidget {
  final Promo promo;
  final String? businessName;
  final Redemption? initialRedemption;

  const VoucherScreen({
    super.key,
    required this.promo,
    this.businessName,
    this.initialRedemption,
  });

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  Redemption? _redemption;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialRedemption != null) {
      _redemption = widget.initialRedemption;
      _isLoading = false;
    } else {
      _issueOrLoadVoucher();
    }
  }

  Future<void> _issueOrLoadVoucher() async {
    final uid = _authService.currentUserId;
    if (uid == null) {
      setState(() {
        _errorMessage = 'Please sign in to claim vouchers.';
        _isLoading = false;
      });
      return;
    }

    try {
      final r = await _dataService.getOrCreateVoucher(
        userId: uid,
        promoId: widget.promo.id,
        businessId: widget.promo.businessId,
      );
      if (mounted) {
        setState(() {
          _redemption = r;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Your Voucher',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MarketColors.onSurface,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: MarketColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(MarketSpacing.screenMargin),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 48, color: MarketColors.error),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: MarketColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            label: 'Retry',
                            onPressed: _issueOrLoadVoucher,
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(MarketSpacing.screenMargin),
                    child: Column(
                      children: [
                        AppCardElevated(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Promo Value Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(MarketRadii.pill),
                                  border: Border.all(
                                    color: MarketColors.primaryContainer.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  widget.promo.valueLabel ?? widget.promo.promoType.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: MarketColors.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Promo Title
                              Text(
                                widget.promo.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: MarketColors.onSurface,
                                  height: 1.3,
                                ),
                              ),
                              if (widget.businessName != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.businessName!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: MarketColors.link,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),

                              // QR Code Container
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: MarketColors.fieldBorder,
                                    width: 1.5,
                                  ),
                                  boxShadow: MarketElevation.level1,
                                ),
                                child: QrImageView(
                                  data: _redemption!.code,
                                  version: QrVersions.auto,
                                  size: 200,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Color(0xFF0B1C30),
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Color(0xFF0B1C30),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 8-character Code Display
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: MarketColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: MarketColors.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  _redemption!.code,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3.0,
                                    color: MarketColors.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _redemption!.isRedeemed
                                      ? MarketColors.surfaceContainerHigh
                                      : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(MarketRadii.pill),
                                ),
                                child: Text(
                                  _redemption!.isRedeemed ? 'Redeemed' : 'Active • Valid',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _redemption!.isRedeemed
                                        ? MarketColors.secondary
                                        : const Color(0xFF15803D),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Divider(color: const Color(0xFFF1F5F9), height: 1),
                              const SizedBox(height: 14),

                              // Instructions
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Icon(Icons.storefront_rounded,
                                      size: 18, color: MarketColors.primary),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Present this QR code or 8-character code to the cashier in-store for verification.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: MarketColors.onSurfaceVariant,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        SecondaryButton(
                          width: double.infinity,
                          label: 'Done / Back',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
