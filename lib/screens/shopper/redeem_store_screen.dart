import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme.dart';
import '../../models/promo.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_text_field.dart';

enum StoreRedemptionStatus {
  ok,
  invalid,
  expiredCode,
  alreadyRedeemed,
  expired,
  limitReached,
}

class StoreRedemptionResult {
  final StoreRedemptionStatus status;
  final String code;
  final String rawStatus;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const StoreRedemptionResult({
    required this.status,
    required this.code,
    required this.rawStatus,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });

  factory StoreRedemptionResult.fromStatus(String code, String status) {
    final clean = code.trim().toUpperCase();
    switch (status) {
      case 'ok':
        return StoreRedemptionResult(
          status: StoreRedemptionStatus.ok,
          code: clean,
          rawStatus: status,
          title: 'Voucher Redeemed!',
          message:
              'Promotion successfully redeemed at the counter! The merchant discount has been verified and applied.',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF16A34A),
          bgColor: const Color(0xFFDCFCE7),
          borderColor: const Color(0xFF86EFAC),
        );
      case 'expired_code':
        return StoreRedemptionResult(
          status: StoreRedemptionStatus.expiredCode,
          code: clean,
          rawStatus: status,
          title: 'Store Code Expired',
          message:
              'The dynamic store QR code has rotated past its 60-second window. Ask the cashier to show their current QR code.',
          icon: Icons.update_disabled_rounded,
          color: const Color(0xFFEA580C),
          bgColor: const Color(0xFFFFEDD5),
          borderColor: const Color(0xFFFDBA74),
        );
      case 'already_redeemed':
        return StoreRedemptionResult(
          status: StoreRedemptionStatus.alreadyRedeemed,
          code: clean,
          rawStatus: status,
          title: 'Already Redeemed',
          message:
              'You have already redeemed your voucher for this promotional offer. Each voucher can only be used once.',
          icon: Icons.history_rounded,
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFEF3C7),
          borderColor: const Color(0xFFFCD34D),
        );
      case 'expired':
        return StoreRedemptionResult(
          status: StoreRedemptionStatus.expired,
          code: clean,
          rawStatus: status,
          title: 'Promotion Expired',
          message:
              'This promotional campaign period has ended and is no longer active at this store.',
          icon: Icons.timer_off_rounded,
          color: const Color(0xFF64748B),
          bgColor: const Color(0xFFF1F5F9),
          borderColor: const Color(0xFFCBD5E1),
        );
      case 'limit_reached':
        return StoreRedemptionResult(
          status: StoreRedemptionStatus.limitReached,
          code: clean,
          rawStatus: status,
          title: 'Campaign Limit Reached',
          message:
              'All available voucher redemption quotas for this promotional campaign have already been claimed.',
          icon: Icons.group_off_rounded,
          color: const Color(0xFFE11D48),
          bgColor: const Color(0xFFFFE4E6),
          borderColor: const Color(0xFFFDA4AF),
        );
      case 'invalid':
      default:
        return StoreRedemptionResult(
          status: StoreRedemptionStatus.invalid,
          code: clean,
          rawStatus: status,
          title: 'Invalid Store Code',
          message:
              'No active store promotion matched this code. Please check the screen or try scanning again.',
          icon: Icons.cancel_rounded,
          color: const Color(0xFFDC2626),
          bgColor: const Color(0xFFFEE2E2),
          borderColor: const Color(0xFFFCA5A5),
        );
    }
  }
}

/// RedeemStoreScreen allows shoppers to redeem a promo at the merchant counter
/// using three options: (a) live camera scan, (b) gallery QR image upload, (c) 8-char manual typing.
class RedeemStoreScreen extends StatefulWidget {
  final Promo? promo;
  final DataService? dataService;

  const RedeemStoreScreen({
    super.key,
    this.promo,
    this.dataService,
  });

  @override
  State<RedeemStoreScreen> createState() => _RedeemStoreScreenState();
}

class _RedeemStoreScreenState extends State<RedeemStoreScreen> {
  late final DataService _dataService;
  late final MobileScannerController _scannerController;
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isManualMode = false;
  bool _isProcessing = false;
  bool _cameraPermissionDenied = false;
  bool _torchOn = false;
  DateTime? _lastScanTime;
  StoreRedemptionResult? _result;
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
      return; // Debounce
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
      final status = await _dataService.redeemAtStore(rawCode);
      if (mounted) {
        setState(() {
          _result = StoreRedemptionResult.fromStatus(rawCode, status);
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  Future<void> _pickImageAndScan() async {
    if (_isProcessing) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (pickerResult == null ||
          pickerResult.files.isEmpty ||
          pickerResult.files.single.path == null) {
        return;
      }

      setState(() {
        _isProcessing = true;
      });

      final filePath = pickerResult.files.single.path!;
      final capture = await _scannerController.analyzeImage(filePath);

      if (capture == null ||
          capture.barcodes.isEmpty ||
          capture.barcodes.first.rawValue == null ||
          capture.barcodes.first.rawValue!.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _errorMessage = 'No QR code found, try again';
          });
        }
        return;
      }

      final detectedCode = capture.barcodes.first.rawValue!;
      await _redeem(detectedCode);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'No QR code found, try again';
        });
      }
    }
  }

  void _onManualSubmit() {
    if (!_formKey.currentState!.validate()) return;
    _redeem(_codeController.text.trim());
  }

  void _resetScan() {
    setState(() {
      _result = null;
      _errorMessage = null;
      _codeController.clear();
      _isProcessing = false;
    });
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
          onPressed: () => Navigator.of(context).pop(_result?.status == StoreRedemptionStatus.ok),
        ),
        title: const Text(
          'Redeem at Store',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MarketColors.onSurface,
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(
              _isManualMode ? Icons.qr_code_scanner_rounded : Icons.keyboard_outlined,
              size: 18,
              color: MarketColors.primary,
            ),
            label: Text(
              _isManualMode ? 'Scanner' : 'Type Code',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MarketColors.primary,
              ),
            ),
            onPressed: () {
              setState(() {
                _isManualMode = !_isManualMode;
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _result != null
            ? _buildResultCard(_result!)
            : _isManualMode
                ? _buildManualInputView()
                : _buildScannerView(),
      ),
    );
  }

  Widget _buildScannerView() {
    return Column(
      children: [
        // Camera Viewport or Permission Fallback
        Expanded(
          flex: 5,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: MarketSpacing.screenMargin),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: MarketColors.outlineVariant.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!_cameraPermissionDenied)
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                    errorBuilder: (ctx, error, child) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_cameraPermissionDenied) {
                          setState(() {
                            _cameraPermissionDenied = true;
                          });
                        }
                      });
                      return _buildCameraFallback();
                    },
                  )
                else
                  _buildCameraFallback(),

                // Viewfinder Target Overlay
                if (!_cameraPermissionDenied)
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(width: 24, height: 4, color: MarketColors.primaryContainer),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(width: 24, height: 4, color: MarketColors.primaryContainer),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(width: 24, height: 4, color: MarketColors.primaryContainer),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(width: 24, height: 4, color: MarketColors.primaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Torch & Flip Action Buttons
                if (!_cameraPermissionDenied)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Row(
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.5),
                          ),
                          icon: Icon(
                            _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _scannerController.toggleTorch();
                            setState(() {
                              _torchOn = !_torchOn;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.5),
                          ),
                          icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                          onPressed: () => _scannerController.switchCamera(),
                        ),
                      ],
                    ),
                  ),

                if (_isProcessing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MarketSpacing.screenMargin),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MarketColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MarketColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: MarketColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MarketColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Bottom Action Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MarketSpacing.screenMargin),
          child: Column(
            children: [
              // Option (b): Upload from gallery button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: MarketColors.primaryContainer.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MarketRadii.button)),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 20, color: MarketColors.primary),
                label: const Text(
                  'Upload QR from Gallery',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.primary,
                  ),
                ),
                onPressed: _pickImageAndScan,
              ),
              const SizedBox(height: 10),

              // Option (c): Type manual code button
              SecondaryButton(
                width: double.infinity,
                height: 50,
                icon: const Icon(Icons.keyboard_outlined, size: 20),
                label: 'Type 8-Character Code',
                onPressed: () {
                  setState(() {
                    _isManualMode = true;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Hold camera steady in front of the merchant\'s store QR code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: MarketColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraFallback() {
    return Container(
      color: MarketColors.surfaceContainerLow,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_outlined, color: MarketColors.error, size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              'Camera Not Available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MarketColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Camera access was denied or is unavailable. You can still upload a QR image from your gallery or type the code below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: MarketColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MarketSpacing.screenMargin),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MarketColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MarketColors.cardBorder),
                boxShadow: MarketElevation.level1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: MarketColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.keyboard_outlined,
                          color: MarketColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Enter Store Code',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: MarketColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ask the store cashier for the 8-character code displayed under their store QR code.',
                    style: TextStyle(
                      fontSize: 13,
                      color: MarketColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  AppTextField(
                    controller: _codeController,
                    label: '8-Character Store Code',
                    hintText: 'e.g. KT8924B1',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      LengthLimitingTextInputFormatter(8),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().length < 6) {
                        return 'Please enter a valid 8-character code';
                      }
                      return null;
                    },
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MarketColors.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  PrimaryButton(
                    width: double.infinity,
                    height: 52,
                    label: 'Redeem Code',
                    isLoading: _isProcessing,
                    onPressed: _onManualSubmit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: MarketColors.primaryContainer.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MarketRadii.button)),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: MarketColors.primary),
              label: const Text(
                'Switch Back to Camera Scanner',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MarketColors.primary,
                ),
              ),
              onPressed: () {
                setState(() {
                  _isManualMode = false;
                  _errorMessage = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(StoreRedemptionResult result) {
    final isSuccess = result.status == StoreRedemptionStatus.ok;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MarketSpacing.screenMargin),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: result.bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: result.borderColor, width: 2),
            boxShadow: MarketElevation.level2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: result.borderColor, width: 2),
                ),
                child: Icon(result.icon, size: 36, color: result.color),
              ),
              const SizedBox(height: 16),
              Text(
                result.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: result.color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                result.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: MarketColors.onSurface,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // Code Display Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: result.borderColor),
                ),
                child: Text(
                  'Code: ${result.code}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: MarketColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (isSuccess) ...[
                PrimaryButton(
                  width: double.infinity,
                  height: 48,
                  label: 'View Redeemed Voucher',
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ] else ...[
                PrimaryButton(
                  width: double.infinity,
                  height: 48,
                  label: 'Try Again',
                  onPressed: _resetScan,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel / Back',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MarketColors.secondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
