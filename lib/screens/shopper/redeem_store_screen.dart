import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme.dart';
import '../../models/promo.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/promo_photo_view.dart';

enum StoreRedemptionStatus {
  ok,
  invalid,
  alreadyRedeemed,
  expired,
  limitReached,
}

enum RedeemInputOption {
  camera,
  upload,
  typeCode,
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
          title: 'Promotion Redeemed!',
          message:
              'Promotion successfully redeemed at the counter! The merchant discount has been verified and applied.',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF16A34A),
          bgColor: const Color(0xFFDCFCE7),
          borderColor: const Color(0xFF86EFAC),
        );
      case 'already_redeemed':
        return StoreRedemptionResult(
          status: StoreRedemptionStatus.alreadyRedeemed,
          code: clean,
          rawStatus: status,
          title: 'Already Redeemed',
          message:
              'You have already redeemed your voucher for this promotional offer. Each customer can only redeem once.',
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
              'No active store promotion matched this code. Please check the merchant screen or try scanning again.',
          icon: Icons.cancel_rounded,
          color: const Color(0xFFDC2626),
          bgColor: const Color(0xFFFEE2E2),
          borderColor: const Color(0xFFFCA5A5),
        );
    }
  }
}

/// RedeemStoreScreen allows shoppers to redeem a promo at the merchant counter.
/// Responsive and overflow-proof across 360x640, 411x891, text scale 1.0/1.5, portrait & landscape.
/// Three clearly separated options:
/// (a) Live camera scanner with LayoutBuilder dynamic viewfinder
/// (b) Gallery image upload with file_picker + mobile_scanner analyzeImage
/// (c) Manual typing of 8-character store code
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

  RedeemInputOption _currentOption = RedeemInputOption.camera;
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
      return; // Debounce 1.5s
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

    final cleanCode = rawCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final status = await _dataService.redeemAtStore(cleanCode);
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _result = StoreRedemptionResult.fromStatus(cleanCode, status);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  Future<void> _pickImageAndScan() async {
    if (_isProcessing) return;

    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        setState(() {
          _errorMessage = 'Unable to read the selected image file.';
          _isProcessing = false;
        });
        return;
      }

      final capture = await _scannerController.analyzeImage(path);
      if (!mounted) return;

      if (capture == null || capture.barcodes.isEmpty) {
        setState(() {
          _errorMessage = 'No QR code found, try again.';
          _isProcessing = false;
        });
        return;
      }

      final code = capture.barcodes.first.rawValue;
      if (code == null || code.trim().isEmpty) {
        setState(() {
          _errorMessage = 'No QR code found, try again.';
          _isProcessing = false;
        });
        return;
      }

      await _redeem(code);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to analyze image. Please try again or type the code.';
        _isProcessing = false;
      });
    }
  }

  void _onManualSubmit() {
    if (_isProcessing) return;
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 8-character store code';
      });
      return;
    }
    _redeem(code);
  }

  void _resetFlow() {
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
      resizeToAvoidBottomInset: true,
      appBar: AppHeader(
        showBack: true,
        subtitle: 'Redeem',
        onBackPressed: () => Navigator.of(context).pop(_result?.status == StoreRedemptionStatus.ok),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: MarketSpacing.screenMargin,
                vertical: 12,
              ),
              child: _result != null
                  ? _buildResultCard(_result!)
                  : _buildMainContent(constraints),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Targeted Promo Banner (if passed)
        if (widget.promo != null) _buildPromoHeader(widget.promo!),

        // Option Selector Segment Tabs
        _buildOptionSelector(),
        const SizedBox(height: 16),

        if (_errorMessage != null) ...[
          _buildErrorBanner(_errorMessage!),
          const SizedBox(height: 16),
        ],

        // Active Option Content
        if (_currentOption == RedeemInputOption.camera)
          _buildCameraView(constraints)
        else if (_currentOption == RedeemInputOption.upload)
          _buildUploadView()
        else
          _buildManualInputView(),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPromoHeader(Promo promo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 52,
              height: 52,
              child: PromoPhotoView(
                promoImageUrl: promo.imageUrl,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: MarketColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              promo.valueLabel ?? promo.promoType.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MarketColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Valid until ${promo.endsAt.toLocal().month}/${promo.endsAt.toLocal().day}/${promo.endsAt.toLocal().year}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: MarketColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildOptionTab(
            option: RedeemInputOption.camera,
            icon: Icons.camera_alt_rounded,
            label: 'Scan Camera',
          ),
          _buildOptionTab(
            option: RedeemInputOption.upload,
            icon: Icons.photo_library_rounded,
            label: 'Upload QR',
          ),
          _buildOptionTab(
            option: RedeemInputOption.typeCode,
            icon: Icons.keyboard_rounded,
            label: 'Type Code',
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTab({
    required RedeemInputOption option,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentOption == option;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentOption = option;
            _errorMessage = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? MarketElevation.level1 : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? MarketColors.primary : MarketColors.secondary,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? MarketColors.primary : MarketColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView(BoxConstraints constraints) {
    if (_cameraPermissionDenied) {
      return _buildCameraPermissionFallback();
    }

    // Dynamic sizing from LayoutBuilder: smaller of 80% width and 45% height
    final availWidth = constraints.maxWidth;
    final availHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 600.0;
    final viewfinderSize = math.min(availWidth * 0.8, availHeight * 0.45).clamp(160.0, 320.0);

    return Column(
      children: [
        Center(
          child: Container(
            width: viewfinderSize,
            height: viewfinderSize,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: MarketColors.outlineVariant.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
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
                    return _buildCameraPermissionFallback();
                  },
                ),

                // Corner view-target marks
                Center(
                  child: Container(
                    width: viewfinderSize * 0.72,
                    height: viewfinderSize * 0.72,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                // Top Controls (Torch & Flip)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                        ),
                        icon: Icon(
                          _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () {
                          _scannerController.toggleTorch();
                          setState(() => _torchOn = !_torchOn);
                        },
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                        ),
                        icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 18),
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
        const SizedBox(height: 14),
        const Text(
          'Point camera at merchant\'s static store QR code',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: MarketColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPermissionFallback() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MarketColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.no_photography_outlined, color: MarketColors.error, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'Camera Access Unavailable',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: MarketColors.onSurface),
          ),
          const SizedBox(height: 6),
          const Text(
            'Camera access is denied or not supported. You can still upload a QR photo or type the code below.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: MarketColors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text('Upload QR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () {
                    setState(() {
                      _currentOption = RedeemInputOption.upload;
                      _errorMessage = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  height: 42,
                  label: 'Type Code',
                  icon: const Icon(Icons.keyboard_outlined, size: 16),
                  onPressed: () {
                    setState(() {
                      _currentOption = RedeemInputOption.typeCode;
                      _errorMessage = null;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MarketColors.cardBorder),
        boxShadow: MarketElevation.level1,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF8FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Icon(Icons.add_photo_alternate_outlined, color: MarketColors.primary, size: 32),
          ),
          const SizedBox(height: 14),
          const Text(
            'Upload QR Code Image',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: MarketColors.onSurface),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select a screenshot or photo of the merchant\'s store QR code from your device gallery.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: MarketColors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            width: double.infinity,
            height: 48,
            label: 'Choose Image from Gallery',
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            isLoading: _isProcessing,
            onPressed: _pickImageAndScan,
          ),
        ],
      ),
    );
  }

  Widget _buildManualInputView() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MarketColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MarketColors.cardBorder),
        boxShadow: MarketElevation.level1,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  child: const Icon(Icons.keyboard_outlined, color: MarketColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Enter 8-Character Code',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: MarketColors.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter the static 8-character code shown below the merchant\'s store QR code.',
              style: TextStyle(fontSize: 13, color: MarketColors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _codeController,
              label: 'Store Code',
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
            const SizedBox(height: 18),
            PrimaryButton(
              width: double.infinity,
              height: 48,
              label: 'Redeem Code',
              isLoading: _isProcessing,
              onPressed: _onManualSubmit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MarketColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MarketColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: MarketColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              softWrap: true,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MarketColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(StoreRedemptionResult result) {
    final isSuccess = result.status == StoreRedemptionStatus.ok;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: result.bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: result.borderColor, width: 2),
        boxShadow: MarketElevation.level2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.promo != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: PromoPhotoView(
                  promoImageUrl: widget.promo!.imageUrl,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: result.borderColor, width: 2),
              ),
              child: Icon(result.icon, size: 36, color: result.color),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            result.title,
            textAlign: TextAlign.center,
            softWrap: true,
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
            softWrap: true,
            style: const TextStyle(
              fontSize: 14,
              color: MarketColors.onSurface,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: result.borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Code: ',
                  style: TextStyle(fontSize: 13, color: MarketColors.secondary, fontWeight: FontWeight.w600),
                ),
                Text(
                  result.code,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    fontFamily: 'monospace',
                    color: MarketColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (isSuccess)
            PrimaryButton(
              width: double.infinity,
              height: 48,
              label: 'Done',
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              onPressed: () => Navigator.of(context).pop(true),
            )
          else
            Column(
              children: [
                PrimaryButton(
                  width: double.infinity,
                  height: 48,
                  label: 'Try Again',
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: _resetFlow,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Back to Promos', style: TextStyle(color: MarketColors.secondary)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
