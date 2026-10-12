import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme.dart';
import '../../models/business.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_text_field.dart';

enum RedemptionStatus {
  ok,
  invalid,
  notYourPromo,
  alreadyRedeemed,
  expired,
  limitReached,
  error,
}

class RedemptionResult {
  final RedemptionStatus status;
  final String code;
  final String rawStatusCode;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const RedemptionResult({
    required this.status,
    required this.code,
    required this.rawStatusCode,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });

  factory RedemptionResult.fromCode(String code, String status) {
    final clean = code.trim().toUpperCase();
    switch (status) {
      case 'ok':
        return RedemptionResult(
          status: RedemptionStatus.ok,
          code: clean,
          rawStatusCode: status,
          title: 'Voucher Redeemed!',
          message:
              'Promotion voucher successfully verified and redeemed. Customer discount can be applied at checkout.',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF16A34A),
          bgColor: const Color(0xFFDCFCE7),
          borderColor: const Color(0xFF86EFAC),
        );
      case 'already_redeemed':
        return RedemptionResult(
          status: RedemptionStatus.alreadyRedeemed,
          code: clean,
          rawStatusCode: status,
          title: 'Voucher Already Redeemed',
          message:
              'This voucher has already been claimed and used. Vouchers can only be redeemed once.',
          icon: Icons.history_rounded,
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFEF3C7),
          borderColor: const Color(0xFFFCD34D),
        );
      case 'not_your_promo':
        return RedemptionResult(
          status: RedemptionStatus.notYourPromo,
          code: clean,
          rawStatusCode: status,
          title: 'Different Merchant Promotion',
          message:
              'This voucher belongs to a different MSME store or business in San Jose de Buenavista.',
          icon: Icons.storefront_rounded,
          color: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFF3E8FF),
          borderColor: const Color(0xFFD8B4FE),
        );
      case 'expired':
        return RedemptionResult(
          status: RedemptionStatus.expired,
          code: clean,
          rawStatusCode: status,
          title: 'Promotion Has Expired',
          message:
              'The promotional period for this offer has ended or is no longer active.',
          icon: Icons.timer_off_rounded,
          color: const Color(0xFF64748B),
          bgColor: const Color(0xFFF1F5F9),
          borderColor: const Color(0xFFCBD5E1),
        );
      case 'limit_reached':
        return RedemptionResult(
          status: RedemptionStatus.limitReached,
          code: clean,
          rawStatusCode: status,
          title: 'Redemption Limit Reached',
          message:
              'All available vouchers for this promotional campaign quota have already been claimed.',
          icon: Icons.group_off_rounded,
          color: const Color(0xFFE11D48),
          bgColor: const Color(0xFFFFE4E6),
          borderColor: const Color(0xFFFDA4AF),
        );
      case 'invalid':
      default:
        return RedemptionResult(
          status: RedemptionStatus.invalid,
          code: clean,
          rawStatusCode: status,
          title: 'Invalid Voucher Code',
          message:
              'No active voucher found with this 8-character code. Please double-check for typos.',
          icon: Icons.cancel_rounded,
          color: const Color(0xFFDC2626),
          bgColor: const Color(0xFFFEE2E2),
          borderColor: const Color(0xFFFCA5A5),
        );
    }
  }
}

/// MerchantScanScreen provides camera QR scanning via mobile_scanner with an 8-character
/// manual fallback. Atomic redemption calls DataService.redeemVoucher (RPC) with debounce.
class MerchantScanScreen extends StatefulWidget {
  final Business? business;
  final DataService? dataService;

  const MerchantScanScreen({
    super.key,
    this.business,
    this.dataService,
  });

  @override
  State<MerchantScanScreen> createState() => _MerchantScanScreenState();
}

class _MerchantScanScreenState extends State<MerchantScanScreen> {
  late final DataService _dataService;
  late final MobileScannerController _scannerController;
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isManualMode = false;
  bool _isProcessing = false;
  bool _cameraPermissionDenied = false;
  bool _torchOn = false;
  DateTime? _lastScanTime;
  RedemptionResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dataService = widget.dataService ?? DataService();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _result != null) return;

    final now = DateTime.now();
    if (_lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < 1500) {
      return; // Debounce rapid scans
    }

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    _lastScanTime = now;
    _redeem(rawValue);
  }

  Future<void> _redeem(String rawCode) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Pause camera stream while validating
      try {
        await _scannerController.stop();
      } catch (_) {}

      final cleanCode = rawCode.trim().toUpperCase();
      final status = await _dataService.redeemVoucher(cleanCode);

      if (mounted) {
        setState(() {
          _result = RedemptionResult.fromCode(cleanCode, status);
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              'Redemption failed: ${e.toString().replaceAll("Exception:", "").trim()}';
        });
      }
    }
  }

  void _submitManual() {
    if (_formKey.currentState?.validate() != true) return;
    final code = _codeController.text.trim().toUpperCase();
    _redeem(code);
  }

  void _resetScan() {
    setState(() {
      _result = null;
      _errorMessage = null;
      _codeController.clear();
    });

    if (!_isManualMode && !_cameraPermissionDenied) {
      try {
        _scannerController.start();
      } catch (_) {}
    }
  }

  void _toggleTorch() {
    setState(() {
      _torchOn = !_torchOn;
    });
    try {
      _scannerController.toggleTorch();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bizName = widget.business?.name ?? 'Store';

    return Scaffold(
      backgroundColor: MarketColors.surface,
      appBar: AppBar(
        backgroundColor: MarketColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Redeem Customer Voucher',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: MarketColors.onSurface,
              ),
            ),
            Text(
              bizName,
              style: const TextStyle(
                fontSize: 12,
                color: MarketColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isManualMode && !_cameraPermissionDenied && _result == null)
            IconButton(
              icon: Icon(
                _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _torchOn ? MarketColors.primary : MarketColors.outline,
              ),
              onPressed: _toggleTorch,
              tooltip: 'Toggle Flash',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Segmented Switch (Scanner vs Manual 8-char Code)
            if (_result == null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MarketSpacing.screenMargin,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: MarketColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_cameraPermissionDenied) return;
                            setState(() {
                              _isManualMode = false;
                              _errorMessage = null;
                            });
                            try {
                              _scannerController.start();
                            } catch (_) {}
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_isManualMode
                                  ? MarketColors.surfaceContainerLowest
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !_isManualMode
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x0A0F172A),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 16,
                                  color: !_isManualMode
                                      ? MarketColors.primary
                                      : MarketColors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'QR Camera',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: !_isManualMode
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: !_isManualMode
                                        ? MarketColors.primary
                                        : MarketColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isManualMode = true;
                              _errorMessage = null;
                            });
                            try {
                              _scannerController.stop();
                            } catch (_) {}
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _isManualMode
                                  ? MarketColors.surfaceContainerLowest
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _isManualMode
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x0A0F172A),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.keyboard_rounded,
                                  size: 16,
                                  color: _isManualMode
                                      ? MarketColors.primary
                                      : MarketColors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Enter Code',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _isManualMode
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: _isManualMode
                                        ? MarketColors.primary
                                        : MarketColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Main Content: Result Card OR Scanner/Manual Input
            Expanded(
              child: _result != null
                  ? _buildResultView(_result!)
                  : _isProcessing
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'Verifying Voucher with Supabase...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: MarketColors.onSurface,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Checking merchant ownership & quota',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: MarketColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : (_isManualMode || _cameraPermissionDenied)
                          ? _buildManualEntryView()
                          : _buildCameraScannerView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraScannerView() {
    return Padding(
      padding: const EdgeInsets.all(MarketSpacing.screenMargin),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                    errorBuilder: (context, error, child) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_cameraPermissionDenied) {
                          setState(() {
                            _cameraPermissionDenied = true;
                            _isManualMode = true;
                          });
                        }
                      });
                      return Container(
                        color: MarketColors.surfaceContainerLow,
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.no_photography_rounded,
                              size: 48,
                              color: MarketColors.outline,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Camera Unavailable',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: MarketColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Camera permission denied or camera device is in use. Please enter the 8-character voucher code manually.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: MarketColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isManualMode = true;
                                });
                              },
                              child: const Text('Switch to Manual Entry'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Scanner Reticle Overlay
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: MarketColors.primaryContainer,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: MarketColors.primaryContainer
                                .withValues(alpha: 0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Helper Instruction Pill
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Align customer voucher QR code inside the frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Fallback to manual entry link
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isManualMode = true;
              });
              try {
                _scannerController.stop();
              } catch (_) {}
            },
            icon: const Icon(Icons.keyboard_rounded, size: 18),
            label: const Text(
              'Having trouble scanning? Enter code manually',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MarketSpacing.screenMargin),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_cameraPermissionDenied)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Camera unavailable or permission denied. Enter code manually below.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: MarketColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    offset: Offset(0, 4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pin_rounded,
                          color: MarketColors.primary, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Manual Code Verification',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the 8-character alphanumeric voucher code displayed beneath the customer’s QR code in their Stash.',
                    style: TextStyle(
                      fontSize: 13,
                      color: MarketColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    controller: _codeController,
                    label: '8-Character Voucher Code *',
                    hintText: 'e.g. KT8X29Q1',
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      LengthLimitingTextInputFormatter(8),
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Voucher code is required';
                      }
                      if (val.trim().length < 6) {
                        return 'Code must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    width: double.infinity,
                    height: 50,
                    label: _isProcessing ? 'Verifying Code...' : 'Verify & Redeem',
                    isLoading: _isProcessing,
                    icon: const Icon(Icons.verified_rounded, size: 20),
                    onPressed: _isProcessing ? null : _submitManual,
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(RedemptionResult result) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MarketSpacing.screenMargin),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: result.bgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: result.borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: result.color.withValues(alpha: 0.1),
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              children: [
                // Icon Beacon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: result.color.withValues(alpha: 0.2),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Icon(result.icon, size: 40, color: result.color),
                ),
                const SizedBox(height: 16),

                // Status Title
                Text(
                  result.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: result.color,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Code Display Tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: result.borderColor),
                  ),
                  child: Text(
                    result.code,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: MarketColors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  result.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: MarketColors.onSurface.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // Action Button
                PrimaryButton(
                  width: double.infinity,
                  height: 48,
                  label: result.status == RedemptionStatus.ok
                      ? 'Scan Next Voucher'
                      : 'Scan Another Code',
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  onPressed: _resetScan,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Return to promotions button
          SecondaryButton(
            width: double.infinity,
            height: 48,
            label: 'Back to Promotions',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
