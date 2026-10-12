import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/promo.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_header.dart';
import 'redeem_store_screen.dart';

/// PromoDetailScreen displays full promotion terms and voucher action.
/// Logs 'viewed' for in-app views; logs 'opened' ONLY when opened from notification tap.
class PromoDetailScreen extends StatefulWidget {
  final Promo? promo;
  final String? promoId;
  final Business? business;
  final bool fromNotification;

  const PromoDetailScreen({
    super.key,
    this.promo,
    this.promoId,
    this.business,
    this.fromNotification = false,
  });

  @override
  State<PromoDetailScreen> createState() => _PromoDetailScreenState();
}

class _PromoDetailScreenState extends State<PromoDetailScreen> {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  Promo? _promo;
  Business? _business;
  bool _isLoading = true;
  bool _isSaved = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPromoData();
  }

  Future<void> _loadPromoData() async {
    try {
      Promo? p = widget.promo;
      if (p == null && widget.promoId != null) {
        p = await _dataService.fetchPromoById(widget.promoId!);
      }

      if (p == null) {
        final activeList = await _dataService.fetchActivePromos();
        if (activeList.isNotEmpty) {
          p = activeList.first;
        }
      }

      if (p != null) {
        _promo = p;
        try {
          _business = widget.business ?? await _dataService.fetchBusinessById(p.businessId);
        } catch (_) {}

        try {
          final uid = _authService.currentUserId;
          if (uid != null) {
            _isSaved = await _dataService.isPromoInStash(uid, p.id);
          }

          // Telemetry Logging:
          // 'opened' ONLY from notification tap; 'viewed' for standard in-app browsing
          final event = widget.fromNotification ? 'opened' : 'viewed';
          await _dataService.logGeofenceEvent(
            eventType: event,
            userId: uid,
            businessId: p.businessId,
            promoId: p.id,
          );
        } catch (_) {}
      } else {
        _errorMessage = 'Promotion not found.';
      }
    } catch (e) {
      if (_promo == null) {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleStash() async {
    final uid = _authService.currentUserId;
    if (uid == null || _promo == null) return;

    setState(() => _isSaving = true);
    try {
      if (_isSaved) {
        await _dataService.removeFromStash(uid, _promo!.id);
        setState(() => _isSaved = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from Stash.')),
          );
        }
      } else {
        await _dataService.saveToStash(uid, _promo!.id);
        setState(() => _isSaved = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to Stash!')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openRedeemStore() {
    if (_promo == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RedeemStoreScreen(
          promo: _promo!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppHeader(
        showBack: true,
        subtitle: 'Promotion',
        trailing: _promo != null
            ? IconButton(
                icon: Icon(
                  _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: _isSaved ? MarketColors.primary : MarketColors.outline,
                  size: 22,
                ),
                tooltip: _isSaved ? 'Remove from Stash' : 'Save to Stash',
                onPressed: _isSaving ? null : _toggleStash,
              )
            : null,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(MarketSpacing.screenMargin),
                      child: Text(_errorMessage!),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MarketSpacing.screenMargin,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Promo Tag & Business Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(MarketRadii.pill),
                            border: Border.all(
                              color: MarketColors.primaryContainer.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            _promo!.valueLabel ?? _promo!.promoType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: MarketColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          _promo!.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: MarketColors.onSurface,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (_business != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.storefront_rounded,
                                  size: 18, color: MarketColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                _business!.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: MarketColors.link,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(MarketRadii.pill),
                                ),
                                child: const Text(
                                  'Verified MSME',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Details Card
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Promotion Details',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: MarketColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _promo!.description ?? 'No specific description provided.',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: MarketColors.onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Divider(color: const Color(0xFFF1F5F9), height: 1),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded,
                                      size: 16, color: MarketColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Valid until ${_formatDate(_promo!.endsAt)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: MarketColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.people_outline_rounded,
                                      size: 16, color: MarketColors.outline),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_promo!.redeemedCount} of ${_promo!.redeemLimit} claimed',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: MarketColors.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        PrimaryButton(
                          width: double.infinity,
                          height: 52,
                          label: 'Redeem at store',
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                          onPressed: _openRedeemStore,
                        ),
                        const SizedBox(height: 12),

                        SecondaryButton(
                          width: double.infinity,
                          height: 50,
                          label: _isSaved ? 'In Stash (Tap to Remove)' : 'Save to Stash',
                          icon: Icon(
                            _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            size: 18,
                            color: MarketColors.primary,
                          ),
                          isLoading: _isSaving,
                          onPressed: _toggleStash,
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}
