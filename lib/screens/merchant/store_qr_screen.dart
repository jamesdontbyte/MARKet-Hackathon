import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../models/business.dart';
import '../../models/promo.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_card.dart';

/// StoreQrScreen displays a static merchant QR code and 8-character code for counter checkout.
/// Shoppers scan or type this code to atomically redeem the promotion in MARKet.
/// Features:
/// - Static QR code + permanent 8-character store code
/// - Promo selector when several promotions are active
/// - "Copy code" button
/// - Live "redeemed today" counter
/// - "Reset QR" button with confirmation calling reset_store_code
class StoreQrScreen extends StatefulWidget {
  final Business? business;
  final Promo? initialPromo;
  final DataService? dataService;

  const StoreQrScreen({
    super.key,
    this.business,
    this.initialPromo,
    this.dataService,
  });

  @override
  State<StoreQrScreen> createState() => _StoreQrScreenState();
}

class _StoreQrScreenState extends State<StoreQrScreen> {
  late final DataService _dataService;
  final AuthService _authService = AuthService();

  Business? _business;
  List<Promo> _activePromos = [];
  Promo? _selectedPromo;

  String? _storeCode;
  String? _qrPayload;
  int _redeemedTodayCount = 0;

  bool _isLoading = true;
  bool _isResetting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dataService = widget.dataService ?? DataService();
    _business = widget.business;
    _selectedPromo = widget.initialPromo;
    _initializeStore();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeStore() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_business == null) {
        final uid = _authService.currentUserId;
        if (uid != null) {
          _business = await _dataService.fetchMerchantBusiness(uid);
        }
      }

      if (_business != null) {
        try {
          final allPromos = await _dataService.fetchPromosForBusiness(_business!.id);
          final now = DateTime.now().toUtc();
          _activePromos = allPromos
              .where((p) =>
                  p.active &&
                  (now.isAfter(p.startsAt) || now.isAtSameMomentAs(p.startsAt)) &&
                  now.isBefore(p.endsAt))
              .toList();
        } catch (_) {}

        if (_activePromos.isEmpty && widget.initialPromo != null) {
          _activePromos = [widget.initialPromo!];
        }

        if (_selectedPromo != null) {
          final found = _activePromos.where((p) => p.id == _selectedPromo!.id).firstOrNull;
          _selectedPromo = found ?? (_activePromos.isNotEmpty ? _activePromos.first : widget.initialPromo);
        } else if (_activePromos.isNotEmpty) {
          _selectedPromo = _activePromos.first;
        }

        await _fetchTodayCount();
      } else if (widget.initialPromo != null) {
        _activePromos = [widget.initialPromo!];
        _selectedPromo = widget.initialPromo;
      }

      if (_selectedPromo != null) {
        await _fetchStoreCode();
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchTodayCount() async {
    if (_business == null) return;
    try {
      final count = await _dataService.fetchTodayRedemptionsCount(
        _business!.id,
        _selectedPromo?.id,
      );
      if (mounted) {
        setState(() {
          _redeemedTodayCount = count;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchStoreCode() async {
    if (_selectedPromo == null) return;
    try {
      final codeData = await _dataService.getStoreCode(_selectedPromo!.id);
      if (mounted) {
        setState(() {
          _storeCode = codeData['code'] as String?;
          _qrPayload = codeData['qr_payload'] as String? ?? _storeCode;
        });
      }
    } catch (_) {
      if (mounted && _selectedPromo != null) {
        final fallback = _selectedPromo!.id.replaceAll('-', '').substring(0, 8).toUpperCase();
        setState(() {
          _storeCode = fallback;
          _qrPayload = fallback;
        });
      }
    }
  }

  Future<void> _confirmAndResetCode() async {
    if (_selectedPromo == null || _isResetting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.refresh_rounded, color: MarketColors.primary),
            SizedBox(width: 8),
            Text('Reset Store QR?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Generate a new static QR code for "${_selectedPromo!.title}"?\n\nThe previous code will be invalidated immediately.',
          style: const TextStyle(fontSize: 14, color: MarketColors.onSurfaceVariant, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: MarketColors.secondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MarketColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset Code'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isResetting = true;
    });

    try {
      final res = await _dataService.resetStoreCode(_selectedPromo!.id);
      if (mounted) {
        setState(() {
          _storeCode = res['code'] as String?;
          _qrPayload = res['qr_payload'] as String? ?? _storeCode;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New store QR code generated successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset code: $e'),
            backgroundColor: MarketColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  void _copyCodeToClipboard() {
    final code = _storeCode ?? '';
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Code "$code" copied to clipboard!'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onPromoSelected(Promo promo) {
    if (_selectedPromo?.id == promo.id) return;
    setState(() {
      _selectedPromo = promo;
      _storeCode = null;
      _qrPayload = null;
    });
    _fetchStoreCode();
    _fetchTodayCount();
  }

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Store Checkout QR',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MarketColors.onSurface,
              ),
            ),
            if (_business != null)
              Text(
                _business!.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: MarketColors.secondary,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: MarketColors.primary),
            tooltip: 'Refresh',
            onPressed: () {
              _fetchStoreCode();
              _fetchTodayCount();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorView()
                : _activePromos.isEmpty
                    ? _buildNoPromosView()
                    : _buildQrContent(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MarketSpacing.screenMargin),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: MarketColors.error),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: MarketColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Retry',
              onPressed: _initializeStore,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPromosView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MarketSpacing.screenMargin),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: MarketColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_offer_outlined, size: 36, color: MarketColors.outline),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Active Promotions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MarketColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create and launch an active promotion in your catalog to generate a store checkout QR code for shoppers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: MarketColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Back to Promotions',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrContent() {
    final codeDisplay = _storeCode ?? '••••••••';
    final payload = _qrPayload ?? codeDisplay;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(MarketSpacing.screenMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Promo Selector (when multiple promos are active)
          if (_activePromos.length > 1) ...[
            const Text(
              'Select Active Promo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MarketColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _activePromos.map((p) {
                  final isSelected = p.id == _selectedPromo?.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text('${p.valueLabel ?? p.promoType.toUpperCase()}: ${p.title}'),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? MarketColors.onPrimary : MarketColors.onSurface,
                      ),
                      selectedColor: MarketColors.primary,
                      backgroundColor: MarketColors.surfaceContainerLow,
                      checkmarkColor: MarketColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? MarketColors.primary : MarketColors.outlineVariant,
                        ),
                      ),
                      onSelected: (_) => _onPromoSelected(p),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Main Static QR Card
          AppCardElevated(
            child: Column(
              children: [
                // Promo Badge & Title
                if (_selectedPromo != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(MarketRadii.pill),
                      border: Border.all(
                        color: MarketColors.primaryContainer.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _selectedPromo!.valueLabel ?? _selectedPromo!.promoType.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: MarketColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedPromo!.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Static QR Code
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MarketColors.fieldBorder, width: 1.5),
                    boxShadow: MarketElevation.level1,
                  ),
                  child: QrImageView(
                    data: payload,
                    version: QrVersions.auto,
                    size: 220,
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
                const SizedBox(height: 18),

                // 8-character Code
                const Text(
                  'STORE CODE (STATIC)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: MarketColors.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: MarketColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MarketColors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    codeDisplay,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.0,
                      fontFamily: 'monospace',
                      color: MarketColors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Copy Code & Reset QR Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: MarketColors.primary.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16, color: MarketColors.primary),
                      label: const Text(
                        'Copy code',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MarketColors.primary),
                      ),
                      onPressed: _copyCodeToClipboard,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: MarketColors.outlineVariant.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      icon: _isResetting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16, color: MarketColors.secondary),
                      label: const Text(
                        'Reset QR',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: MarketColors.secondary),
                      ),
                      onPressed: _isResetting ? null : _confirmAndResetCode,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Subtitle Instruction
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Customer can scan this static QR code or type the 8-character code in the MARKet app to claim their discount.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: MarketColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live "Redeemed Today" Counter Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MarketColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MarketColors.cardBorder),
              boxShadow: MarketElevation.level1,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF16A34A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Redeemed Today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MarketColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_redeemedTodayCount customer${_redeemedTodayCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: MarketColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.sync_rounded, color: MarketColors.outline, size: 20),
                  tooltip: 'Refresh count',
                  onPressed: _fetchTodayCount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Backward compatibility alias for any existing references
typedef MerchantScanScreen = StoreQrScreen;
