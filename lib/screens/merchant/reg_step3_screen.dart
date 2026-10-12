import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../widgets/app_buttons.dart';
import 'merchant_reg_controller.dart';
import 'reg_step4_review_screen.dart';
import 'widgets/merchant_reg_stepper.dart';

/// MSME Registration Step 3: Document Uploads & Verification
/// Matches Stitch frame: market_msme_registration_step_3_business_verification
class RegStep3Screen extends StatefulWidget {
  final MerchantRegController controller;

  const RegStep3Screen({
    super.key,
    required this.controller,
  });

  @override
  State<RegStep3Screen> createState() => _RegStep3ScreenState();
}

class _RegStep3ScreenState extends State<RegStep3Screen> {
  late final MerchantRegController _regController;
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _regController = widget.controller;
  }

  void _onContinue() {
    // Document uploads are optional for the demo and never block progress
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegStep4ReviewScreen(controller: _regController),
      ),
    );
  }

  Future<void> _pickAndUpload(String docType) async {
    final uid = _authService.currentUserId ?? 'demo_merchant';
    await _regController.pickAndUploadDocument(
      docType: docType,
      userId: uid,
      dataService: _dataService,
    );
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
        title: const Text(
          'Permits & Verification',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MarketColors.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: MarketSpacing.screenMargin,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 4-Step Stepper
                    const MerchantRegStepper(currentStep: 3),
                    const SizedBox(height: 20),

                    // Header
                    const Text(
                      'Business Verification',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: MarketColors.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Step 3 of 4: Upload government permits to verify your business storefront and unlock local discovery.',
                      style: TextStyle(
                        fontSize: 13,
                        color: MarketColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Demo Notice Pill
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline_rounded,
                              color: Color(0xFF0284C7), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Demo Note: Document uploads go to the merchant-docs bucket. Skips or upload failures never block progress.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Main Card Container
                    ListenableBuilder(
                      listenable: _regController,
                      builder: (context, _) {
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: MarketColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A0F172A),
                                offset: Offset(0, 4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // SECTION 1: DTI or SEC Certificate
                              _buildDocUploadSection(
                                title: '1. DTI or SEC Certificate',
                                subtitle: 'DTI Business Name Registration or SEC Certificate',
                                fileName: _regController.dtiFileName,
                                isUploading: _regController.uploadingDti,
                                onUpload: () => _pickAndUpload('dti'),
                              ),
                              const Divider(height: 32),

                              // SECTION 2: BIR Certificate (Form 2303)
                              _buildDocUploadSection(
                                title: '2. BIR Certificate (Form 2303)',
                                subtitle: 'Bureau of Internal Revenue taxpayer registration certificate',
                                fileName: _regController.birFileName,
                                isUploading: _regController.uploadingBir,
                                onUpload: () => _pickAndUpload('bir'),
                              ),
                              const Divider(height: 32),

                              // SECTION 3: Mayor's / Business Permit
                              _buildDocUploadSection(
                                title: "3. Mayor's / Business Permit",
                                subtitle: 'Valid LGU business permit from your municipality/city',
                                fileName: _regController.mayorFileName,
                                isUploading: _regController.uploadingMayor,
                                onUpload: () => _pickAndUpload('mayor'),
                              ),
                              const Divider(height: 32),

                              // SECTION 4: Valid Government ID
                              _buildDocUploadSection(
                                title: '4. Valid Government ID / Clearance',
                                subtitle: 'PhilSys National ID, Passport, UMID, or Barangay Clearance',
                                fileName: _regController.validIdFileName,
                                isUploading: _regController.uploadingValidId,
                                onUpload: () => _pickAndUpload('valid_id'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Continue Button
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MarketSpacing.screenMargin,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: MarketColors.surface,
                border: Border(
                  top: BorderSide(
                    color: MarketColors.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    offset: Offset(0, -4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: PrimaryButton(
                width: double.infinity,
                height: 52,
                label: 'Continue to Review',
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                onPressed: _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocUploadSection({
    required String title,
    required String subtitle,
    required String? fileName,
    required bool isUploading,
    required VoidCallback onUpload,
  }) {
    final hasFile = fileName != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MarketColors.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: hasFile
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hasFile ? 'ATTACHED' : 'REQUIRED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: hasFile
                      ? const Color(0xFF166534)
                      : const Color(0xFF991B1B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: MarketColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),

        // Dropzone Container
        GestureDetector(
          onTap: isUploading ? null : onUpload,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: hasFile
                  ? const Color(0xFFF0FDF4)
                  : MarketColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasFile
                    ? MarketColors.success
                    : MarketColors.primaryContainer.withValues(alpha: 0.7),
                width: hasFile ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              children: [
                if (isUploading) ...[
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Uploading document...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MarketColors.primary,
                    ),
                  ),
                ] else if (hasFile) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: MarketColors.success,
                    size: 32,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Document attached • Tap to change',
                    style: TextStyle(
                      fontSize: 11,
                      color: MarketColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: MarketColors.primaryContainer.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      color: MarketColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to upload PDF or image',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MarketColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Supported formats: PDF, JPG, PNG up to 10MB',
                    style: TextStyle(
                      fontSize: 11,
                      color: MarketColors.outline,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      side: const BorderSide(color: MarketColors.primaryContainer),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: onUpload,
                    child: const Text(
                      'Browse Document',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MarketColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
