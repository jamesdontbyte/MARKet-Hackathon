import 'dart:async';
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

/// StoreQrScreen allows MSME merchants to display a dynamic, rotating QR code
/// and 8-character fallback code that refreshes every 60 seconds with a countdown timer.
/// Includes promo selector when multiple promos are active and a live "Redeemed today" counter.
class StoreQrScreen extends StatefulWidget {
  final Business? business;
  final DataService? dataService;
  final Promo? initialPromo;

  const StoreQrScreen({
    super.key,
    this.business,
    this.dataService,
    this.initialPromo,
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
  int _secondsRemaining = 60;
  int _redeemedTodayCount = 0;

  bool _isLoading = true;
  String? _errorMessage;

  Timer? _countdownTimer;

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
    _countdownTimer?.cancel();
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
              .where((p) => p.active && (now.isAfter(p.startsAt) || now.isAtSameMomentAs(p.startsAt)) && now.isBefore(p.endsAt))
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
        _startTimer();
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
          final sec = codeData['seconds_remaining'];
          _secondsRemaining = (sec is int) ? sec : 60;
        });
      }
    } catch (_) {
      // Retain fallback code if already present
      if (_storeCode == null && _selectedPromo != null) {
        final fallback = _selectedPromo!.id.replaceAll('-', '').substring(0, 8).toUpperCase();
        setState(() {
          _storeCode = fallback;
          _qrPayload = fallback;
          _secondsRemaining = 60;
        });
      }
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        // Window expired, regenerate new rotating code and update today's count
        _secondsRemaining = 60;
        _fetchStoreCode();
        _fetchTodayCount();
      }
    });
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
            tooltip: 'Refresh Store Code',
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

          // Main QR Card
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

                // Visible Countdown Timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _secondsRemaining <= 10
                        ? MarketColors.error.withValues(alpha: 0.1)
                        : const Color(0xFFEFF8FF),
                    borderRadius: BorderRadius.circular(MarketRadii.pill),
                    border: Border.all(
                      color: _secondsRemaining <= 10
                          ? MarketColors.error.withValues(alpha: 0.3)
                          : const Color(0xFFBAE6FD),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: _secondsRemaining <= 10
                            ? MarketColors.error
                            : const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Refreshes in ${_secondsRemaining}s',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _secondsRemaining <= 10
                              ? MarketColors.error
                              : const Color(0xFF0369A1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Large QR Image
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
                  'STORE CODE (60-SECOND WINDOW)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: MarketColors.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: codeDisplay));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Store code copied to clipboard')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: MarketColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MarketColors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          codeDisplay,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4.0,
                            fontFamily: 'monospace',
                            color: MarketColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.copy_rounded, size: 18, color: MarketColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Subtitle Instruction
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Customer can scan this QR code or type the 8-character code in the MARKet app to claim their discount.',
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
